---@class vm
local vm    = require 'vm.vm'
local guide = require 'parser.guide'
local util  = require 'utility'

---@param func parser.object
---@return parser.object[]?
local function getFunctionDocs(func)
    if func.bindDocs then
        return func.bindDocs
    end
    local parent = func.parent
    if not parent then
        return nil
    end
    if parent.type == 'setglobal'
    or parent.type == 'setlocal'
    or parent.type == 'setfield'
    or parent.type == 'setmethod'
    or parent.type == 'setindex'
    or parent.type == 'local' then
        return parent.bindDocs
    end
    return nil
end

---@param arg parser.object
---@return parser.object?
local function getDocParam(arg)
    if not arg.bindDocs then
        return nil
    end
    for _, doc in ipairs(arg.bindDocs) do
        if doc.type == 'doc.param'
        and doc.param[1] == arg[1] then
            return doc
        end
    end
    return nil
end

---@param func parser.object
---@return integer min
---@return number  max
---@return integer def
function vm.countParamsOfFunction(func)
    local min = 0
    local max = 0
    local def = 0
    if func.type == 'function' then
        if func.args then
            max = #func.args
            def = max
            for i = #func.args, 1, -1 do
                local arg = func.args[i]
                if arg.type == '...' then
                    max = math.huge
                elseif arg.type == 'self'
                and    i == 1 then
                    min = i
                    break
                elseif getDocParam(arg)
                and    not vm.compileNode(arg):isNullable() then
                    min = i
                    break
                end
            end
        end
    end
    if func.type == 'doc.type.function' then
        if func.args then
            max = #func.args
            def = max
            for i = #func.args, 1, -1 do
                local arg = func.args[i]
                if arg.name and arg.name[1] =='...' then
                    max = math.huge
                elseif not vm.compileNode(arg):isNullable() then
                    min = i
                    break
                end
            end
        end
    end
    return min, max, def
end

---@param source parser.object
---@return integer min
---@return number  max
---@return integer def
function vm.countParamsOfSource(source)
    local min = 0
    local max = 0
    local def = 0
    local overloads = {}
    if source.bindDocs then
        for _, doc in ipairs(source.bindDocs) do
            if doc.type == 'doc.overload' then
                overloads[doc.overload] = true
            end
        end
    end
    local hasDocFunction
    for nd in vm.compileNode(source):eachObject() do
        if nd.type == 'doc.type.function' and not overloads[nd] then
            hasDocFunction = true
            ---@cast nd parser.object
            local dmin, dmax, ddef = vm.countParamsOfFunction(nd)
            if dmin > min then
                min = dmin
            end
            if dmax > max then
                max = dmax
            end
            if ddef > def then
                def = ddef
            end
        end
    end
    if not hasDocFunction then
        local dmin, dmax, ddef = vm.countParamsOfFunction(source)
        if dmin > min then
            min = dmin
        end
        if dmax > max then
            max = dmax
        end
        if ddef > def then
            def = ddef
        end
    end
    return min, max, def
end

---@param node vm.node
---@return integer min
---@return number  max
---@return integer def
function vm.countParamsOfNode(node)
    local min, max, def
    for n in node:eachObject() do
        if n.type == 'function'
        or n.type == 'doc.type.function' then
            ---@cast n parser.object
            local fmin, fmax, fdef = vm.countParamsOfFunction(n)
            if not min or fmin < min then
                min = fmin
            end
            if not max or fmax > max then
                max = fmax
            end
            if not def or fdef > def then
                def = fdef
            end
        end
    end
    return min or 0, max or math.huge, def or 0
end

---@param func parser.object
---@param onlyDoc? boolean
---@param mark? table
---@return integer min
---@return number  max
---@return integer def
function vm.countReturnsOfFunction(func, onlyDoc, mark)
    if func.type == 'function' then
        ---@type integer?, number?, integer?
        local min, max, def
        local hasDocReturn
        if func.bindDocs then
            local lastReturn
            local n = 0
            ---@type integer?, number?, integer?
            local dmin, dmax, ddef
            for _, doc in ipairs(func.bindDocs) do
                if doc.type == 'doc.return' then
                    hasDocReturn = true
                    for _, ret in ipairs(doc.returns) do
                        n = n + 1
                        lastReturn = ret
                        dmax = n
                        ddef = n
                        if  (not ret.name or ret.name[1] ~= '...')
                        and not vm.compileNode(ret):isNullable() then
                            dmin = n
                        end
                    end
                end
            end
            if lastReturn then
                if lastReturn.name and lastReturn.name[1] == '...' then
                    dmax = math.huge
                end
            end
            if dmin and (not min or (dmin < min)) then
                min = dmin
            end
            if dmax and (not max or (dmax > max)) then
                max = dmax
            end
            if ddef and (not def or (ddef > def)) then
                def = ddef
            end
        end
        if not onlyDoc and not hasDocReturn and func.returns then
            for _, ret in ipairs(func.returns) do
                local dmin, dmax, ddef = vm.countList(ret, mark)
                if not min or dmin < min then
                    min = dmin
                end
                if not max or dmax > max then
                    max = dmax
                end
                if not def or ddef > def then
                    def = ddef
                end
            end
        end
        return min or 0, max or math.huge, def or 0
    end
    if func.type == 'doc.type.function' then
        return vm.countList(func.returns)
    end
    error('not a function')
end

---@param source parser.object
---@return integer min
---@return number  max
---@return integer def
function vm.countReturnsOfSource(source)
    local overloads = {}
    local hasDocFunction
    local min, max, def
    if source.bindDocs then
        for _, doc in ipairs(source.bindDocs) do
            if doc.type == 'doc.overload' then
                overloads[doc.overload] = true
                local dmin, dmax, ddef = vm.countReturnsOfFunction(doc.overload)
                if not min or dmin < min then
                    min = dmin
                end
                if not max or dmax > max then
                    max = dmax
                end
                if not def or ddef > def then
                    def = ddef
                end
            end
        end
    end
    for nd in vm.compileNode(source):eachObject() do
        if nd.type == 'doc.type.function' and not overloads[nd] then
            ---@cast nd parser.object
            hasDocFunction = true
            local dmin, dmax, ddef = vm.countReturnsOfFunction(nd)
            if not min or dmin < min then
                min = dmin
            end
            if not max or dmax > max then
                max = dmax
            end
            if not def or ddef > def then
                def = ddef
            end
        end
    end
    if not hasDocFunction then
        local dmin, dmax, ddef = vm.countReturnsOfFunction(source, true)
        if not min or dmin < min then
            min = dmin
        end
        if not max or dmax > max then
            max = dmax
        end
        if not def or ddef > def then
            def = ddef
        end
    end
    return min, max, def
end

---@param func parser.object
---@param mark? table
---@return integer min
---@return number  max
---@return integer def
function vm.countReturnsOfCall(func, args, mark)
    local funcs = vm.getMatchedFunctions(func, args, mark)
    if not funcs then
        return 0, math.huge, 0
    end
    ---@type integer?, number?, integer?
    local min, max, def
    for _, f in ipairs(funcs) do
        local rmin, rmax, rdef = vm.countReturnsOfFunction(f, false, mark)
        if not min or rmin < min then
            min = rmin
        end
        if not max or rmax > max then
            max = rmax
        end
        if not def or rdef > def then
            def = rdef
        end
    end
    return min or 0, max or math.huge, def or 0
end

---@param list parser.object[]?
---@param mark? table
---@return integer min
---@return number  max
---@return integer def
function vm.countList(list, mark)
    if not list then
        return 0, 0, 0
    end
    local lastArg = list[#list]
    if not lastArg then
        return 0, 0, 0
    end
    ---@type integer, number, integer
    local min, max, def = #list, #list, #list
    if lastArg.type == '...'
    or lastArg.type == 'varargs'
    or (lastArg.type == 'doc.type' and lastArg.name and lastArg.name[1] == '...') then
        max = math.huge
    elseif lastArg.type == 'call' then
        if not mark then
            mark = {}
        end
        if mark[lastArg] then
            min = min - 1
            max = math.huge
        else
            mark[lastArg] = true
            local rmin, rmax, rdef = vm.countReturnsOfCall(lastArg.node, lastArg.args, mark)
            return min - 1 + rmin, max - 1 + rmax, def - 1 + rdef
        end
    end
    for i = min, 1, -1 do
        local arg = list[i]
        if  arg.type == 'doc.type'
        and ((arg.name and arg.name[1] == '...')
            or vm.compileNode(arg):isNullable()) then
            min = i - 1
        else
            break
        end
    end
    return min, max, def
end

local getReceiverGenericMap
local mergeResolvedGenerics
local getCallableVariableCallbackScore

---@param callFunc parser.object?
---@param args parser.object[]?
---@return boolean
local function hasMethodSelfArg(callFunc, args)
    return callFunc and callFunc.type == 'getmethod'
       and args and args[1] and args[1].type == 'self'
       or false
end

---@param callFunc parser.object?
---@param args parser.object[]?
---@param func parser.object
---@return integer
local function getMethodArgOffset(callFunc, args, func)
    if not callFunc or callFunc.type ~= 'getmethod' then
        return 0
    end
    if hasMethodSelfArg(callFunc, args) then
        return 0
    end
    local firstArg = func.args and func.args[1]
    if not firstArg then
        return 0
    end
    if firstArg.type == 'self' then
        return 1
    end
    if firstArg.name and firstArg.name[1] == 'self' then
        return 1
    end
    return 0
end

---@param uri uri
---@param callFunc parser.object?
---@param args parser.object[]
---@param func parser.object
---@return boolean
local function isAllParamMatched(uri, callFunc, args, params, func)
    if not params then
        return false
    end
    local resolved
    local sign = vm.getSign(func)
    local resolveArgs = args
    if sign and args then
        if callFunc and callFunc.type == 'getmethod' and not hasMethodSelfArg(callFunc, args) and #sign.signList ~= #args then
            local receiver = callFunc.node
            if receiver then
                resolveArgs = { receiver }
                for i = 1, #args do
                    resolveArgs[#resolveArgs+1] = args[i]
                end
            end
        end
    end
    if sign then
        resolved = sign:resolve(uri, resolveArgs)
    end
    resolved = mergeResolvedGenerics(resolved, getReceiverGenericMap(uri, callFunc))
    local argOffset = getMethodArgOffset(callFunc, args, func)
    for i = 1, #args do
        local param = params[i + argOffset]
        if not param then
            return false
        end
        local argNode = vm.compileNode(args[i])
        local defObj = param
        if resolved and next(resolved) then
            defObj = vm.cloneObject(defObj, resolved) or defObj
        end
        local defNode = vm.compileNode(defObj)
        local callbackScore = 0
        if defObj.type ~= 'generic' then
            ---@cast defObj parser.object
            callbackScore = getCallableVariableCallbackScore(uri, args[i], defObj)
        end
        if not vm.canCastType(uri, defNode, argNode)
        and callbackScore <= 0 then
            return false
        end
    end
    return true
end

---@param uri uri
---@param callFunc parser.object?
---@param args parser.object[]
---@param func parser.object
---@param index integer
---@return parser.object|vm.generic?
local function getResolvedParamObject(uri, callFunc, args, func, index)
    local argOffset = getMethodArgOffset(callFunc, args, func)
    local param = func.args and func.args[index + argOffset]
    if not param then
        return nil
    end
    local sign = vm.getSign(func)
    if not sign then
        return param
    end
    local resolveArgs = args
    if callFunc and callFunc.type == 'getmethod' and args and not hasMethodSelfArg(callFunc, args) and #sign.signList ~= #args then
        local receiver = callFunc.node
        if receiver then
            resolveArgs = { receiver }
            for i = 1, #args do
                resolveArgs[#resolveArgs+1] = args[i]
            end
        end
    end
    local resolved = sign:resolve(uri, resolveArgs)
    resolved = mergeResolvedGenerics(resolved, getReceiverGenericMap(uri, callFunc))
    if not resolved or not next(resolved) then
        return param
    end
    return vm.cloneObject(param, resolved) or param
end

---@param uri uri
---@param callFunc parser.object?
---@return table<string, vm.node>?
function getReceiverGenericMap(uri, callFunc)
    if not callFunc or callFunc.type ~= 'getmethod' then
        return nil
    end
    local receiver = callFunc.node
    if receiver and receiver.type == 'getlocal' then
        receiver = guide.getLocal(receiver, receiver[1], receiver.start) or receiver
    end
    if not receiver then
        return nil
    end
    local receiverNode = vm.compileNode(receiver)
    for item in receiverNode:eachObject() do
        if item.type == 'doc.type.sign' and item.node and item.node[1] and item.signs then
            local classGlobal = vm.getGlobal('type', item.node[1])
            if classGlobal then
                local genericMap = vm.getClassGenericMap(uri, classGlobal, item.signs)
                if genericMap then
                    return genericMap
                end
            end
        end
    end
    return nil
end

---@param resolved table<string, vm.node>?
---@param receiverGenericMap table<string, vm.node>?
---@return table<string, vm.node>?
function mergeResolvedGenerics(resolved, receiverGenericMap)
    if not receiverGenericMap then
        return resolved
    end
    local merged = resolved or {}
    for name, node in pairs(receiverGenericMap) do
        if not merged[name] then
            merged[name] = node
        end
    end
    if next(merged) then
        return merged
    end
    return nil
end

---@param func parser.object
---@return parser.object?
local function getMethodSelfDoc(func)
    if func.args and func.args[1] and func.args[1].name and func.args[1].name[1] == 'self' then
        return func.args[1].extends
    end
    local docs = getFunctionDocs(func)
    if not docs then
        return nil
    end
    for _, doc in ipairs(docs) do
        if doc.type == 'doc.param'
        and doc.param
        and doc.param[1] == 'self'
        and doc.extends then
            return doc.extends
        end
    end
    return nil
end

---@param view string?
---@return string?, integer?
local function getStructuredTypeInfo(view)
    if not view then
        return nil, nil
    end
    local baseName, signText = view:match('^([%w_%.]+)%s*<(.+)>$')
    if not baseName then
        local plainName = view:match('^([%w_%.]+)$')
        if plainName then
            return plainName, 0
        end
        return nil, nil
    end
    local depth = 0
    local arity = 1
    for i = 1, #signText do
        local ch = signText:sub(i, i)
        if ch == '<' or ch == '(' or ch == '{' or ch == '[' then
            depth = depth + 1
        elseif ch == '>' or ch == ')' or ch == '}' or ch == ']' then
            depth = depth - 1
        elseif ch == ',' and depth == 0 then
            arity = arity + 1
        end
    end
    return baseName, arity
end

---@param uri uri
---@param callFunc parser.object
---@param args parser.object[]
---@param func parser.object
---@return integer
local function getMethodSelfSpecificityScore(uri, callFunc, args, func)
    if callFunc.type ~= 'getmethod' then
        return 0
    end
    local receiver = callFunc.node
    if not receiver then
        return 0
    end
    local selfDoc = getMethodSelfDoc(func)
    if not selfDoc then
        return 0
    end
    local receiverNode = vm.compileNode(receiver)
    local selfObject = selfDoc
    local receiverGenericMap = getReceiverGenericMap(uri, callFunc)
    local sign = vm.getSign(func)
    if sign then
        local resolvedArgs = args
        if not hasMethodSelfArg(callFunc, args) and #sign.signList ~= #args then
            resolvedArgs = { receiver }
            for i = 1, #args do
                resolvedArgs[#resolvedArgs+1] = args[i]
            end
        end
        local resolved = sign:resolve(uri, resolvedArgs)
        resolved = mergeResolvedGenerics(resolved, receiverGenericMap)
        if resolved and next(resolved) then
            local clonedSelfObject = vm.cloneObject(selfDoc, resolved)
            if clonedSelfObject and clonedSelfObject.type ~= 'generic' then
                ---@cast clonedSelfObject parser.object
                selfObject = clonedSelfObject
            end
        end
    elseif receiverGenericMap then
        local clonedSelfObject = vm.cloneObject(selfDoc, receiverGenericMap)
        if clonedSelfObject and clonedSelfObject.type ~= 'generic' then
            ---@cast clonedSelfObject parser.object
            selfObject = clonedSelfObject
        end
    end
    local selfNode = vm.compileNode(selfObject)
    if not vm.canCastType(uri, selfNode, receiverNode) then
        return -50
    end
    local receiverView = vm.getInfer(receiverNode):view(uri)
    local selfView = vm.getInfer(selfNode):view(uri)
    if receiverView and selfView and receiverView == selfView then
        return 16
    end
    local receiverName, receiverArity = getStructuredTypeInfo(receiverView)
    local selfName, selfArity = getStructuredTypeInfo(selfView)
    if receiverName and selfName and receiverName == selfName then
        if receiverArity == selfArity then
            return 12
        end
        if selfArity and selfArity > 0 then
            return -12
        end
    end
    return 4
end

---@param param parser.object?
---@return boolean
local function hasStructuredGenericParam(param)
    if not param then
        return false
    end
    local hasGeneric = false
    local hasContainer = false
    guide.eachSourceType(param, 'doc.generic.name', function (_)
        hasGeneric = true
    end)
    if not hasGeneric then
        return false
    end
    guide.eachSourceType(param, 'doc.type.sign', function (_)
        hasContainer = true
    end)
    guide.eachSourceType(param, 'doc.type.array', function (_)
        hasContainer = true
    end)
    guide.eachSourceType(param, 'doc.type.table', function (_)
        hasContainer = true
    end)
    guide.eachSourceType(param, 'doc.type.function', function (_)
        hasContainer = true
    end)
    return hasContainer
end

---@param param parser.object?
---@return boolean
local function isVariadicParam(param)
    if not param then
        return false
    end
    if param.type == '...' then
        return true
    end
    return param.name and param.name[1] == '...'
end

---@param uri uri
---@param param parser.object?
---@return boolean
local function hasExplicitTableParam(uri, param)
    if param and param.type == 'doc.type.arg' and param.extends then
        param = param.extends
    end
    if param and param.type == 'doc.type' and param.types and #param.types == 1 then
        param = param.types[1]
    end
    if not param then
        return false
    end
    if param.type == 'doc.type.table'
    or param.type == 'doc.type.array' then
        return true
    end
    if param.type == 'doc.type.name' then
        return param[1] == 'table'
    end
    if param.type == 'doc.type.sign' and param.node and param.node[1] then
        return param.node[1] == 'table'
    end
    local infer = vm.getInfer(param)
    return infer:hasType(uri, 'table') and not infer:hasClass(uri)
end

---@param param parser.object|vm.generic?
---@return parser.object?
local function getTableParamProto(param)
    if not param then
        return nil
    end
    if param.type == 'generic' then
        ---@cast param vm.generic
        local proto = param.proto
        if proto and proto.type ~= 'generic' then
            ---@cast proto parser.object
            return proto
        end
        return nil
    end
    ---@cast param parser.object
    return param
end

---@param param parser.object?
---@return boolean
local function isSpecializedTableParam(param)
    if param and param.type == 'doc.type.arg' and param.extends then
        param = param.extends
    end
    if param and param.type == 'doc.type' and param.types and #param.types == 1 then
        param = param.types[1]
    end
    if not param then
        return false
    end
    if param.type == 'doc.type.table'
    or param.type == 'doc.type.array' then
        return true
    end
    if param.type == 'doc.type.name' then
        return param[1] == 'table'
           and param.signs ~= nil
           and #param.signs > 0
    end
    local specialized = false
    guide.eachSourceType(param, 'doc.type.table', function (_)
        specialized = true
    end)
    if specialized then
        return true
    end
    guide.eachSourceType(param, 'doc.type.array', function (_)
        specialized = true
    end)
    if specialized then
        return true
    end
    guide.eachSourceType(param, 'doc.type.sign', function (_)
        specialized = true
    end)
    return specialized
end

---@param uri uri
---@param arg parser.object?
---@return boolean
local function isExplicitTableArg(uri, arg)
    if not arg then
        return false
    end
    local node = vm.compileNode(arg)
    local hasTable = false
    local hasOtherClass = false
    for n in node:eachObject() do
        if n.type == 'table'
        or n.type == 'doc.type.table'
        or n.type == 'doc.type.array' then
            hasTable = true
        elseif n.type == 'global' and n.cate == 'type' then
            ---@cast n vm.global
            if n.name == 'table' then
                hasTable = true
            elseif not guide.isBasicType(n.name) then
                hasOtherClass = true
            end
        elseif n.type == 'doc.type.sign' and n.node and n.node[1] then
            if n.node[1] == 'table' then
                hasTable = true
            else
                hasOtherClass = true
            end
        end
    end
    if hasOtherClass then
        return false
    end
    if hasTable then
        return true
    end
    local infer = vm.getInfer(arg)
    return infer:hasType(uri, 'table') and not infer:hasClass(uri)
end

---@param arg parser.object?
---@return boolean
local function isStructuredTableArg(arg)
    if not arg then
        return false
    end
    local node = vm.compileNode(arg)
    for n in node:eachObject() do
        if n.type == 'table'
        or n.type == 'doc.type.table'
        or n.type == 'doc.type.array' then
            return true
        end
        if n.type == 'doc.type.sign' and n.node and n.node[1] == 'table' and n.signs and #n.signs > 0 then
            return true
        end
    end
    return false
end

---@param uri uri
---@param arg parser.object?
---@return boolean
local function isScalarArg(uri, arg)
    if not arg then
        return false
    end
    if arg.type == 'function' then
        return false
    end
    local infer = vm.getInfer(arg)
    if infer:hasClass(uri) then
        return false
    end
    if infer:hasType(uri, 'table') then
        return false
    end
    return true
end

---@param args parser.object[]
---@param func parser.object
---@return integer
local function getFunctionArityPriority(args, func)
    local amin, amax = vm.countList(args)
    local min, max, def = vm.countParamsOfFunction(func)
    if amin == amax and min == amax and max == amax and def == amax then
        return 3
    end
    local lastParam = func.args and func.args[#func.args] or nil
    if isVariadicParam(lastParam) then
        return 1
    end
    return 2
end

---@param uri uri
---@param arg parser.object?
---@param param parser.object?
---@return integer
local function getParamSpecificityScore(uri, arg, param)
    if not param then
        return 0
    end
    local score = 0
    if isVariadicParam(param) then
        return -1
    end
    local paramInfer = vm.getInfer(param)
    if isExplicitTableArg(uri, arg) and hasExplicitTableParam(uri, param) then
        score = score + 8
    end

    local argView = arg and vm.getInfer(arg):view(uri) or nil
    local paramView = paramInfer:view(uri)
    if argView and paramView and argView == paramView and not paramInfer:hasAny(uri) then
        score = score + 6
    end

    if not paramInfer:hasAny(uri) then
        score = score + 2
    end

    return score
end

---@param arg parser.object?
---@param param parser.object?
---@return boolean
local function hasExactLiteralMatch(arg, param)
    if not arg or not param then
        return false
    end
    local argLiterals = vm.getLiterals(arg)
    local paramLiterals = vm.getLiterals(param)
    if not argLiterals or not paramLiterals then
        return false
    end
    for literal in pairs(argLiterals) do
        if paramLiterals[literal] then
            return true
        end
    end
    return false
end

---@param param parser.object?
---@return parser.object?
local function getFunctionParamProto(param)
    if not param then
        return nil
    end
    if param.type == 'doc.type.arg' and param.extends then
        param = param.extends
    end
    if param.type == 'doc.type' and param.types and #param.types == 1 then
        param = param.types[1]
    end
    if param.type == 'doc.type.function' then
        return param
    end
    return nil
end

---@param uri uri
---@param actual parser.object?
---@param expected parser.object?
---@return integer
getCallableVariableCallbackScore = function (uri, actual, expected)
    if not actual or actual.type == 'function' then
        return 0
    end
    local expectedFunc = getFunctionParamProto(expected)
    if not expectedFunc then
        return 0
    end

    local bestScore = -1
    local actualNode = vm.compileNode(actual)
    for callback in actualNode:eachObject() do
        if callback.type == 'function' or callback.type == 'doc.type.function' then
            ---@cast callback parser.object
            local actualMin, actualMax, actualDef = vm.countParamsOfFunction(callback)
            local expectedMin, expectedMax, expectedDef = vm.countParamsOfFunction(expectedFunc)
            local actualRetMin, actualRetMax, actualRetDef = vm.countReturnsOfFunction(callback)
            local expectedRetMin, expectedRetMax, expectedRetDef = vm.countReturnsOfFunction(expectedFunc)

            if actualMin > expectedMax or actualMax < expectedMin then
                goto CONTINUE
            end

            local score = 0
            if expectedMax ~= math.huge then
                if actualMax == expectedMax and actualDef == expectedDef then
                    score = score + 18
                elseif actualMax >= expectedMax then
                    score = score + 6
                end
            end

            if expectedRetMax ~= math.huge then
                if actualRetMax < expectedRetMin then
                    goto CONTINUE
                end
                if actualRetMax == expectedRetMax and actualRetDef == expectedRetDef then
                    score = score + 14
                elseif actualRetDef >= expectedRetDef then
                    score = score + 4
                end
            end

            local compatible = true
            for index, expectedArg in ipairs(expectedFunc.args or {}) do
                local callbackArg = callback.args and callback.args[index]
                if not callbackArg then
                    compatible = false
                    break
                end
                local callbackArgNode = vm.compileNode(callbackArg.extends or callbackArg)
                local expectedArgNode = vm.compileNode(expectedArg.extends or expectedArg)
                if not vm.canCastType(uri, callbackArgNode, expectedArgNode) then
                    local callbackView = vm.getInfer(callbackArgNode):view(uri)
                    local expectedView = vm.getInfer(expectedArgNode):view(uri)
                    local callbackName, callbackArity = getStructuredTypeInfo(callbackView)
                    local expectedName, expectedArity = getStructuredTypeInfo(expectedView)
                    if not (callbackName and expectedName and callbackName == expectedName and callbackArity and expectedArity and expectedArity >= callbackArity and callbackArity > 0) then
                        compatible = false
                        break
                    end
                end

                local callbackView = vm.getInfer(callbackArgNode):view(uri)
                local expectedView = vm.getInfer(expectedArgNode):view(uri)
                if callbackView and expectedView then
                    if callbackView == expectedView then
                        score = score + 12
                    else
                        local callbackName, callbackArity = getStructuredTypeInfo(callbackView)
                        local expectedName, expectedArity = getStructuredTypeInfo(expectedView)
                        if callbackName and expectedName and callbackName == expectedName then
                            if callbackArity == expectedArity then
                                score = score + 8
                            else
                                score = score + 3
                            end
                        end
                    end
                end
            end

            if compatible and score > bestScore then
                bestScore = score
            end
            ::CONTINUE::
        end
    end

    if bestScore < 0 then
        return 0
    end
    return bestScore
end

---@param actual parser.object?
---@param expected parser.object?
---@return integer
local function getCallbackSpecificityScore(actual, expected)
    if not actual or actual.type ~= 'function' then
        return 0
    end
    local expectedFunc = getFunctionParamProto(expected)
    if not expectedFunc then
        return 0
    end

    local actualMin, actualMax, actualDef = vm.countParamsOfFunction(actual)
    local expectedMin, expectedMax, expectedDef = vm.countParamsOfFunction(expectedFunc)
    local actualRetMin, actualRetMax, actualRetDef = vm.countReturnsOfFunction(actual)
    local expectedRetMin, expectedRetMax, expectedRetDef = vm.countReturnsOfFunction(expectedFunc)

    local score = 0

    if expectedMax ~= math.huge then
        if actualMax == expectedMax and actualDef == expectedDef then
            score = score + 18
        elseif actualMax > expectedMax then
            score = score - 10
        elseif actualMin == expectedMin then
            score = score + 4
        end
    end

    if expectedRetMax ~= math.huge then
        if actualRetMax < expectedRetMin then
            score = score - 20
        elseif actualRetMax == expectedRetMax and actualRetDef == expectedRetDef then
            score = score + 14
        elseif actualRetDef == expectedRetDef then
            score = score + 6
        elseif actualRetDef < expectedRetDef then
            score = score - 8
        end
    end

    return score
end

---@param func parser.object
---@return boolean
local function hasExplicitReturns(func)
    if func.type == 'doc.type.function' then
        return func.returns and #func.returns > 0 or false
    end
    if func.type == 'function' and func.bindDocs then
        for _, doc in ipairs(func.bindDocs) do
            if doc.type == 'doc.return' and doc.returns and #doc.returns > 0 then
                return true
            end
        end
    end
    return false
end

---@param uri uri
---@param callFunc parser.object?
---@param args parser.object[]
---@param func parser.object
---@return number
local function calcFunctionMatchScore(uri, callFunc, args, func)
    if vm.isVarargFunctionWithOverloads(func)
    or vm.isFunctionWithOnlyOverloads(func)
    or not isAllParamMatched(uri, callFunc, args, func.args, func)
    then
        return -1
    end
    local matchScore = getFunctionArityPriority(args, func) * 10
    if callFunc and callFunc.type == 'getmethod' then
        matchScore = matchScore + getMethodSelfSpecificityScore(uri, callFunc, args, func)
    end
    local argOffset = getMethodArgOffset(callFunc, args, func)
    for i = 1, math.min(#args, #func.args - argOffset) do
        local arg = args[i]
        local originalParam = func.args[i + argOffset]
        local resolvedParam = getResolvedParamObject(uri, callFunc, args, func, i) or originalParam
        local isReceiverArg = callFunc
            and callFunc.type == 'getmethod'
            and arg.type == 'self'
            and (originalParam.type == 'self' or (originalParam.name and originalParam.name[1] == 'self'))
        ---@type parser.object
        local param = originalParam
        if resolvedParam and resolvedParam.type ~= 'generic' then
            ---@cast resolvedParam parser.object
            param = resolvedParam
        end
        if resolvedParam and resolvedParam.type == 'generic' then
            ---@cast resolvedParam vm.generic
            local genericProto = resolvedParam.proto
            if genericProto and genericProto.type ~= 'generic' then
                ---@cast genericProto parser.object
                param = genericProto
            end
        end
        matchScore = matchScore + getParamSpecificityScore(uri, arg, param)
        matchScore = matchScore + getCallbackSpecificityScore(arg, param)
        matchScore = matchScore + getCallableVariableCallbackScore(uri, arg, param)
        local _, literalsCount = vm.getLiterals(param)
        if hasExactLiteralMatch(arg, param) then
            matchScore = matchScore + math.max(1, 12 / math.max(literalsCount, 1))
        end
        local argView = vm.getInfer(arg):view(uri)
        local paramView = vm.getInfer(param):view(uri)
        if hasStructuredGenericParam(originalParam)
        and not isReceiverArg
        and arg.type ~= 'function'
        and argView and paramView then
            if argView == paramView then
                matchScore = matchScore + 4
            else
                if isScalarArg(uri, arg) then
                    return -1
                end
                matchScore = matchScore - 20
            end
        end
    end
    return matchScore
end

---@param uri uri
---@param args parser.object[]
---@param callFunc parser.object?
---@param funcs parser.object[]
---@return parser.object[]
local function filterExplicitTableOverloads(uri, args, callFunc, funcs)
    local filtered = funcs
    for i = 1, #args do
        if not isExplicitTableArg(uri, args[i]) then
            goto CONTINUE
        end
        local explicit = {}
        for _, func in ipairs(filtered) do
            local argOffset = getMethodArgOffset(callFunc, args, func)
            local param = func.args and func.args[i + argOffset]
            if hasExplicitTableParam(uri, param) then
                explicit[#explicit + 1] = func
            end
        end
        if #explicit > 0 then
            filtered = explicit
        end

        if isStructuredTableArg(args[i]) then
            local specialized = {}
            for _, func in ipairs(filtered) do
                local argOffset = getMethodArgOffset(callFunc, args, func)
                local param = getTableParamProto(getResolvedParamObject(uri, callFunc, args, func, i) or (func.args and func.args[i + argOffset]))
                if hasExplicitTableParam(uri, param)
                and isSpecializedTableParam(param) then
                    specialized[#specialized + 1] = func
                end
            end
            if #specialized > 0 then
                filtered = specialized
            end
        end
        ::CONTINUE::
    end
    return filtered
end

---@param uri uri
---@param args parser.object[]
---@param callFunc parser.object?
---@param funcs parser.object[]
---@return parser.object[]
local function filterMethodSelfOverloads(uri, args, callFunc, funcs)
    if not callFunc or callFunc.type ~= 'getmethod' then
        return funcs
    end
    local bestScore
    local filtered = {}
    for _, func in ipairs(funcs) do
        local score = getMethodSelfSpecificityScore(uri, callFunc, args, func)
        if not bestScore or score > bestScore then
            bestScore = score
            filtered = { func }
        elseif score == bestScore then
            filtered[#filtered + 1] = func
        end
    end
    if bestScore and #filtered > 0 and #filtered < #funcs then
        return filtered
    end
    return funcs
end

---@param args parser.object[]
---@param callFunc parser.object?
---@param funcs parser.object[]
---@return parser.object[]
local function filterExactArityOverloads(args, callFunc, funcs)
    local amin, amax = vm.countList(args)
    if amin ~= amax then
        return funcs
    end
    local exact = {}
    local variadic = {}
    for _, func in ipairs(funcs) do
        local argOffset = getMethodArgOffset(callFunc, args, func)
        local _, max, def = vm.countParamsOfFunction(func)
        local lastParam = func.args and func.args[#func.args] or nil
        if max ~= math.huge then
            max = max - argOffset
        end
        def = def - argOffset
        if max == amax and def == amax then
            exact[#exact + 1] = func
        elseif isVariadicParam(lastParam) then
            variadic[#variadic + 1] = func
        end
    end
    if #exact > 0 then
        for _, func in ipairs(variadic) do
            exact[#exact + 1] = func
        end
        return exact
    end
    return funcs
end

---@param args parser.object[]
---@return boolean
local function hasCallableVariableArg(args)
    for _, arg in ipairs(args) do
        if arg and arg.type ~= 'function' then
            local node = vm.compileNode(arg)
            for obj in node:eachObject() do
                if obj.type == 'function' or obj.type == 'doc.type.function' then
                    return true
                end
            end
        end
    end
    return false
end

---@param func parser.object
---@param args? parser.object[]
---@return parser.object[]?
function vm.getExactMatchedFunctions(func, args)
    local funcs = vm.getMatchedFunctions(func, args)
    if not funcs then
        return funcs
    end
    args = args or {}
    if #funcs == 1 then
        return funcs
    end
    local uri = guide.getUri(func)
    funcs = filterExplicitTableOverloads(uri, args, func, funcs)
    if #funcs == 1 then
        return funcs
    end
    funcs = filterMethodSelfOverloads(uri, args, func, funcs)
    if #funcs == 1 then
        return funcs
    end
    funcs = filterExactArityOverloads(args, func, funcs)
    if #funcs == 1 then
        return funcs
    end
    local matchScores = {}
    for i, n in ipairs(funcs) do
        matchScores[i] = calcFunctionMatchScore(uri, func, args, n)
    end

    local maxMatchScore = math.max(table.unpack(matchScores))
    if maxMatchScore == -1 then
        if hasCallableVariableArg(args) then
            return funcs
        end
        return nil
    end

    local minMatchScore = math.min(table.unpack(matchScores))
    if minMatchScore == maxMatchScore then
        -- all should be kept
        return funcs
    end

    -- remove functions that have matchScore < maxMatchScore
    local needRemove = {}
    for i, matchScore in ipairs(matchScores) do
        if matchScore < maxMatchScore then
            needRemove[#needRemove + 1] = i
        end
    end
    util.tableMultiRemove(funcs, needRemove)
    return funcs
end

---@param func parser.object
---@param args? parser.object[]
---@param mark? table
---@return parser.object[]?
function vm.getMatchedFunctions(func, args, mark)
    local funcs = {}
    local node = vm.compileNode(func)
    node = node.originNode or node
    for n in node:eachObject() do
        if n.type == 'function'
        or n.type == 'doc.type.function' then
            funcs[#funcs+1] = n
        end
    end

    local amin, amax = vm.countList(args, mark)

    local matched = {}
    for _, n in ipairs(funcs) do
        local argOffset = getMethodArgOffset(func, args, n)
        local min, max = vm.countParamsOfFunction(n)
        min = math.max(0, min - argOffset)
        if max ~= math.huge then
            max = math.max(0, max - argOffset)
        end
        if amin >= min and amax <= max then
            matched[#matched+1] = n
        end
    end

    if #matched == 0 then
        return nil
    end

    local overloadMatched = {}
    local hasOverloadedImpl = false
    for _, n in ipairs(matched) do
        if n.type == 'doc.type.function' then
            overloadMatched[#overloadMatched+1] = n
        elseif n.type == 'function' and vm.isFunctionWithOnlyOverloads(n) then
            hasOverloadedImpl = true
        end
    end
    if hasOverloadedImpl and #overloadMatched > 0 then
        for _, overload in ipairs(overloadMatched) do
            if hasExplicitReturns(overload) then
                return overloadMatched
            end
        end
    end

    return matched
end

---@param func table
---@return boolean
function vm.isVarargFunctionWithOverloads(func)
    if func.type ~= 'function' then
        return false
    end
    if not func.args then
        return false
    end
    if func._varargFunction ~= nil then
        return func._varargFunction
    end
    if func.args[1] and func.args[1].type == 'self' then
        if not func.args[2] or func.args[2].type ~= '...' then
            func._varargFunction = false
            return false
        end
    else
        if not func.args[1] or func.args[1].type ~= '...' then
            func._varargFunction = false
            return false
        end
    end
    local docs = getFunctionDocs(func)
    if not docs then
        func._varargFunction = false
        return false
    end
    for _, doc in ipairs(docs) do
        if doc.type == 'doc.overload' then
            func._varargFunction = true
            return true
        end
    end
    func._varargFunction = false
    return false
end

---@param func table
---@return boolean
function vm.isFunctionWithOnlyOverloads(func)
    if func.type ~= 'function' then
        return false
    end
    if func._onlyOverloadFunction ~= nil then
        return func._onlyOverloadFunction
    end

    local docs = getFunctionDocs(func)
    if not docs then
        func._onlyOverloadFunction = false
        return false
    end
    local hasOverload = false
    for _, doc in ipairs(docs) do
        if doc.type == 'doc.overload' then
            hasOverload = true
        elseif doc.type == 'doc.param'
        or doc.type == 'doc.return'
        then
            -- has specified @param or @return, thus not only @overload
            func._onlyOverloadFunction = false
            return false
        end
    end
    func._onlyOverloadFunction = hasOverload
    return hasOverload
end

---@param func parser.object
---@return boolean
function vm.isEmptyFunction(func)
    if #func > 0 then
        return false
    end
    local startRow  = guide.rowColOf(func.start)
    local finishRow = guide.rowColOf(func.finish)
    return finishRow - startRow <= 1
end
