---@class vm
local vm        = require 'vm.vm'
local util      = require 'utility'
local guide     = require 'parser.guide'

local simpleSwitch

simpleSwitch = util.switch()
    : case 'goto'
    : call(function (source, pushResult)
        if source.node then
            pushResult(source.node)
        end
    end)
    : case 'doc.cast.name'
    : call(function (source, pushResult)
        local loc = guide.getLocal(source, source[1], source.start)
        if loc then
            pushResult(loc)
        end
    end)
    : case 'doc.field'
    : call(function (source, pushResult)
        pushResult(source)
    end)

---@param source  parser.object
---@param pushResult fun(src: parser.object)
local function searchBySimple(source, pushResult)
    simpleSwitch(source.type, source, pushResult)
end

---@param source  parser.object
---@param pushResult fun(src: parser.object)
local function searchByLocalID(source, pushResult)
    local idSources = vm.getVariableSets(source)
    if not idSources then
        return
    end
    for _, src in ipairs(idSources) do
        pushResult(src)
    end
end

local function searchByNode(source, pushResult)
    local node = vm.compileNode(source)
    local suri = guide.getUri(source)
    for n in node:eachObject() do
        if n.type == 'global' then
            for _, set in ipairs(n:getSets(suri)) do
                pushResult(set)
            end
        else
            pushResult(n)
        end
    end
end

---@param source parser.object
---@return       parser.object[]
function vm.getDefs(source)
    local results = {}
    local mark    = {}

    local hasLocal
    local function pushResult(src)
        if src.type == 'local' then
            if hasLocal then
                return
            end
            hasLocal = true
            if  source.type ~= 'local'
            and source.type ~= 'getlocal'
            and source.type ~= 'setlocal'
            and source.type ~= 'doc.cast.name' then
                return
            end
        end
        if not mark[src] then
            mark[src] = true
            if guide.isAssign(src)
            or guide.isLiteral(src) then
                results[#results+1] = src
            end
        end
    end

    searchBySimple(source, pushResult)
    searchByLocalID(source, pushResult)
    vm.compileByNodeChain(source, pushResult)
    searchByNode(source, pushResult)

    return results
end

local HAS_DEF_ERR = false  -- the error object for comparing
local function checkHasDef(checkFunc, source, pushResult)
    local _, err = pcall(checkFunc, source, pushResult)
    return err == HAS_DEF_ERR
end

---@param classGlobal vm.global?
---@param uri uri
---@return boolean
local function isAliasClass(classGlobal, uri)
    if not classGlobal then
        return false
    end
    for _, set in ipairs(classGlobal:getSets(uri)) do
        if set.type == 'doc.alias' then
            return true
        end
    end
    return false
end

---@param source parser.object
---@param object vm.node.object
---@return vm.global?
---@return string?
local function getMemberClassInfo(source, object)
    local classGlobal
    local typeName
    if object.type == 'global' and object.cate == 'type' then
        ---@cast object vm.global
        classGlobal = object
        typeName = object.name
    elseif object.type == 'doc.class' then
        ---@cast object parser.object
        classGlobal = vm.getGlobalNode(object)
        typeName = classGlobal and classGlobal.name or nil
    elseif object.type == 'doc.class.name' then
        ---@cast object parser.object
        classGlobal = vm.getGlobalNode(object.parent)
        typeName = classGlobal and classGlobal.name or nil
    elseif object.type == 'doc.type.name' and object[1] then
        typeName = object[1]
        classGlobal = vm.getGlobal('type', typeName)
    elseif object.type == 'doc.type.sign' and object.node and object.node[1] then
        typeName = object.node[1]
        classGlobal = vm.getGlobal('type', typeName)
    elseif object.type == 'string' or object.type == 'doc.type.string' then
        typeName = 'string'
        classGlobal = vm.getGlobal('type', typeName)
    elseif object.type ~= 'global' and object.type ~= 'generic' and object.type ~= 'variable' then
        ---@cast object parser.object
        classGlobal = vm.getDefinedClass(guide.getUri(source), object)
        typeName = classGlobal and classGlobal.name or nil
    end
    return classGlobal, typeName
end

---@param source parser.object
---@param receiverNode vm.node
---@return string[]
local function getReceiverViews(source, receiverNode)
    local uri = guide.getUri(source)
    local mark = {}
    local views = {}
    for object in receiverNode:eachObject() do
        local view = vm.viewObject(object, uri)
        if view and not mark[view] then
            mark[view] = true
            views[#views+1] = view
        end
    end
    table.sort(views)
    return views
end

---@param source parser.object
---@param object vm.node.object
---@param key string
---@return boolean?
local function hasMemberOnObject(source, object, key)
    local uri = guide.getUri(source)
    local found = false

    local function markFound(_src)
        found = true
    end

    if object.type ~= 'global' and object.type ~= 'generic' then
        ---@cast object parser.object|vm.variable
        vm.compileByParentNode(object, key, markFound)
        if found then
            return true
        end
    end

    if object.type == 'global' then
        ---@cast object vm.global
        if object.cate == 'variable' then
            local globalField = vm.getGlobal('variable', object.name, key)
            if globalField then
                for _ in ipairs(globalField:getSets(uri)) do
                    return true
                end
            end
        end
    end

    local classGlobal, typeName = getMemberClassInfo(source, object)
    if classGlobal then
        if isAliasClass(classGlobal, uri) then
            return nil
        end
        local classSets = classGlobal:getSets(uri)
        if #classSets == 0 and not typeName then
            return nil
        end
        vm.getClassFields(uri, classGlobal, key, function (_field)
            found = true
        end)
        if found then
            return true
        end
        if #classSets == 0 then
            return nil
        end
    end
    if typeName then
        local globalField = vm.getGlobal('variable', typeName, key)
        if globalField then
            for _ in ipairs(globalField:getSets(uri)) do
                return true
            end
        end
    end

    if object.type == 'generic'
    or object.type == 'doc.generic.name' then
        return nil
    end

    return false
end

---@param source parser.object
function vm.hasDef(source)
    local mark = {}
    local hasLocal
    local function pushResult(src)
        if src.type == 'local' then
            if hasLocal then
                return
            end
            hasLocal = true
            if  source.type ~= 'local'
            and source.type ~= 'getlocal'
            and source.type ~= 'setlocal'
            and source.type ~= 'doc.cast.name' then
                return
            end
        end
        if not mark[src] then
            mark[src] = true
            if guide.isAssign(src)
            or guide.isLiteral(src) then
                -- break out on 1st result using error() with a unique error object
                error(HAS_DEF_ERR)
            end
        end
    end

    return checkHasDef(searchBySimple, source, pushResult)
        or checkHasDef(searchByLocalID, source, pushResult)
        or checkHasDef(vm.compileByNodeChain, source, pushResult)
        or checkHasDef(searchByNode, source, pushResult)
end

---@param source parser.object
---@return boolean
function vm.hasAllDefs(source)
    if source.type ~= 'getfield' and source.type ~= 'getmethod' then
        return vm.hasDef(source)
    end

    local key = guide.getKeyName(source)
    local receiver = source.node
    if not key or not receiver then
        return vm.hasDef(source)
    end

    local receiverNode = vm.compileNode(receiver)
    if #receiverNode == 0 then
        return vm.hasDef(source)
    end

    local receiverViews = getReceiverViews(source, receiverNode)
    if #receiverViews <= 1 then
        return vm.hasDef(source)
    end

    local checked = false
    local hasUnknown = false
    for object in receiverNode:eachObject() do
        checked = true
        local hasMember = hasMemberOnObject(source, object, key)
        if hasMember == nil then
            hasUnknown = true
        elseif not hasMember then
            return false
        end
    end

    if not checked then
        return false
    end
    if hasUnknown then
        return true
    end
    return true
end

---@param source parser.object
---@return string[]?
function vm.getUndefinedFieldViews(source)
    if source.type ~= 'getfield' and source.type ~= 'getmethod' then
        return nil
    end

    local key = guide.getKeyName(source)
    local receiver = source.node
    if not key or not receiver then
        return nil
    end

    local uri = guide.getUri(source)
    local receiverNode = vm.compileNode(receiver)
    local receiverViews = getReceiverViews(source, receiverNode)
    if #receiverViews <= 1 then
        return nil
    end

    local missingViews = {}
    local mark = {}
    for object in receiverNode:eachObject() do
        local hasMember = hasMemberOnObject(source, object, key)
        if hasMember == false then
            local view = vm.viewObject(object, uri)
            if view and not mark[view] then
                mark[view] = true
                missingViews[#missingViews+1] = view
            end
        end
    end

    if #missingViews == 0 then
        return nil
    end

    table.sort(missingViews)
    return missingViews
end
