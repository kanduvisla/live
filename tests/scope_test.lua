-- Test to see how scoping works

-- Object A
A = {}
A.__index = A

function A:new()
    local instance = setmetatable({}, A)

    instance.name = "Mr. A"

    return instance
end

function A:sayName()
    print("My name is " .. self.name)
end

function A:greet(name)
    print("Hello " .. name)
end

function A:greetFn(name)
    self:greet(name)
end

-- Object B
B = {}
B.__index = B

function B:new(fn, greetFn)
    local instance = setmetatable({}, B)

    instance.fn = fn
    instance.greetFn = greetFn
    instance.name = "Mr. B"

    return instance
end

function B:callFn()
    self:fn()
end

function B:callGreet(name)
    self:greetFn(name)
end

-- Helper function to bind self
function bind(fn, obj)
    return function(...)
        return fn(obj, ...)
    end
end

local instanceA = A:new()
local instanceB = B:new(
    instanceA.sayName,
    instanceA.greetFn
)
local boundInstanceB = B:new(
    function() return instanceA:sayName() end,
    -- Methods with arguments, always get the first argument as scope, ignore that:
    function(_, name) return instanceA:greetFn(name) end
)

instanceA:sayName()
instanceB:callFn()
boundInstanceB:callFn()
boundInstanceB:callGreet("Bob") -- Will work, because of binding
instanceB:callGreet("Bob") -- Will cause nil error, because B:greet does not exist
