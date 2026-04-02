TEST [[
local function test()
end

local result = <!test()!>
]]

TEST [[
local function test()
    return nil
end

local result = <!test()!>
]]

TEST [[
---@class enumerable<T>
local enumerable = {}

local linq = {}

---@generic T
---@overload fun(...: T): enumerable<T>
function linq.enumerable(...)
end

---@generic T, R1, R2
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (nil), fork2: fun(enumerable: enumerable<T>): (nil)): nil
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1?), fork2: fun(enumerable: enumerable<T>): (R2?)): enumerable<R1?|R2?>
function enumerable:fork(...)
end

---@type enumerable<integer>
local l = linq.enumerable(1, 2, 3)

local fork = <!l:fork(function (e)
    e:any()
end, function (e)
end)!>
]]

TEST [[
local function test()
    return 1
end

local result = test()
]]