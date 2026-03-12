-- Test generic function return type inference

TEST 'list<integer>' [[
---@class list<T>

---@generic T
---@param list list<T>
---@return list<T>
function list_from(list)
    return list
end

---@type list<integer>
local list = {}

local <?list2?> = list_from(list)
]]

TEST 'string' [[
---@generic T
---@param value T
---@return T
function identity(value)
    return value
end

---@type string
local myString = "hello"

local <?result?> = identity(myString)
]]

TEST 'integer' [[
---@generic T
---@param value T
---@return T
function identity(value)
    return value
end

---@type integer
local myInt = 42

local <?result?> = identity(myInt)
]]

TEST 'list<integer>' [[
---@class list<T>
---@class enumerable<T>

---@generic T
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
function list_from(list)
    return list
end

---@type list<integer>
local list = {}

local <?list2?> = list_from(list)
]]