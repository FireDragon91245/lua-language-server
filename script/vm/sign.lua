local guide         = require 'parser.guide'
---@class vm
local vm            = require 'vm.vm'

---@class vm.sign
---@field parent    parser.object
---@field signList  vm.node[]
---@field docGeneric parser.object[]
---@field varargIndex? integer
local mt = {}
mt.__index = mt
mt.type = 'sign'

---@param uri uri?
---@param source parser.object|vm.node|vm.node.object|any
---@return string
local function debugCollectView(uri, source)
    if not source then
        return 'nil'
    end
    if type(source) ~= 'table' then
        return tostring(source)
    end
    if source.type == 'vm.node' then
        local ok, view = pcall(vm.getInfer(source).view, vm.getInfer(source), uri)
        if ok and view then
            return view
        end
        return 'vm.node'
    end
    local ok, view = pcall(vm.getInfer(source).view, vm.getInfer(source), uri)
    if ok and view then
        return view
    end
    return source.type or tostring(source)
end

---@param uri uri?
---@param tag string
---@param message string
local function debugCollectTrace(uri, tag, message)
    local state = rawget(_G, 'DEBUG_COLLECT_GENERIC')
    if not state then
        return
    end
    if state.onlyUri and uri ~= state.onlyUri then
        return
    end
    local traces = state.traces
    if not traces then
        traces = {}
        state.traces = traces
    end
    traces[#traces+1] = ('[%s] %s'):format(tag, message)
end

---@param node vm.node
function mt:addSign(node)
    self.signList[#self.signList+1] = node
end

---@param doc parser.object
function mt:addDocGeneric(doc)
    self.docGeneric[#self.docGeneric+1] = doc
end

---@param index integer
function mt:setVarargIndex(index)
    self.varargIndex = index
end

---@param uri uri
---@param args parser.object
---@return table<string, vm.node>?
function mt:resolve(uri, args)
    if not args then
        return nil
    end

    ---@type table<string, vm.node>
    local resolved = {}
    ---@type table<string, boolean>
    local visited = {}

    ---@param call parser.object
    ---@param returnIndex integer
    ---@return vm.node?
    local function resolveCallExpression(call, returnIndex)
        local resultNode = vm.createNode()
        local hasResolved = false
        local callNode = vm.compileNode(call.node)
        if (call.node.type == 'getfield' or call.node.type == 'getmethod') and vm.getInfer(callNode):view(uri) == 'unknown' then
            local key = guide.getKeyName(call.node)
            if key then
                local rebuiltCallNode = vm.createNode()
                local parentNode = call.node.node
                if parentNode and parentNode.type == 'getlocal' then
                    parentNode = guide.getLocal(parentNode, parentNode[1], parentNode.start) or parentNode
                end
                local function mergeCandidates(source)
                    vm.compileByParentNode(source, key, function (src)
                        rebuiltCallNode:merge(vm.compileNode(src))
                    end)
                end
                if parentNode then
                    mergeCandidates(parentNode)
                end
                if parentNode and parentNode.type == 'local' and parentNode.value then
                    mergeCandidates(parentNode.value)
                end
                if not rebuiltCallNode:isEmpty() then
                    callNode = rebuiltCallNode
                end
            end
        end
        debugCollectTrace(uri, 'sign.resolve.call-fallback.callee', ('returnIndex=%d callee=%s'):format(returnIndex, debugCollectView(uri, callNode)))
        for funcNode in callNode:eachObject() do
            if funcNode.type == 'function' or funcNode.type == 'doc.type.function' then
                ---@cast funcNode parser.object
                local returnObject = vm.getReturnOfFunction(funcNode, returnIndex)
                if returnObject then
                    debugCollectTrace(uri, 'sign.resolve.call-fallback.return', ('func=%s return=%s'):format(funcNode.type, debugCollectView(uri, returnObject)))
                    for returnNode in vm.compileNode(returnObject):eachObject() do
                        if returnNode.type == 'generic' and returnNode.sign and call.args then
                            local resolvedGeneric = returnNode.sign:resolve(uri, call.args)
                            debugCollectTrace(uri, 'sign.resolve.call-fallback.generic', ('resolved=%s'):format(debugCollectView(uri, resolvedGeneric and next(resolvedGeneric) and select(2, next(resolvedGeneric)) or nil)))
                            if resolvedGeneric then
                                local protoNode = vm.compileNode(returnNode.proto)
                                for proto in protoNode:eachObject() do
                                    resultNode:merge(vm.cloneObject(proto, resolvedGeneric) or proto)
                                    hasResolved = true
                                end
                            else
                                resultNode:merge(returnNode)
                                hasResolved = true
                            end
                        else
                            resultNode:merge(returnNode)
                            hasResolved = true
                        end
                    end
                end
            end
        end
        if hasResolved then
            return resultNode
        end
        return nil
    end

    ---@param object vm.node|vm.node.object
    ---@param node   vm.node
    local function resolve(object, node)
        local visitedHash = ("%s|%s"):format(object, node)
        if visited[visitedHash] then
            return -- prevent circular resolve calls by only visiting each pair once
        end
        visited[visitedHash] = true
        if object.type == 'vm.node' then
            for o in object:eachObject() do
                resolve(o, node)
            end
            return
        end
        if object.type == 'doc.type' then
            ---@cast object parser.object
            resolve(vm.compileNode(object), node)
            return
        end
        if object.type == 'doc.generic.name' then
            ---@type string
            local key = object[1]
            debugCollectTrace(uri, 'sign.resolve.generic', ('key=%s node=%s literal=%s'):format(key, debugCollectView(uri, node), tostring(not not object.literal)))
            if object.literal then
                -- 'number' -> `T`
                for n in node:eachObject() do
                    local typeName
                    if n.type == 'string' then
                        ---@cast n parser.object
                        local candidate = object.pattern and object.pattern:format(n[1]) or n[1]
                        if guide.isBasicType(candidate) or vm.getGlobal('type', candidate) then
                            typeName = candidate
                        else
                            typeName = 'string'
                        end
                        if typeName and typeName ~= 'unknown' then
                            local type = vm.declareGlobal('type', typeName, guide.getUri(n))
                            resolved[key] = vm.createNode(type, resolved[key])
                        end
                    else
                        typeName = vm.getInfer(n):view(uri)
                        if typeName and guide.isBasicType(typeName) and typeName ~= 'unknown' then
                            local type = vm.declareGlobal('type', typeName, guide.getUri(n))
                            resolved[key] = vm.createNode(type, resolved[key])
                        end
                    end
                end
            else
                -- number -> T
                for n in node:eachObject() do
                    if  n.type ~= 'doc.generic.name'
                    and n.type ~= 'generic' then
                        if resolved[key] then
                            resolved[key]:merge(n)
                        else
                            resolved[key] = vm.createNode(n)
                        end
                    end
                end
                if resolved[key] and node:isOptional() then
                    resolved[key]:addOptional()
                end
            end
            return
        end
        if object.type == 'doc.type.array' then
            for n in node:eachObject() do
                if n.type == 'doc.type.array' then
                    -- number[] -> T[]
                    resolve(object.node, vm.compileNode(n.node))
                end
                if n.type == 'doc.type.table' then
                    -- { [integer]: number } -> T[]
                    local tvalueNode = vm.getTableValue(uri, node, 'integer', true)
                    if tvalueNode then
                        resolve(object.node, tvalueNode)
                    end
                end
                if n.type == 'global' and n.cate == 'type' then
                    -- ---@field [integer]: number -> T[]
                    ---@cast n vm.global
                    vm.getClassFields(uri, n, vm.declareGlobal('type', 'integer'), function (field)
                        resolve(object.node, vm.compileNode(field.extends))
                    end)
                end
                if n.type == 'table' and #n >= 1 then
                    -- { x } / { ... } -> T[]
                    resolve(object.node, vm.compileNode(n[1]))
                end
            end
            return
        end
        if object.type == 'doc.type.sign' then
            if not object.node or not object.node[1] or not object.signs then
                return
            end
            for n in node:eachObject() do
                if n.type == 'doc.type.sign'
                and n.node
                and n.node[1] == object.node[1]
                and n.signs then
                    for i, sign in ipairs(object.signs) do
                        local resolvedSign = n.signs[i]
                        if resolvedSign then
                            resolve(sign, vm.compileNode(resolvedSign))
                        end
                    end
                end
            end
            return
        end
        if object.type == 'doc.type.table' then
            for _, ufield in ipairs(object.fields) do
                local ufieldNode = vm.compileNode(ufield.name)
                local uvalueNode = vm.compileNode(ufield.extends)
                local firstField = ufieldNode:get(1)
                local firstValue = uvalueNode:get(1)
                if not firstField or not firstValue then
                    goto CONTINUE
                end
                if firstField.type == 'doc.generic.name' and firstValue.type == 'doc.generic.name' then
                    -- { [number]: number} -> { [K]: V }
                    local tfieldNode = vm.getTableKey(uri, node, 'any', true)
                    local tvalueNode = vm.getTableValue(uri, node, 'any', true)
                    if tfieldNode then
                        resolve(firstField, tfieldNode)
                    end
                    if tvalueNode then
                        resolve(firstValue, tvalueNode)
                    end
                else
                    if ufieldNode:get(1).type == 'doc.generic.name' then
                        -- { [number]: number}|number[] -> { [K]: number }
                        local tnode = vm.getTableKey(uri, node, uvalueNode, true)
                        if tnode then
                            resolve(firstField, tnode)
                        end
                    elseif uvalueNode:get(1).type == 'doc.generic.name' then
                        -- { [number]: number}|number[] -> { [number]: V }
                        local tnode = vm.getTableValue(uri, node, ufieldNode, true)
                        if tnode then
                            resolve(firstValue, tnode)
                        end
                    end
                end
                ::CONTINUE::
            end
            return
        end
        if object.type == 'doc.type.function' then
            local currentObject = vm.cloneObject(object, resolved) or object
            debugCollectTrace(uri, 'sign.resolve.callback', ('args=%d returns=%d node=%s'):format(#currentObject.args, #currentObject.returns, debugCollectView(uri, node)))
            for i, arg in ipairs(currentObject.args) do
                if arg.extends then
                    for n in node:eachObject() do
                        if n.type == 'function'
                        or n.type == 'doc.type.function' then
                            ---@cast n parser.object
                            local farg = n.args and n.args[i]
                            if farg then
                                resolve(arg.extends, vm.compileNode(farg))
                            end
                        end
                    end
                end
            end
            for i, ret in ipairs(currentObject.returns) do
                local returnNodes = {}
                local hasConcreteReturn = false
                for n in node:eachObject() do
                    if n.type == 'function'
                    or n.type == 'doc.type.function' then
                        ---@cast n parser.object
                        if n.type == 'function' and n.args and currentObject.args then
                            for argIndex, expectedArg in ipairs(currentObject.args) do
                                local actualArg = n.args[argIndex]
                                if actualArg and expectedArg.extends then
                                    vm.setNode(actualArg, vm.compileNode(expectedArg.extends), true)
                                    if actualArg.ref then
                                        for _, ref in ipairs(actualArg.ref) do
                                            vm.removeNode(ref)
                                        end
                                    end
                                end
                            end
                            local cachedReturns = rawget(n, '_returns')
                            if cachedReturns then
                                for _, cachedReturn in ipairs(cachedReturns) do
                                    vm.removeNode(cachedReturn)
                                end
                                rawset(n, '_returns', nil)
                            end
                            if n.returns then
                                for _, returnList in ipairs(n.returns) do
                                    for _, returnNode in ipairs(returnList) do
                                        vm.removeNode(returnNode)
                                        if returnNode.type == 'call' and returnNode.node then
                                            local cachedCallReturns = rawget(returnNode.node, '_callReturns')
                                            if cachedCallReturns then
                                                for _, cachedCallReturn in ipairs(cachedCallReturns) do
                                                    vm.removeNode(cachedCallReturn)
                                                end
                                                rawset(returnNode.node, '_callReturns', nil)
                                            end
                                        end
                                    end
                                end
                            end
                            vm.removeNode(n)
                        end
                        local fret = vm.getReturnOfFunction(n, i)
                        local fretNode
                        if fret then
                            fretNode = vm.compileNode(fret)
                        end
                        debugCollectTrace(uri, 'sign.resolve.callback.return', ('index=%d source=%s fret=%s'):format(i, n.type, debugCollectView(uri, fretNode)))
                        if n.type == 'function'
                        and fretNode
                        and vm.getInfer(fretNode):view(uri) == 'unknown'
                        and n.returns then
                            local directReturnNodes = {}
                            local hasConcreteDirectReturn = false
                            for _, returnList in ipairs(n.returns) do
                                local selectedNode, selectedExp = vm.selectNode(returnList, i)
                                if selectedExp then
                                    vm.removeNode(selectedExp)
                                    if selectedExp.node then
                                        vm.removeNode(selectedExp.node)
                                        if selectedExp.node.node then
                                            vm.removeNode(selectedExp.node.node)
                                        end
                                    end
                                    if selectedExp.args then
                                        for _, arg in ipairs(selectedExp.args) do
                                            vm.removeNode(arg)
                                        end
                                    end
                                    if selectedExp.type == 'call' and selectedExp.node then
                                        local cachedCallReturns = rawget(selectedExp.node, '_callReturns')
                                        if cachedCallReturns then
                                            for _, cachedCallReturn in ipairs(cachedCallReturns) do
                                                vm.removeNode(cachedCallReturn)
                                            end
                                            rawset(selectedExp.node, '_callReturns', nil)
                                        end
                                    end
                                    selectedNode = vm.compileNode(selectedExp)
                                    if vm.getInfer(selectedNode):view(uri) == 'unknown' and selectedExp.type == 'call' then
                                        selectedNode = resolveCallExpression(selectedExp, i) or selectedNode
                                    end
                                end
                                debugCollectTrace(uri, 'sign.resolve.callback.direct-selected', ('index=%d exp=%s node=%s'):format(
                                    i,
                                    selectedExp and selectedExp.type or 'nil',
                                    debugCollectView(uri, selectedNode)
                                ))
                                if selectedExp and selectedExp.type == 'call' and selectedExp.node then
                                    debugCollectTrace(uri, 'sign.resolve.callback.direct-selected.callee', ('index=%d callee=%s'):format(
                                        i,
                                        debugCollectView(uri, vm.compileNode(selectedExp.node))
                                    ))
                                end
                                if selectedNode and vm.getInfer(selectedNode):view(uri) ~= 'unknown' then
                                    directReturnNodes[#directReturnNodes+1] = selectedNode
                                    hasConcreteDirectReturn = true
                                end
                            end
                            if hasConcreteDirectReturn then
                                for _, directReturnNode in ipairs(directReturnNodes) do
                                    returnNodes[#returnNodes+1] = directReturnNode
                                end
                                debugCollectTrace(uri, 'sign.resolve.callback.direct-return', ('index=%d direct=%s'):format(i, table.concat((function ()
                                    local views = {}
                                    for idx = 1, #directReturnNodes do
                                        views[idx] = debugCollectView(uri, directReturnNodes[idx])
                                    end
                                    return views
                                end)(), ', ')))
                                hasConcreteReturn = true
                                goto CONTINUE
                            end
                        end
                        if fretNode then
                            returnNodes[#returnNodes+1] = fretNode
                            if vm.getInfer(fretNode):view(uri) ~= 'unknown' then
                                hasConcreteReturn = true
                            end
                        end
                    end
                    ::CONTINUE::
                end
                for _, fretNode in ipairs(returnNodes) do
                    if not (hasConcreteReturn and vm.getInfer(fretNode):view(uri) == 'unknown') then
                        debugCollectTrace(uri, 'sign.resolve.callback.apply-return', ('index=%d return=%s'):format(i, debugCollectView(uri, fretNode)))
                        resolve(ret, fretNode)
                    end
                end
            end
            return
        end
    end

    ---@param sign vm.node
    ---@return table<string, true>
    ---@return table<string, true>
    local function getSignInfo(sign)
        local knownTypes = {}
        local genericsNames   = {}
        for obj in sign:eachObject() do
            if obj.type == 'doc.generic.name' then
                genericsNames[obj[1]] = true
                goto CONTINUE
            end
            if obj.type == 'doc.type.table'
            or obj.type == 'doc.type.function'
            or obj.type == 'doc.type.array'
            or obj.type == 'doc.type.sign' then
                ---@cast obj parser.object
                local hasGeneric
                guide.eachSourceType(obj, 'doc.generic.name', function (src)
                    hasGeneric = true
                    genericsNames[src[1]] = true
                end)
                if hasGeneric then
                    goto CONTINUE
                end
            end
            if obj.type == 'variable'
            or obj.type == 'local' then
                goto CONTINUE
            end
            local view = vm.getInfer(obj):view(uri)
            if view then
                knownTypes[view] = true
            end
            ::CONTINUE::
        end
        return knownTypes, genericsNames
    end

    -- remove un-generic type
    ---@param argNode vm.node
    ---@param sign vm.node
    ---@param knownTypes table<string, true>
    ---@return vm.node
    local function buildArgNode(argNode, sign, knownTypes)
        local newArgNode = vm.createNode()
        local needRemoveNil = sign:hasFalsy()
        for n in argNode:eachObject() do
            if needRemoveNil then
                if n.type == 'nil' then
                    goto CONTINUE
                end
                if n.type == 'global' and n.cate == 'type' and n.name == 'nil' then
                    goto CONTINUE
                end
            end
            local view = vm.getInfer(n):view(uri)
            if knownTypes[view] then
                goto CONTINUE
            end
            newArgNode:merge(n)
            ::CONTINUE::
        end
        if not needRemoveNil and argNode:isOptional() then
            newArgNode:addOptional()
        end
        return newArgNode
    end

    ---@param node vm.node
    ---@return vm.node
    local function normalizeVariadicNode(node)
        ---@param obj vm.node.object
        ---@return 'integer'|'number'?
        local function getNumericKind(obj)
            if obj.type == 'integer' or obj.type == 'doc.type.integer' then
                return 'integer'
            end
            if obj.type == 'number' then
                return 'number'
            end
            if obj.type == 'global' and obj.cate == 'type' then
                if obj.name == 'integer' then
                    return 'integer'
                end
                if obj.name == 'number' then
                    return 'number'
                end
            end
            return nil
        end

        local normalized = vm.createNode()
        local others = vm.createNode()
        local hasInteger = false
        local hasNumber = false
        for n in node:eachObject() do
            local numericKind = getNumericKind(n)
            if numericKind == 'integer' then
                hasInteger = true
                goto CONTINUE
            end
            if numericKind == 'number' then
                hasNumber = true
                goto CONTINUE
            end
            others:merge(n)
            ::CONTINUE::
        end
        if hasNumber then
            normalized:merge(vm.declareGlobal('type', 'number'))
        elseif hasInteger then
            normalized:merge(vm.declareGlobal('type', 'integer'))
        end
        normalized:merge(others)
        if normalized:isEmpty() then
            return node
        end
        return normalized
    end

    ---@param arg parser.object
    ---@return vm.node
    local function getVariadicArgNode(arg)
        local argNode = vm.compileNode(arg)
        if arg.type == 'table' then
            local valueNode = vm.getTableValue(uri, argNode, 'integer', true)
            if valueNode and not valueNode:isEmpty() then
                return valueNode
            end
        end
        return argNode
    end

    ---@param startIndex integer
    ---@return vm.node
    local function buildVariadicArgNode(startIndex)
        local merged = vm.createNode()
        for i = startIndex, #args do
            merged:merge(getVariadicArgNode(args[i]))
        end
        return normalizeVariadicNode(merged)
    end

    ---@param genericNames table<string, true>
    local function isAllResolved(genericNames)
        for n in pairs(genericNames) do
            if not resolved[n] then
                return false
            end
        end
        return true
    end

    for i, arg in ipairs(args) do
        local sign = self.signList[i]
        if not sign and self.varargIndex and i >= self.varargIndex then
            sign = self.signList[self.varargIndex]
        end
        if not sign then
            break
        end
        local argNode
        if self.varargIndex and i >= self.varargIndex then
            argNode = buildVariadicArgNode(i)
        else
            argNode = vm.compileNode(arg)
        end
        local knownTypes, genericNames = getSignInfo(sign)
        if not isAllResolved(genericNames) then
            local newArgNode = buildArgNode(argNode, sign, knownTypes)
            resolve(sign, newArgNode)
        end
        if self.varargIndex and i >= self.varargIndex then
            break
        end
    end

    return resolved
end

---@return vm.sign
function vm.createSign()
    local genericMgr = setmetatable({
        signList  = {},
        docGeneric = {},
        varargIndex = nil,
    }, mt)
    return genericMgr
end

---@class parser.object
---@field package _sign vm.sign|false|nil

---@param source parser.object
---@param sign vm.sign
function vm.setSign(source, sign)
    source._sign = sign
end

---@param source parser.object
---@return vm.sign?
function vm.getSign(source)
    if source._sign ~= nil then
        return source._sign or nil
    end
    source._sign = false
    if source.type == 'function' then
        if not source.bindDocs then
            return nil
        end
        for _, doc in ipairs(source.bindDocs) do
            if doc.type == 'doc.generic' then
                if not source._sign then
                    source._sign = vm.createSign()
                end
                source._sign:addDocGeneric(doc)
            end
        end
        if not source._sign then
            return nil
        end
        if source.args then
            for index, arg in ipairs(source.args) do
                local argNode = vm.compileNode(arg)
                if arg.optional then
                    argNode:addOptional()
                end
                source._sign:addSign(argNode)
                if arg.type == '...' then
                    source._sign:setVarargIndex(index)
                end
            end
        end
    end
    if source.type == 'doc.type.function'
    or source.type == 'doc.type.table'
    or source.type == 'doc.type.array' then
        local hasGeneric
        guide.eachSourceType(source, 'doc.generic.name', function (_)
            hasGeneric = true
        end)
        if not hasGeneric then
            return nil
        end
        source._sign = vm.createSign()
        if source.type == 'doc.type.function' then
            for index, arg in ipairs(source.args) do
                if arg.extends then
                    local argNode = vm.compileNode(arg.extends)
                    if arg.optional then
                        argNode:addOptional()
                    end
                    source._sign:addSign(argNode)
                else
                    source._sign:addSign(vm.createNode())
                end
                if arg.name and arg.name[1] == '...' then
                    source._sign:setVarargIndex(index)
                end
            end
        end
    end
    return source._sign or nil
end
