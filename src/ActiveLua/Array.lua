---
--- See LICENSE file in top directory for copyright information

local Object = require "ActiveLua.Object"

local table = table

module("ActiveLua.Array")
Object:subclass(_M)

--

-- Class methods
--

--- Returns whether instances of this class are indexable. Array and related
--- classes are indexable using numeric indexes so this returns true
--
-- @return true
function isIndexed(class)
    return true
end

--
-- Instance methods
--


--- Returns the number of items in this array.
--
-- @return the number of items in this array
function count(object)
    return object._count or 0
end

--- Collects the values in the array for which the given function "func"
--- returns true. 
--
-- @param func The function to call for each value. 
-- @return An array of values which pass the func test
function collect(object, func)
    -- Make an instance of the same type of class
    local result = object:class():new()
    for i = 1, object:count() do 
        local val = func(object[i])
        if val then result:add(val) end
    end
    return result
end

--- Adds an item to the array
-- 
-- @param item item to add to the array 
-- @return the index that the item was added at
function add(object, item)
    table.insert(object, item)
    object._count = (object._count or 0) + 1
    return object._count
end

-- Removes an item at given index from the array
--
-- @param index of item to remove
-- @return the removed item
function remove(object, index)
    local val = table.remove(object, index)
    if val then
        object._count = object._count - 1
    end
    return val
end

--- Returns the classname for this class (Array)
--
-- @return string with the classname for the class
function className()
    return "Array"
end