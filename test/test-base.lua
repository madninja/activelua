---
--- See LICENSE file in top directory for copyright information

local Base        = require "ActiveLua.Base"

require "lunit"

lunit.setprivfenv()
lunit.import "assertions"
lunit.import "checks"

local base = lunit.TestCase("Base Class Methods")

function base:setup()
    self.Organization = Base:extend("Organization", {
        name = "string"
    })
end

function base:teardown()
    self.Organization:selfDestruct()
end

function base:test_className()
    assert_equal("Organization", self.Organization:className())
    assert_error("Expected error on undefined className", 
        function()
            Tmp = Base:extend()
        end)
end

function base:test_foreignKey()
    assert_equal("organization_id", self.Organization:foreignKey())
    assert_equal("person_organization_id", 
        self.Organization:foreignKey{ attributeName = "person"})
end

function base:test_attributeKey()
    assert_equal("organization", self.Organization:attributeKey())
    assert_equal("person", 
        self.Organization:attributeKey{ attributeName = "person"})
end

function base:test_tableName()
    assert_equal("organization", self.Organization:tableName())
end

function base:test_connection()
    assert_not_nil(self.Organization:connection())
end

function base:test_defaultSource()
    assert_equal("store.db", self.Organization:defaultSource())
end

function base:test_defaultConnection()
    assert_not_nil(self.Organization:defaultConnection())
end

function base:test_hasAttribute()
    assert_true(self.Organization:hasAttribute("name"))
    assert_false(self.Organization:hasAttribute("unknownAttribute"))
end


function base:test_addAttribute()
    self.Organization:addAttribute("status", "string")
    -- Attribute created?
    assert_true(self.Organization:hasAttribute("status"))
    -- Add attribute is test through the associations class definitions in setup.
    -- Try a bad attribute here
    assert_error("Expected failure on bad attribute type",
        function()
            self.Organization:addAttribut("bad", "unknownType")
        end
    )
    -- Try adding an attribute that already exists but with a different type
    assert_error("Expected existing typed attribute error",
        function()
            self.Organization:addAttribute("name", "integer")
        end
    )
end

function base:test_attributeTypes()
    assert_not_nil(self.Organization:attributeTypes()["name"])
    assert_nil(self.Organization:attributeTypes()["unknownAttribute"])
end


function base:test_hooks()
    local value = false
    local func = function(val)
        value = val
    end
    self.Organization:addHook("test", func)
    self.Organization:callHook("test", true)
    assert_true(value)
    -- Remove hook and ensure that it's not triggered again
    self.Organization:removeHook("test", func)
    self.Organization:callHook("test", false)
    assert_true(value)
    
    value = false
    local errFunc = function(val)
        error("Hook error")
    end
    self.Organization:addHook("test", errFunc)
    self.Organization:addHook("test", func)
    assert_error("Expected hook error", function()
        self.Organization:callHook("test", true)
    end)
    assert_false(value)
end


local life = lunit.TestCase("Object lifecycle methods")

function life:setup()
    self.Person = Base:extend("Person", {
        tableName = function() 
            return "people" 
        end;
        firstName = "string";
        lastName = "string";
        age = "integer";
    })
end

function life:teardown()
    self.Person:selfDestruct()
end


function life:test_new()
    local jane= self.Person:new {
        firstName = "Jane",
        lastName = "Doddle"
    }
    assert_equal("Jane", jane:firstName())
    assert_equal("Doddle", jane:lastName())
    -- Check dirty,present and created
    assert_false(jane:isCreated())
    assert_false(jane:isPresent())
    assert_true(jane:isDirty())
end

function life:test_create()
    local jane = self.Person:create {
        firstName = "Jane",
        lastName = "Doe",
        age = 22
    }
    local joe = self.Person:create {
        firstName = "Joe",
        lastName = "Smith",
        age = 22
    }
    assert_equal(2, self.Person:count())
    assert_equal(1, jane:id())
    assert_equal("Doe", jane:lastName())
    assert_equal(2, joe:id())
    assert_equal(22, joe:age())    
    -- Check dirty, present and created
    assert_true(jane:isCreated())
    assert_true(jane:isPresent())
    assert_false(jane:isDirty())
end

function life:test_createAll()
    local prevCount = self.Person:count()
    self.Person:createAll {
        {firstName = "Sylvia"},
        {firstName = "Sonny"},
        {firstName = "Sonny"},
    }

    assert_equal(prevCount + 3, self.Person:count())
end

function life:test_deleteAll()
    assert_equal(self.Person, self.Person:deleteAll{ firstName = "Sonny" })
    assert_equal(0, self.Person:count{firstName = "Sonny"})
    -- Also tests delete by id
    local sylvia = self.Person:first{firstName = "Sylvia"}
    self.Person:deleteAll(sylvia:id())
    assert_nil(self.Person:first(sylvia:id()))
    assert_false(sylvia:isPresent())
end


function life:test_first()
    local jane = self.Person:first { firstName = "Jane" }
    assert_equal("Doe", jane:lastName())
    assert_equal(1, jane:id())
    -- Test lookup by id
    assert_equal("Doe", self.Person:first(jane:id()):lastName())
    -- Test lookup failure
    assert_nil(self.Person:first{ lastName = "unkownName" })
end

function life:test_update()
    local joe = self.Person:first{
        firstName = "Joe"
    }
    -- Using setter method
    joe:lastNameSet("DoGood")
    assert_false(joe:isDirty())
    joe = assert_not_nil(self.Person:first(joe:id()))
    assert_equal("DoGood", joe:lastName())
    
    -- Using set attribute
    joe:setAttribute("lastName", "Smith")
    assert_false(joe:isDirty())
    assert_equal("Smith", self.Person:first(joe:id()):lastName())
end

function life:test_refresh()
    local joe = self.Person:create{ firstName = "Joe" }
    local joe2 = self.Person:first(joe:id())
    
    -- Update original
    joe:lastNameSet("DoLittle")
    assert_equal(nil, joe2:lastName())
    -- Test basic
    joe2:refresh()
    assert_equal("DoLittle", joe2:lastName())
    
    -- test destruction and refresh
    joe:destroy()
    assert_nil(joe2:refresh())
    
    -- test uncreated object refresh
    joe = self.Person:new{ firstName = "Joe" }
    assert_nil(joe:refresh())
end


function life:test_freeze()
    local jim = self.Person:create {
        firstName = "Jim"
    }
    jim:freeze()
    assert_true(jim:isFrozen())
    assert_error("Expected frozen object", function()
        jim:lastNameSet("DoGood")
    end)
end

function life:test_destroy()
    local jim = self.Person:create { firstName = "Jim" }
    assert_equal(jim, jim:destroy())
    assert_nil(self.Person:first(jim:id()))
    assert_true(jim:isFrozen())
    assert_false(jim:isPresent())
    -- A frozen object is ignored when destroyed again
    assert_equal(jim, jim:destroy())
    
    -- Test destroy hooks
    local jim = self.Person:create { firstName = "Jim" }
    local func = function(id)
        assert_equal(jim:id(), id)
    end
    self.Person:addHook("before-destroy", func)
    self.Person:addHook("after-destroy", func)
    jim:destroy()
    self.Person:removeHook("before-destroy", func)
    self.Person:removeHook("after-destroy", func)
end

function life:test_destroyAll()
    self.Person:createAll{
        { firstName = "Jim"},
        { firstName = "Jim"},
    }
    assert_equal(self.Person, self.Person:destroyAll{ firstName = "Jim"})
    assert_equal(0, self.Person:count{ firstName = "Jim"})
end

function life:test_transactionDo()
    local prevCount = self.Person:count{ firstName = "Jim"}
    self.Person:transactionDo(function()
        self.Person:create{ firstName = "Jim"}
        error("Transaction Error")
    end)
    assert_equal(prevCount, self.Person:count{ firstName = "Jim"})
end

function life:test_all()
    local valid = {
        { firstName = "Jane"},
        { firstName = "Joe"},
    }
    -- Check with criteria and options
    local stored = self.Person:all({ age = 22 }, {order = "lastName"})
    assert_equal(2, stored:count())
    for i = 1, 2 do  
        assert_equal(valid[i].firstName, stored[i]:firstName())
        assert_equal(22, stored[i]:age())
        i = i + 1
    end
    -- Check empty request
    local all = self.Person:all()
    assert_equal(self.Person:count(), all:count())
end

function life:test_ids()
    -- Based on previoud test_all test, 
    assert_equal(2, #self.Person:ids{ age = 22 })
    assert_equal(0, #self.Person:ids{firstName = "Unknown"})
end