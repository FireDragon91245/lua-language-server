local guide   = require 'parser.guide'
---@class vm
local vm      = require 'vm.vm'

---@class parser.object
---@field package _generic vm.generic
---@field package _resolved vm.node

---@class vm.generic
---@field sign  vm.sign
---@field proto vm.object
local mt = {}
mt.__index = mt
mt.type = 'generic'

---@param source table?
---@return string?
local function getSingleGenericKey(source)
    if not source then
        return nil
    end
    if source.type == 'doc.generic.name' then
        return source[1]
    end
    if source.type == 'doc.type' and source.types and #source.types == 1 then
        local inner = source.types[1]
        if inner.type == 'doc.generic.name' then
            return inner[1]
        end
    end
    return nil
end

---@param source parser.object
---@param resolved table<string, vm.node>
---@return vm.node?
local function getNilFilteredGenericNode(source, resolved)
    if not source.optional
    or not source.parent
    or source.parent.type ~= 'doc.type'
    or not source.parent.types
    or #source.parent.types <= 1 then
        return nil
    end

    local key = getSingleGenericKey(source)
    if not key or not resolved[key] then
        return nil
    end

    local filteredNode = resolved[key]:copy()
    filteredNode:remove('nil')
    filteredNode:removeOptional()
    if filteredNode:isEmpty() then
        return vm.createNode()
    end
    return filteredNode
end

---@param source table?
---@param resolved table<string, vm.node>
---@return boolean
local function hasResolvedGenericReference(source, resolved)
    if not source then
        return false
    end
    if (source.type == 'doc.type.name' or source.type == 'doc.generic.name') and source[1] then
        return resolved[source[1]] ~= nil
    end
    if source.type == 'doc.type' and source.types then
        for _, typeUnit in ipairs(source.types) do
            if hasResolvedGenericReference(typeUnit, resolved) then
                return true
            end
        end
        return false
    end
    if source.type == 'doc.type.arg' then
        return hasResolvedGenericReference(source.extends, resolved)
    end
    if source.type == 'doc.type.array' then
        return hasResolvedGenericReference(source.node, resolved)
    end
    if source.type == 'doc.type.table' and source.fields then
        for _, field in ipairs(source.fields) do
            if hasResolvedGenericReference(field.name, resolved)
            or hasResolvedGenericReference(field.extends, resolved) then
                return true
            end
        end
        return false
    end
    if source.type == 'doc.type.function' then
        for _, arg in ipairs(source.args or {}) do
            if hasResolvedGenericReference(arg, resolved) then
                return true
            end
        end
        for _, ret in ipairs(source.returns or {}) do
            if hasResolvedGenericReference(ret, resolved) then
                return true
            end
        end
        return false
    end
    if source.type == 'doc.type.sign' and source.signs then
        for _, sign in ipairs(source.signs) do
            if hasResolvedGenericReference(sign, resolved) then
                return true
            end
        end
        return false
    end
    return false
end

---@param source    table?
---@param resolved? table<string, vm.node>
---@return vm.object?
local function cloneObject(source, resolved)
    if not resolved or not source then
        return source
    end
    if source.type == 'doc.generic.name' then
        local key = source[1]
        local newName = {
            type   = source.type,
            start  = source.start,
            finish = source.finish,
            parent = source.parent,
            [1]    = source[1],
        }
        if resolved[key] then
            vm.setNode(newName, resolved[key], true)
            newName._resolved = resolved[key]
        end
        return newName
    end
    if source.type == 'doc.type.name' then
        local key = source[1]
        if resolved[key] then
            local newName = {
                type   = 'doc.generic.name',
                start  = source.start,
                finish = source.finish,
                parent = source.parent,
                [1]    = source[1],
            }
            vm.setNode(newName, resolved[key], true)
            newName._resolved = resolved[key]
            return newName
        end
    end
    if source.type == 'doc.type' then
        local nilFilteredNode = resolved and getNilFilteredGenericNode(source, resolved)
        if nilFilteredNode and nilFilteredNode:isEmpty() then
            return nil
        end

        local effectiveResolved = resolved
        local preserveOptional = source.optional
        if nilFilteredNode then
            local key = getSingleGenericKey(source)
            effectiveResolved = setmetatable({
                [key] = nilFilteredNode,
            }, {
                __index = resolved,
            })
            preserveOptional = false
        end

        local newType = {
            type     = source.type,
            start    = source.start,
            finish   = source.finish,
            parent   = source.parent,
            optional = preserveOptional,
            types    = {},
        }
        for i, typeUnit in ipairs(source.types) do
            local newObj = cloneObject(typeUnit, effectiveResolved)
            if newObj then
                if type(newObj) == 'table' then
                    newObj.parent = newType
                end
                newType.types[#newType.types+1] = newObj
            end
        end
        if #newType.types == 0 then
            return nil
        end
        return newType
    end
    if source.type == 'doc.type.arg' then
        local newArg = {
            type    = source.type,
            start   = source.start,
            finish  = source.finish,
            parent  = source.parent,
            name    = source.name,
            extends = cloneObject(source.extends, resolved)
        }
        return newArg
    end
    if source.type == 'doc.type.array' then
        local newArray = {
            type   = source.type,
            start  = source.start,
            finish = source.finish,
            parent = source.parent,
            node   = cloneObject(source.node, resolved),
        }
        return newArray
    end
    if source.type == 'doc.type.table' then
        local newTable = {
            type   = source.type,
            start  = source.start,
            finish = source.finish,
            parent = source.parent,
            fields = {},
        }
        for i, field in ipairs(source.fields) do
            local newField = {
                type    = field.type,
                start   = field.start,
                finish  = field.finish,
                parent  = newTable,
                name    = cloneObject(field.name, resolved),
                extends = cloneObject(field.extends, resolved),
            }
            newTable.fields[i] = newField
        end
        return newTable
    end
    if source.type == 'doc.type.function' then
        local newDocFunc = {
            type    = source.type,
            start   = source.start,
            finish  = source.finish,
            parent  = source.parent,
            args    = {},
            returns = {},
        }
        for i, arg in ipairs(source.args) do
            local newObj = cloneObject(arg, resolved)
            newObj.optional    = arg.optional
            newDocFunc.args[i] = newObj
        end
        for i, ret in ipairs(source.returns) do
            local newObj = cloneObject(ret, resolved)
            newObj.parent   = newDocFunc
            newObj.optional = ret.optional
            newDocFunc.returns[i] = newObj
        end
        return newDocFunc
    end
    if source.type == 'doc.type.sign' and source.signs then
        local isClassGeneric = false
        if source.node and source.node[1] then
            local globalVar = vm.getGlobal('type', source.node[1])
            if globalVar then
                for _, set in ipairs(globalVar:getSets(guide.getUri(source))) do
                    if set.type == 'doc.class' and set.signs then
                        isClassGeneric = true
                        break
                    end
                end
            end
        end
        local needsClone = false
        if isClassGeneric then
            for _, sign in ipairs(source.signs) do
                if hasResolvedGenericReference(sign, resolved) then
                    needsClone = true
                end
                if needsClone then break end
            end
        end
        if needsClone then
            local newSign = {
                type   = source.type,
                start  = source.start,
                finish = source.finish,
                parent = source.parent,
                node   = source.node,
                signs  = {},
            }
            for i, sign in ipairs(source.signs) do
                newSign.signs[i] = cloneObject(sign, resolved)
            end
            return newSign
        end
    end
    return source
end

---@param uri uri
---@param args parser.object
---@return vm.node
function mt:resolve(uri, args)
    local resolved  = self.sign:resolve(uri, args)
    local protoNode = vm.compileNode(self.proto)
    local result = vm.createNode()
    for nd in protoNode:eachObject() do
        if nd.type == 'global' or nd.type == 'variable' then
            ---@cast nd vm.global | vm.variable
            result:merge(nd)
        else
            ---@cast nd -vm.global, -vm.variable
            local clonedObject = cloneObject(nd, resolved)
            if clonedObject then
                local clonedNode   = vm.compileNode(clonedObject)
                result:merge(clonedNode)
            end
        end
    end
    if protoNode:isOptional() then
        result:addOptional()
    end
    return result
end

---@param source parser.object
---@return vm.node?
function vm.getGenericResolved(source)
    if source.type ~= 'doc.generic.name' then
        return nil
    end
    return source._resolved
end

---@param source table
function vm.isGenericUnsolved(source)
    if source.type == 'doc.generic.name' and not source._resolved then
        return true
    end
    return false
end

---@param source parser.object
---@param generic vm.generic
function vm.setGeneric(source, generic)
    source._generic = generic
end

---@param source parser.object
---@return vm.generic?
function vm.getGeneric(source)
    return source._generic
end

---@param proto vm.object
---@param sign  vm.sign
---@return vm.generic
function vm.createGeneric(proto, sign)
    local generic = setmetatable({
        sign  = sign,
        proto = proto,
    }, mt)
    return generic
end

---@param source    table?
---@param resolved? table<string, vm.node>
---@return vm.object?
function vm.cloneObject(source, resolved)
    return cloneObject(source, resolved)
end
