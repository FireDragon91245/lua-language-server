TEST [[
---@class Foo
---@field field1 integer
local mt = {}
function mt:Constructor()
    self.field2 = 1
end
function mt:method1() return 1 end
function mt.method2() return 2 end

---@class Bar: Foo
---@field field4 integer
local mt2 = {}

---@type Foo
local v
print(v.field1 + 1)
print(v.field2 + 1)
print(v.<!field3!> + 1)
print(v:method1())
print(v.method2())
print(v:<!method3!>())

---@type Bar
local v2
print(v2.field1 + 1)
print(v2.field2 + 1)
print(v2.<!field3!> + 1)
print(v2.field4 + 1)
print(v2:method1())
print(v2.method2())
print(v2:<!method3!>())

local v3 = {}
print(v3.abc)

---@class Bar2
local mt3
function mt3:method() return 1 end
print(mt3:method())
]]

-- checkUndefinedField 通过type找到class
TEST [[
---@class Foo
local Foo
function Foo:method1() end

---@type Foo
local v
v:method1()
v:<!method2!>() -- doc.class.name
]]

-- checkUndefinedField 通过type找到class，涉及到 class 继承版
TEST [[
---@class Foo
local Foo
function Foo:method1() end
---@class Bar: Foo
local Bar
function Bar:method3() end

---@type Bar
local v
v:method1()
v:<!method2!>() -- doc.class.name
v:method3()
]]

-- checkUndefinedField 类名和类变量同名，类变量被直接使用
TEST [[
---@class Foo
local Foo
function Foo:method1() end
Foo:<!method2!>() -- doc.class
Foo:<!method2!>() -- doc.class
]]

-- checkUndefinedField 没有@class的不检测
TEST [[
local Foo
function Foo:method1()
    return Foo:method2() -- table
end
]]

-- checkUndefinedField 类名和类变量不同名，类变量被直接使用、使用self
TEST [[
---@class Foo
local mt
function mt:method1()
    mt.<!method2!>() -- doc.class
    self:method1()
    return self.<!method2!>() -- doc.class.name
end
]]

-- checkUndefinedField 当会推导成多个class类型时
TEST [[
---@class Foo
local mt
function mt:method1() end

---@class Bar
local mt2
function mt2:method2() end

---@type Foo
local v
---@type Bar
local v2
v2 = v
v2:<!method1!>()
v2:<!method2!>()
]]

TEST [[
---@type table
T1 = {}
print(T1.f1)
---@type tablelib
T2 = {}
print(T2.<!f2!>)
]]

TEST [[
---@type string|table
local n

print(n.x)
]]

TEST [[
---@class string

---@class list<T>
local list

---@generic T
---@param self list<T>
function list:iter()
end

---@type list<string>|string
local value

value:<!iter!>()
]]

TEST [[
---@class Foo
---@field shared integer
---@field onlyFoo integer
local Foo

---@class Bar
---@field shared integer
local Bar

---@type Foo|Bar
local value

print(value.shared)
print(value.<!onlyFoo!>)
]]

TEST [[
---@class string

---@class list<T>
local list

---@generic T
---@param self list<T>
function list:spread()
end

---@type list<string>|list<number>|string
local test = ""

local spread1, spread2 = test:<!spread!>()
]]
(function (diags)
    local diag = diags[1]
    assert(diag.message == [[字段 `spread` 在类型 `string` 中未定义。]])
end)

TEST [[
---@class Foo
---@field shared integer
local Foo
function Foo:common() end

---@class Bar
---@field shared integer
local Bar
function Bar:common() end

---@type Foo|Bar
local value

print(value.shared)
value:common()
]]

TEST [[
---@type 'x'
local t

local n = t:upper()
]]

TEST [[
---@alias A 'x'

---@type A
local t

local n = t:upper()
]]

TEST [[
---@enum X
X = {
    A = 1,
    B = 2
}

print(X.<!C!>)
]]
