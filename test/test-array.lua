---
--- See LICENSE file in top directory for copyright information

Array = require "ActiveLua.Array"

require "lunit"

lunit.setprivfenv()
lunit.import "assertions"
lunit.import "checks"


local array = lunit.TestCase("Array behavior")

function array:test_indexed()
    assert_true(Array:isIndexed())
end

function array:test_addition()
    local arr = Array:new()
    assert_equal(0, arr:count())
    -- Test adding an object
    arr:add(Object:new())
    assert_equal(Object, arr[1]:class())
    -- Test adding a table
    arr:add({ a = 22 })
    assert_equal("table", type(arr[2]))
    assert_equal(22, arr[2].a)
    -- Test adding a string
    arr:add("test")
    assert_equal("test", arr[3])
    -- Test adding a number
    arr:add(43)
    assert_equal(43, arr[4])

    assert_equal(4, arr:count())
end

function array:test_remove()
    local arr = Array:new()
    arr:add(1)
    arr:add(2)
    arr:add(3)
    -- Remove at index 2
    assert_equal(2, arr:remove(2))
    -- Ensure 3 is now at location 2
    assert_equal(3, arr[2])
    -- Remove out of bound index
    assert_equal(2, arr:count())
    assert_nil(arr:remove(100))
    assert_equal(2, arr:count())
end

function array:test_collect()
    local arr = Array:new()
    -- Collect over empty array should be an empty array
    assert_equal(0, arr:collect(function(item) return item end):count())
    
    for i = 1, 4 do arr:add(i) end
    local even = arr:collect(function(item)
        if (item % 2) == 0 then return item end
        return nil
    end)
    assert_equal(2, even:count())
    assert_equal(2, even[1])
    assert_equal(4, even[2])
end