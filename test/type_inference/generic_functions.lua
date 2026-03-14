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

TEST 'list<any>' [[
---@class list<T>
---@class enumerable<T>

local linq = {}

---@generic T
---@overload fun(): list<any>
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
---@overload fun(tbl: table): list<any>
function linq.list(...)
end

local <?result?> = linq.list()
]]

TEST 'list<integer>' [[
---@class list<T>
---@class enumerable<T>

local linq = {}

---@generic T
---@overload fun(): list<any>
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
---@overload fun(table: table): list<any>
function linq.list(...)
end

local <?abcd?> = linq.list(1)
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

TEST 'integer' [[
---@generic T
---@param item `T`
---@return T
local function id(item)
    return item
end

local <?value?> = id(1)
]]

TEST 'list<string|integer>' [[
---@class list<T>
local list = {}

---@generic T, U
---@param self list<T>
---@param item `U`
---@return list<T|U>
function list:addtransform(item)
    return self
end

---@type list<string>
local list3 = list

local <?list4?> = list3:addtransform(1)
]]

TEST 'list<number>' [[
---@class list<T>
local list = {}

---@generic T, U
---@param self list<T>
---@param item `U`
---@return list<T|U>
function list:addtransform(item)
    return self
end

---@type list<number>
local list3 = list

local <?list4?> = list3:addtransform(1)
]]

TEST 'list<string>' [[
---@class list<T>
local list = {}

---@generic T, U
---@param self list<T>
---@param item `U`
---@return list<T|U>
function list:addtransform(item)
    return self
end

---@type list<string>
local list3 = list

local <?list4?> = list3:addtransform("1")
]]

TEST 'list<string>' [[
---@class enumerable<T>
---@class list<T>: enumerable<T>

local linq = {}

---@generic T, U
---@overload fun(self: enumerable<T>, consumer: fun(enum: enumerable<T>): (U)): U
---@overload fun(self: enumerable<T>, constructor: fun(): (U), consumer: fun(acc: U, item: T)): U
---@overload fun(self: enumerable<T>, constructor: fun(): (U), consumer: fun(acc: U, item: T), finalizer: fun(acc: U): (U)): U
function list:collect(...)
end

---@type list<string>
local list3 = list

local value = list3:collect(function(<?enum?>)
    return ""
end)
]]

TEST 'list<string>' [[
---@class enumerable<T>
---@class list<T>

local linq = {}

---@generic T
---@overload fun(): list<any>
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
---@overload fun(table: table): list<any>
function linq.list(...)
end

---@type list<string>
local list3 = linq.list("ABC", "abc", "aBc", "TEST", "test", "Hallo")

local <?list4?> = linq.list(list3)
]]

TEST 'list<string>' [[
---@class enumerable<T>
---@class list<T>

local linq = {}

---@generic T
---@overload fun(): list<any>
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
---@overload fun(table: table): list<any>
function linq.list(...)
end

---@generic T, U
---@overload fun(self: enumerable<T>, consumer: fun(enum: enumerable<T>): (U)): U
function list:collect(...)
end

---@type list<string>
local list3 = linq.list("ABC", "abc", "aBc", "TEST", "test", "Hallo")

local <?list5?> = list3:collect(function(enum)
    return linq.list(enum)
end)
]]

TEST 'list<string>' [[
---@class enumerable<T>
---@class list<T>

local linq = {}

---@generic T
---@overload fun(): list<any>
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
---@overload fun(table: table): list<any>
function linq.list(...)
end

---@generic T, U
---@overload fun(self: enumerable<T>, consumer: fun(enum: enumerable<T>): (U)): U
function list:collect(...)
end

---@type list<string>
local list3 = linq.list("ABC", "abc", "aBc", "TEST", "test", "Hallo")

list3:collect(function(enum)
    local <?tmp?> = linq.list(enum)
    return tmp
end)
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