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
            if object.literal then
                -- 'number' -> `T`
                for n in node:eachObject() do
                    if n.type == 'string' then
                        ---@cast n parser.object
                        local type = vm.declareGlobal('type', object.pattern and object.pattern:format(n[1]) or n[1], guide.getUri(n))
                        resolved[key] = vm.createNode(type, resolved[key])
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
            for i, arg in ipairs(object.args) do
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
            for i, ret in ipairs(object.returns) do
                for n in node:eachObject() do
                    if n.type == 'function'
                    or n.type == 'doc.type.function' then
                        ---@cast n parser.object
                        local fret = vm.getReturnOfFunction(n, i)
                        if fret then
                            resolve(ret, vm.compileNode(fret))
                        end
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
        local views = {}
        local count = 0
        for n in node:eachObject() do
            local view = vm.getInfer(n):view(uri)
            if view and not views[view] then
                views[view] = true
                count = count + 1
                if count > 1 then
                    return vm.createNode(vm.declareGlobal('type', 'any'))
                end
            end
        end
        return node
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
