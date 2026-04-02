local files = require 'files'
local guide = require 'parser.guide'
local vm    = require 'vm'
local await = require 'await'
local lang  = require 'language'

local checkTypes = {
    'local',
    'setlocal',
    'setglobal',
}

---@param uri uri
---@param func parser.object
---@return boolean
local function returnsNoValueOrOnlyNil(uri, func)
    local _, max, def = vm.countReturnsOfFunction(func)
    if def <= 0 then
        return true
    end
    if max ~= def then
        return false
    end
    for index = 1, def do
        local ret = vm.getReturnOfFunction(func, index)
        if not ret or vm.getInfer(ret):view(uri) ~= 'nil' then
            return false
        end
    end
    return true
end

---@async
return function (uri, callback)
    local state = files.getState(uri)
    if not state then
        return
    end

    local delayer = await.newThrottledDelayer(15)
    ---@async
    guide.eachSourceTypes(state.ast, checkTypes, function (source)
        local value = source.value
        if value and value.type == 'select' then
            value = value.vararg
        end
        if not value or value.type ~= 'call' then
            return
        end
        delayer:delay()

        local funcs = vm.getExactMatchedFunctions(value.node, value.args)
                   or vm.getMatchedFunctions(value.node, value.args)
        if not funcs or #funcs == 0 then
            return
        end
        for _, func in ipairs(funcs) do
            if not returnsNoValueOrOnlyNil(uri, func) then
                return
            end
        end

        callback {
            start   = value.start,
            finish  = value.finish,
            message = lang.script('DIAG_ASSIGN_CALL_NIL'),
        }
    end)
end