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

TEST 'list<integer>' [[
---@class list<T>

---@generic T
---@param ... T
---@return list<T>
function list_of(...)
end

local <?list?> = list_of { 1, 2, 2, 3, 4, 4, 5 }
]]

TEST 'list<string|integer>' [[
---@class list<T>

---@generic T
---@param ... T
---@return list<T>
function list_of(...)
end

local <?list?> = list_of(1, '', 2, 3, '')
]]

TEST 'list<number>' [[
---@class list<T>

---@generic T
---@param ... T
---@return list<T>
function list_of(...)
end

local <?list?> = list_of(1, 1.1, 3)
]]

TEST 'list<number>' [[
---@class list<T>

---@generic T
---@param ... T
---@return list<T>
function list_of(...)
end

local <?list?> = list_of(1.1, 2.2, 3.3)
]]

TEST 'list<integer>' [[
---@class list<T>
---@class enumerable<T>

---@generic T
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
function make_list(...)
end

---@type integer
local test = 4

local list = make_list(1, 2, 2, 3, 4, test, 5)
local <?list2?> = make_list(list)
]]

TEST 'list<string|integer>' [[
---@class list<T>
---@class enumerable<T>

---@generic T
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
function make_list(...)
end

local <?list?> = make_list(1, '', 2, 3, '')
]]

TEST 'list<number>' [[
---@class list<T>
---@class enumerable<T>

---@generic T
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
function make_list(...)
end

local <?list?> = make_list(1, 1.1, 3)
]]

TEST 'list<number>' [[
---@class list<T>
---@class enumerable<T>

---@generic T
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
function make_list(...)
end

local <?list?> = make_list(1.1, 2.2, 3.3)
]]

TEST 'enumerable<string>' [[
---@class enumerable<T>

---@generic T, U
---@param self enumerable<T>
---@param selector fun(item: T): U
---@return enumerable<U>
function select(self, selector)
end

---@type enumerable<integer>
local source = nil

local <?result?> = select(source, function (item)
    return tostring(item)
end)
]]

TEST 'list<any>' [[
---@class list<T>
---@class enumerable<T>

---@generic T
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
---@overload fun(tbl: table): list<any>
function make_list(...)
end

---@type table
local source = {}

local <?result?> = make_list(source)
]]

TEST 'list<integer>' [[
---@class list<T>
---@class enumerable<T>

---@generic T
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
---@overload fun(tbl: table): list<any>
function make_list(...)
end

---@type list<integer>
local source = {}

local <?result?> = make_list(source)
]]