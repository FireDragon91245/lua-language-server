local files      = require 'files'
local vm         = require 'vm'
local hoverLabel = require 'core.hover.label'
local hoverDesc  = require 'core.hover.description'
local guide      = require 'parser.guide'
local lookback   = require 'core.look-backward'

local function findNearCall(uri, ast, pos)
    local text  = files.getText(uri)
    local state = files.getState(uri)
    if not state or not text then
        return nil
    end
    local nearCall
    guide.eachSourceContain(ast.ast, pos, function (src)
        if src.type == 'call'
        or src.type == 'table'
        or src.type == 'function' then
            local finishOffset = guide.positionToOffset(state, src.finish)
            -- call(),$
            if  src.finish <= pos
            and text:sub(finishOffset, finishOffset) == ')' then
                return
            end
            -- {},$
            if  src.finish <= pos
            and text:sub(finishOffset, finishOffset) == '}' then
                return
            end
            if not nearCall or nearCall.start <= src.start then
                nearCall = src
            end
        end
    end)
    if not nearCall then
        return nil
    end
    if nearCall.type ~= 'call' then
        return nil
    end
    return nearCall
end

---@async
local function makeOneSignature(source, oop, index)
    local label = hoverLabel(source, oop, 0)
    if not label then
        return nil
    end
    -- 去掉返回值
    label = label:gsub('%s*->.+', '')
    local params = {}
    local i = 0
    local argStart, argLabel = label:match '()(%b())$'
    local converted = argLabel
        : sub(2, -2)
        : gsub('%b<>', function (str)
            return ('_'):rep(#str)
        end)
        : gsub('%b()', function (str)
            return ('_'):rep(#str)
        end)
        : gsub('%b{}', function (str)
            return ('_'):rep(#str)
        end)
        : gsub ('%b[]', function (str)
            return ('_'):rep(#str)
        end)
        : gsub('[%(%)]', '_')

    for start, finish in converted:gmatch '%s*()[^,]+()' do
        i = i + 1
        params[i] = {
            label = {start + argStart - 1, finish - 1 + argStart},
        }
    end
    -- 不定参数
    if index and index > i and i > 0 then
        local lastLabel = params[i].label
        local text = label:sub(lastLabel[1] + 1, lastLabel[2])
        if text:sub(1, 3) == '...' then
            index = i
        end
    end
    if #params < (index or 0) then
        return nil
    end
    return {
        label       = label,
        params      = params,
        index       = index or 1,
        description = hoverDesc(source),
    }
end

local function isEventNotMatch(call, src)
    if not call.args or not src.args then
        return false
    end
    local literal, index
    for i = 1, #call.args do
        literal = guide.getLiteral(call.args[i])
        if literal then
            index = i
            break
        end
    end
    if not literal then
        return false
    end
    local event = src.args[index]
    if not event or event.type ~= 'doc.type.arg' then
        return false
    end
    if not event.extends
    or #event.extends.types ~= 1 then
        return false
    end
    local eventLiteral = event.extends.types[1] and guide.getLiteral(event.extends.types[1])
    if eventLiteral == nil then
        -- extra checking when function param is not pure literal
        -- eg: it maybe an alias type with literal values
        local eventMap = vm.getLiterals(event.extends.types[1])
        if not eventMap then
            return false
        end
        return not eventMap[literal]
    end
    return eventLiteral ~= literal
end

---@param call parser.object
---@return integer
local function getCallExplicitArgStart(call)
    if call.node.type == 'getmethod'
    and call.args
    and call.args[1]
    and call.args[1].type == 'self' then
        return 2
    end
    return 1
end

---@param call parser.object
---@param func parser.object
---@return integer
local function getSignatureMethodArgOffset(call, func)
    if call.node.type ~= 'getmethod' then
        return 0
    end
    local firstArg = func.args and func.args[1]
    if not firstArg then
        return 0
    end
    if firstArg.type == 'self'
    or (firstArg.name and firstArg.name[1] == 'self') then
        return 1
    end
    return 0
end

---@param call parser.object
---@param index integer?
---@param funcs parser.object[]?
---@return parser.object[]?
local function filterSignatureCandidates(call, index, funcs)
    if not funcs or not index or not call.args or #funcs == 0 then
        return funcs
    end
    local explicitArgStart = getCallExplicitArgStart(call)
    local completedExplicitArgs = #call.args - explicitArgStart + 1
    if completedExplicitArgs <= 0 then
        return funcs
    end
    local uri = guide.getUri(call)
    local filtered = {}
    for _, func in ipairs(funcs) do
        local argOffset = getSignatureMethodArgOffset(call, func)
        local _, max = vm.countParamsOfFunction(func)
        local explicitMax = max == math.huge and math.huge or math.max(0, max - argOffset)
        if explicitMax >= index then
            local matched = true
            for argIndex = explicitArgStart, #call.args do
                local explicitIndex = argIndex - explicitArgStart + 1
                local param = func.args and func.args[explicitIndex + argOffset]
                if not param or not vm.canCastType(uri, vm.compileNode(param), vm.compileNode(call.args[argIndex])) then
                    matched = false
                    break
                end
            end
            if matched then
                filtered[#filtered+1] = func
            end
        end
    end
    if #filtered > 0 then
        return filtered
    end
    return funcs
end

---@param call parser.object
---@return parser.object[]
local function collectSignatureFuncs(call)
    local funcs = {}
    local node = vm.compileNode(call.node)
    node = node.originNode or node
    for src in node:eachObject() do
        if src.type == 'function'
        or src.type == 'doc.type.function' then
            funcs[#funcs+1] = src
        elseif src.type == 'global' and src.cate == 'type' then
            ---@cast src vm.global
            for _, set in ipairs(src:getSets(guide.getUri(call))) do
                if set.type == 'doc.class' then
                    for _, overload in ipairs(set.calls) do
                        funcs[#funcs+1] = overload.overload
                    end
                end
            end
        end
    end
    return funcs
end

---@param call parser.object
---@return vm.node
local function getMatchedSignatureNode(call, index)
    local explicitArgCount = 0
    if call.args then
        for _, arg in ipairs(call.args) do
            if arg.type ~= 'self' then
                explicitArgCount = explicitArgCount + 1
            end
        end
    end
    if explicitArgCount <= 1 then
        if explicitArgCount == 1 then
            local funcs = filterSignatureCandidates(call, index, collectSignatureFuncs(call))
            if funcs and #funcs > 0 then
                local node = vm.createNode()
                for _, func in ipairs(funcs) do
                    node:merge(func)
                end
                return node
            end
        end
        local fallbackNode = vm.compileNode(call.node)
        return fallbackNode.originNode or fallbackNode
    end
    local funcs = vm.getExactMatchedFunctions(call.node, call.args)
    if not funcs or #funcs == 0 then
        local node = vm.compileNode(call.node)
        return node.originNode or node
    end
    local node = vm.createNode()
    for _, func in ipairs(funcs) do
        node:merge(func)
    end
    return node
end

---@async
local function makeSignatures(text, call, pos)
    local func = call.node
    local oop = func.type == 'method'
             or func.type == 'getmethod'
             or func.type == 'setmethod'
    local index
    if call.args then
        local args = {}
        for _, arg in ipairs(call.args) do
            if arg.type ~= 'self' then
                args[#args+1] = arg
            end
        end
        local uri   = guide.getUri(call)
        local state = files.getState(uri)
        for i, arg in ipairs(args) do
            local startOffset = guide.positionToOffset(state, arg.start)
            startOffset =  lookback.findTargetSymbol(text, startOffset, '(')
                        or lookback.findTargetSymbol(text, startOffset, ',')
                        or startOffset
            local startPos = guide.offsetToPosition(state, startOffset)
            if startPos > pos then
                index = i - 1
                break
            end
            if pos <= arg.finish then
                index = i
                break
            end
        end
        if not index then
            local offset     = guide.positionToOffset(state, pos)
            local backSymbol = lookback.findSymbol(text, offset)
            if backSymbol == ','
            or backSymbol == '(' then
                index = #args + 1
            else
                index = #args
            end
        end
    end
    local signs = {}
    local node = getMatchedSignatureNode(call, index)
    local mark = {}
    for src in node:eachObject() do
        if (src.type == 'function' and not vm.isVarargFunctionWithOverloads(src))
        or src.type == 'doc.type.function' then
            if  not mark[src]
            and not isEventNotMatch(call, src) then
                mark[src] = true
                signs[#signs+1] = makeOneSignature(src, oop, index)
            end
        elseif src.type == 'global' and src.cate == 'type' then
            ---@cast src vm.global
            for _, set in ipairs(src:getSets(guide.getUri(call))) do
                if set.type == 'doc.class' then
                    for _, overload in ipairs(set.calls) do
                        local f = overload.overload
                        if  not mark[f]
                        and not isEventNotMatch(call, src) then
                            mark[f] = true
                            signs[#signs+1] = makeOneSignature(f, oop, index)
                        end
                    end
                end
            end
        end
    end
    return signs
end

---@async
return function (uri, pos)
    local state = files.getState(uri)
    local text  = files.getText(uri)
    if not state or not text then
        return nil
    end
    local offset = guide.positionToOffset(state, pos)
    pos = guide.offsetToPosition(state, lookback.skipSpace(text, offset))
    local call = findNearCall(uri, state, pos)
    if not call then
        return nil
    end
    local signs = makeSignatures(text, call, pos)
    if not signs or #signs == 0 then
        return nil
    end
    table.sort(signs, function (a, b)
        return #a.params < #b.params
    end)
    return signs
end
