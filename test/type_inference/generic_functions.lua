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


TEST '{ age: number }' [[
---@class list<T>
local list = {}

---@class fork_result<A, B>
local fork_result = {}

---@class dict<K, V>
local dict = {}

---@class enumerable<T>
local enumerable = {}

local linq = {}

---@generic T
---@overload fun(enumerable: enumerable<T>): list<T>
function linq.list(...)
end

---@generic A, B
---@param self fork_result<A, B>
---@return A, B
function fork_result:spread()
end

---@generic K, V
---@overload fun(table: { [K]: V }): dict<K, V>
function linq.dict(...)
end

---@generic K, V
---@param self dict<K, V>
---@return enumerable<K, V>
function dict:enumerate()
end

---@generic T, K, V
---@overload fun(self: enumerable<T>, predicate: fun(item: T): boolean): enumerable<T>
---@overload fun(self: enumerable<K, V>, predicate: fun(key: K, value: V): boolean): enumerable<K, V>
function enumerable:where(...)
end

---@generic TI, TO, KI, KO, VI, VO
---@overload fun(self: enumerable<TI>, selector: fun(item: TI): TO): enumerable<TO>
---@overload fun(self: enumerable<KI, VI>, selector: fun(key: KI, value: VI): TO): enumerable<TO>
---@overload fun(self: enumerable<KI, VI>, selector: fun(key: KI, value: VI): KO, VO): enumerable<KO, VO>
function enumerable:select(...)
end

---@generic TI, TO, KI, VI
---@overload fun(self: enumerable<TI>, consumer: fun(enum: enumerable<TI>): TO): TO
---@overload fun(self: enumerable<KI, VI>, consumer: fun(enum: enumerable<KI, VI>): TO): TO
function enumerable:collect(...)
end

---@generic T, K, V, R1, R2
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2)): fork_result<R1, R2>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2)): fork_result<R1, R2>
function enumerable:fork(...)
end

---@return table<string, { age: number }>
local function make_table()
    return {
        ['max'] = { age = 30 },
        ['tom'] = { age = 25 },
        ['isa'] = { age = 28 },
        ['lisa'] = { age = 22 },
    }
end

local t = make_table()

local dict = linq.dict(t)
local names, ages = dict
    :enumerate()
    :where(function (k, v)
        return k == 'max' or k == 'tom'
    end)
    :fork(function (e)
        local tmp = e:select(function (k, <?v?>)
            return k
        end)
        return tmp:collect(linq.list)
    end, function (e)
        local tmp = e:select(function (k, v)
            return v.age
        end)
        return tmp:collect(linq.list)
    end):spread()
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

TEST 'enumerable<number>' [[
---@class list<T>
local list = {}

---@class fork_result<A, B>
local fork_result = {}

---@class dict<K, V>
local dict = {}

---@class enumerable<T>
local enumerable = {}

local linq = {}

---@generic T
---@overload fun(enumerable: enumerable<T>): list<T>
function linq.list(...)
end

---@generic A, B
---@param self fork_result<A, B>
---@return A, B
function fork_result:spread()
end

---@generic K, V
---@overload fun(table: { [K]: V }): dict<K, V>
function linq.dict(...)
end

---@generic K, V
---@param self dict<K, V>
---@return enumerable<K, V>
function dict:enumerate()
end

---@generic T, K, V
---@overload fun(self: enumerable<T>, predicate: fun(item: T): boolean): enumerable<T>
---@overload fun(self: enumerable<K, V>, predicate: fun(key: K, value: V): boolean): enumerable<K, V>
function enumerable:where(...)
end

---@generic TI, TO, KI, KO, VI, VO
---@overload fun(self: enumerable<TI>, selector: fun(item: TI): TO): enumerable<TO>
---@overload fun(self: enumerable<KI, VI>, selector: fun(key: KI, value: VI): TO): enumerable<TO>
---@overload fun(self: enumerable<KI, VI>, selector: fun(key: KI, value: VI): KO, VO): enumerable<KO, VO>
function enumerable:select(...)
end

---@generic TI, TO, KI, VI
---@overload fun(self: enumerable<TI>, consumer: fun(enum: enumerable<TI>): TO): TO
---@overload fun(self: enumerable<KI, VI>, consumer: fun(enum: enumerable<KI, VI>): TO): TO
function enumerable:collect(...)
end

---@generic T, K, V, R1, R2
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2)): fork_result<R1, R2>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2)): fork_result<R1, R2>
function enumerable:fork(...)
end

---@return table<string, { age: number }>
local function make_table()
    return {
        ['max'] = { age = 30 },
        ['tom'] = { age = 25 },
        ['isa'] = { age = 28 },
        ['lisa'] = { age = 22 },
    }
end

local t = make_table()

local dict = linq.dict(t)
local names, ages = dict
    :enumerate()
    :where(function (k, v)
        return k == 'max' or k == 'tom'
    end)
    :fork(function (e)
        local tmp = e:select(function (k, v)
            return k
        end)
        return tmp:collect(linq.list)
    end, function (e)
        local <?tmp?> = e:select(function (k, v)
            return v.age
        end)
        return tmp:collect(linq.list)
    end):spread()
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
---@param source enumerable<T>
---@return list<T>
local function to_list(source)
end

---@generic K, V
---@param source enumerable<K, V>
---@return list<K>
local function keys(source)
end

---@generic K, V, R
---@param source enumerable<K, V>
---@param selector fun(value: V): R
---@return list<R>
local function map_values(source, selector)
end

---@generic T
---@param self enumerable<T>
---@return list<T>
function enumerable:to_list()
end

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

TEST 'dict<string, integer>' [[
---@class dict<K, V>
---@class enumerable<K, V>
---@class iter<K, V>

local linq = {}

---@generic K, V
---@overload fun(): dict<any, any>
---@overload fun(table: { [K]: V }): dict<K, V>
---@overload fun(dict: dict<K, V>): dict<K, V>
---@overload fun(enumerable: enumerable<K, V>): dict<K, V>
---@overload fun(iter: iter<K, V>): dict<K, V>
---@overload fun(table: table): dict<any, any>
function linq.dict(...)
end

local tab = {
    ["a"] = 1,
    ["b"] = 2,
}

local <?result?> = linq.dict(tab)
]]

TEST 'dict<any, any>' [[
---@class dict<K, V>
---@class enumerable<K, V>
---@class iter<K, V>

local linq = {}

---@generic K, V
---@overload fun(): dict<any, any>
---@overload fun(table: { [K]: V }): dict<K, V>
---@overload fun(dict: dict<K, V>): dict<K, V>
---@overload fun(enumerable: enumerable<K, V>): dict<K, V>
---@overload fun(iter: iter<K, V>): dict<K, V>
---@overload fun(table: table): dict<any, any>
function linq.dict(...)
end

---@return table
local function make_table()
    return {
        ["a"] = 1,
        ["b"] = 2,
        [1] = 3,
    }
end

local t = make_table()

local <?result?> = linq.dict(t)
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

TEST 'string' [[
---@class list<T>
local list = {}

---@class fork_result<A, B>
local fork_result = {}

---@class dict<K, V>
local dict = {}

---@class enumerable<T>
local enumerable = {}

local linq = {}

---@generic T
---@param self list<T>
---@return T
function list:first()
end

---@generic T
---@param self list<T>
---@return fun(): T
function list:iter()
end

---@generic A, B
---@param self fork_result<A, B>
---@return A, B
function fork_result:spread()
end

---@generic K, V
---@overload fun(table: { [K]: V }): dict<K, V>
function linq.dict(...)
end

---@generic T
---@overload fun(enumerable: enumerable<T>): list<T>
function linq.list(...)
end

---@generic K, V
---@param self dict<K, V>
---@return enumerable<K, V>
function dict:enumerate()
end

---@generic T, K, V
---@overload fun(self: enumerable<T>, predicate: fun(item: T): boolean): enumerable<T>
---@overload fun(self: enumerable<K, V>, predicate: fun(key: K, value: V): boolean): enumerable<K, V>
function enumerable:where(...)
end

---@generic TI, TO, KI, KO, VI, VO
---@overload fun(self: enumerable<TI>, selector: fun(item: TI): TO): enumerable<TO>
---@overload fun(self: enumerable<KI, VI>, selector: fun(key: KI, value: VI): TO): enumerable<TO>
---@overload fun(self: enumerable<KI, VI>, selector: fun(key: KI, value: VI): KO, VO): enumerable<KO, VO>
function enumerable:select(...)
end

---@generic TI, TO, KI, VI
---@overload fun(self: enumerable<TI>, consumer: fun(enum: enumerable<TI>): TO): TO
---@overload fun(self: enumerable<KI, VI>, consumer: fun(enum: enumerable<KI, VI>): TO): TO
function enumerable:collect(...)
end

---@generic T, K, V, R1, R2
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2)): fork_result<R1, R2>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2)): fork_result<R1, R2>
function enumerable:fork(...)
end

---@return table<string, { age: number }>
local function make_table()
    return {
        ['max'] = { age = 30 },
        ['tom'] = { age = 25 },
        ['isa'] = { age = 28 },
        ['lisa'] = { age = 22 },
    }
end

local t = make_table()

local names = linq.dict(t)
    :enumerate()
    :where(function (k, v)
        return k == 'max' or k == 'tom'
    end)
    :fork(function (e)
        return to_list(e:select(function (<?k?>, v)
            return k
        end))
    end, function (e)
        return to_list(e:select(function (k, v)
            return v.age
        end))
    end):spread()
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