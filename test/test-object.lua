---
--- See LICENSE file in top directory for copyright information

Object      = require "ActiveLua.Object"
Class       = require "ActiveLua.Class"

require "lunit"

lunit.setprivfenv()
lunit.import "assertions"
lunit.import "checks"

local cls = lunit.TestCase("Class/Object behavior")

function cls:test_indexed()
    assert_false(Object:isIndexed())
end

function cls:test_super()
    assert_true(Object:super() == nil)
end

function cls:test_subclass()
    Person = Object:subclass { name = "Fred";
        employed = function() return false end
    }
    Employee = Person:subclass {
        employed = function() return true end
    }
    assert_true(Person:super() == Object)
    assert_true(Employee:super() == Person)
    
    -- Ensure class methods in place
    assert_true(Person:class() == Class)
    assert_true(Employee:class() == Class)
    
    -- Check inheritance of class attributes
    assert_equal(Person.name, "Fred")
    assert_equal(Employee.name, "Fred")
    
    -- Check change of super class attributes
    Person.name = "John"
    assert_equal(Person.name, "John")
    assert_equal(Employee.name, "John")
    
    -- Check override of class attributes
    Employee.name = "Wilma"
    assert_equal(Person.name, "John")
    assert_equal(Employee.name, "Wilma")
    
    -- Check method overrides
    assert_false(Person:employed())
    assert_true(Employee:employed())
    assert_false(Employee:super():employed())
end

function cls:test_subclassOf()
    Person = Object:subclass()
    assert_true(Person:subclassOf(Object))
    assert_true(Object:subclassOf(nil))
end

function cls:test_instanceOf()
    o = Object:new()
    assert_true(o:instanceOf(Object))

    Person = Object:subclass()
    p = Person:new()
    assert_true(p:instanceOf(Object))
    assert_true(p:instanceOf(Person))
end

function cls:test_basicNew()
    Person = Object:subclass { name = "John" }
    p1 = Person:basicNew { name = "Fred"}

    assert_equal("Fred", p1.name)
    assert_true(p1:class() == Person)
    assert_true(p1:super() == Object)
    assert_equal("John", p1:class().name)    
end






