local Base        = require "ActiveLua.Base"

require "lunit"

lunit.setprivfenv()
lunit.import "assertions"
lunit.import "checks"


---
--- BelongsTo
---

local belongsTo = lunit.TestCase("BelongsTo Association")

function belongsTo:setup()
    self.Person = Base:extend("Person", {
        name = "string"
    })
    self.Address = Base:extend("Address", {
        city = "string"
    })
    self.Address:belongsTo(self.Person, {dependency = "destroy"})
    self.Address:belongsTo(self.Person, {attributeName = "manager"})
end

function belongsTo:teardown()
    self.Person:selfDestruct()
    self.Address:selfDestruct()
end

function belongsTo:testAttributes()
    assert_function(self.Address.person)
    assert_function(self.Address.personSet)
    assert_true(self.Address:hasAttribute(self.Person:foreignKey()))
    
    assert_function(self.Address.manager)
    assert_function(self.Address.managerSet)
    assert_true(self.Address:hasAttribute(self.Person:foreignKey{attributeName = "manager"}))
end


function belongsTo:testGetSet()
    self.Address:deleteAll()
    self.Person:deleteAll()

    local addr = assert_not_nil(self.Address:create { city = "Gotham" })
    local jane = assert_not_nil(self.Person:create { name = "Jane" })
    local joe = assert_not_nil(self.Person:create { name = "Joe" })
    
    -- Test setter
    assert_equal(addr, addr:personSet(jane))
    -- Test getter
    assert_equal(jane:name(), addr:person():name())
    
    -- Test setAttribute
    assert_equal(addr, addr:setAttribute("manager", joe))
    -- Test getAttribute
    assert_equal(joe:name(), addr:getAttribute("manager"):name())
end

function belongsTo:createAll()
    self.Address:deleteAll()
    self.Person:deleteAll()

    local jim = assert_not_nil(self.Person:create{ name = "Jim"})
    local jane = assert_not_nil(self.Person:create{ name = "Jane"})
    
    self.Address:createAll {
        { city = "Gotham", person = jim },
        { city = "Golem", manager = jane }
    }
    
    assert_equal(jim:name(), self.Address:first{city = "Gotham"}:person():name())
    assert_equal(jane:name(), self.Address:first{city = "Golem"}:manager():name())
end


function belongsTo:testDestroy()
    self.Address:deleteAll()
    self.Person:deleteAll()

    local addr = assert_not_nil(self.Address:create { city = "Gotham" })
    local jane = assert_not_nil(self.Person:create { name = "Jane" })
    local joe = assert_not_nil(self.Person:create { name = "Joe" })
    
    
    addr:personSet(jane) -- destructive
    addr:managerSet(joe) -- nullify
    
    joe:destroy()
    -- nullify
    assert_equal(0, self.Address:first(addr:id()):getAttribute("manager_person_id"))
    
    jane:destroy()
    -- destroy
    assert_nil(self.Address:first(addr:id()))
end



---
--- HasOne
---

local hasOne = lunit.TestCase("HasOne Association")

function hasOne:setup()
    self.Person = Base:extend("Person", {
        name = "string"
    })
    self.Address = Base:extend("Address", {
        city = "string"
    })
    self.Person:hasOne(self.Address, {dependency = "destroy"})
    self.Person:hasOne(self.Address, {attributeName = "work"})
end

function hasOne:teardown()
    self.Person:selfDestruct()
    self.Address:selfDestruct()
end


function hasOne:testAttributes()
    -- Assert first association functins and attributes
    assert_function(self.Person.address)
    assert_function(self.Person.addressSet)
    assert_true(self.Address:hasAttribute(self.Person:foreignKey()))
    -- Assert second association 
    assert_function(self.Person.work)
    assert_function(self.Person.workSet)
    assert_true(self.Address:hasAttribute("work_person_id"))
end

function hasOne:testSetGet()
    self.Address:deleteAll()
    self.Person:deleteAll()

    local gotham = assert_not_nil(self.Address:create { city = "Gotham" })
    local golem = assert_not_nil(self.Address:create { city = "Golem" })
    local salem = assert_not_nil(self.Address:create{ city = "Salem" })
    local jim = assert_not_nil(self.Person:create { name = "Jim" })

    assert_nil(jim:address())
    assert_nil(jim:work())
    
    -- Test setter
    assert_equal(jim, jim:addressSet(gotham))
    -- Test getter
    assert_equal(gotham:city(), jim:address():city())
    
    -- Test setAttribute
    jim:setAttribute("work", golem)
    -- Test getAttribute
    assert_equal(golem:city(), jim:getAttribute("work"):city())

    jim:addressSet(salem) -- destructive, destroys gotham
    assert_nil(self.Address:first(gotham:id()))

    jim:workSet(salem) -- nullify, nulls golem    
    assert_equal(0, self.Address:first(golem:id()):getAttribute("work_person_id"))
end
    
function hasOne:createAll()
    self.Address:deleteAll()
    self.Person:deleteAll()
 
    local gotham = assert_not_nil(self.Address:create { city = "Gotham" })
    local golem = assert_not_nil(self.Address:create { city = "Golem" })
    
    self.Person:createAll {
        { name = "Jim", address = gotham },
        { name = "Jane", work = golem }
    }

    assert_equal(gotham:city(), self.Person:first{name = "Jim"}:address():city())
    assert_equal(golem:city(), self.Person:first{name = "Jane"}:address():city())
end


function hasOne:testDestroy()
    self.Address:deleteAll()
    self.Person:deleteAll()
    
    local gotham = assert_not_nil(self.Address:create { city = "Gotham" })
    local golem = assert_not_nil(self.Address:create { city = "Golem" })
    local jim = assert_not_nil(self.Person:create { name = "Jim" })
    
    -- Test Destroy behavior
    jim:addressSet(gotham) -- destructive
    jim:workSet(golem) -- nullify
    
    jim:destroy()

    assert_nil(self.Address:first(gotham:id()))
    assert_nil(jim:address())

    -- address should still be there
    golem = assert_not_nil(self.Address:first(golem:id()))
    -- but not refer to the destroyed person anymore
    assert_nil(jim:work())
end


---
--- holdsOne
---

local holdsOne = lunit.TestCase("HoldsOne Association")

function holdsOne:setup()
    self.Person = Base:extend("Person", {
        name = "string"
    })
    self.Address = Base:extend("Address", {
        city = "string"
    })
    self.Person:holdsOne(self.Address, {dependency = "destroy"})
    self.Person:holdsOne(self.Address, {attributeName = "work"})
end

function holdsOne:teardown()
    self.Person:selfDestruct()
    self.Address:selfDestruct()
end

function holdsOne:testAttributes()
    -- Assert first association functins and attributes
    assert_function(self.Person.address)
    assert_function(self.Person.addressSet)
    assert_true(self.Person:hasAttribute(self.Address:foreignKey()))
    -- Assert second association 
    assert_function(self.Person.work)
    assert_function(self.Person.workSet)
    assert_true(self.Person:hasAttribute("work_address_id"))
end

function holdsOne:testSetGet()
    self.Address:deleteAll()
    self.Person:deleteAll()

    local gotham = assert_not_nil(self.Address:create { city = "Gotham" })
    local golem = assert_not_nil(self.Address:create { city = "Golem" })
    local salem = assert_not_nil(self.Address:create{ city = "Salem" })
    local jim = assert_not_nil(self.Person:create { name = "Jim" })

    assert_nil(jim:address())
    assert_nil(jim:work())

    -- Test setter
    assert_equal(jim, jim:addressSet(gotham))
    -- Test getter
    assert_equal(gotham:city(), jim:address():city())

    -- Test setAttribute
    jim:setAttribute("work", golem)
    -- Test getAttribute
    assert_equal(golem:city(), jim:getAttribute("work"):city())

    jim:addressSet(salem) -- destructive, destroys gotham
    assert_nil(self.Address:first(gotham:id()))

    jim:workSet(salem) -- nullify, does nothing    
    assert_not_nil(self.Address:first(golem:id()))
end

function holdsOne:createAll()
    self.Address:deleteAll()
    self.Person:deleteAll()

    local jim = assert_not_nil(self.Person:create { name = "Jim" }) 
    local gotham = assert_not_nil(self.Address:create { city = "Gotham" })
    local golem = assert_not_nil(self.Address:create { city = "Golem" })
    
    self.Person:createAll {
        { name = "Jim", address = gotham },
        { name = "Jane", work = golem }
    }

    assert_equal(gotham:city(), self.Person:first{name = "Jim"}:address():city())
    assert_equal(golem:city(), self.Person:first{name = "Jane"}:address():city())
end


function holdsOne:testDestroy()
    self.Address:deleteAll()
    self.Person:deleteAll()

    local gotham = assert_not_nil(self.Address:create { city = "Gotham" })
    local golem = assert_not_nil(self.Address:create { city = "Golem" })
    local jim = assert_not_nil(self.Person:create { name = "Jim" })
    
    -- Test Destroy behavior
    jim:addressSet(gotham) -- destructive
    jim:workSet(golem) -- nullify
    
    jim:destroy()

    -- destructive
    assert_nil(self.Address:first(gotham:id()))
    assert_nil(jim:address())

    -- nullify
    assert_not_nil(self.Address:first(golem:id()))
end


---
--- HasMany
---

local hasMany = lunit.TestCase("HasMany Association")

function hasMany:setup()
    self.Organization = Base:extend("Organization", {
        name = "string"
    })
    self.Person = Base:extend("Address", {
        name = "string"
    })
    self.Organization:hasMany(self.Person, {attributeName = "people"})
    self.Organization:hasMany(self.Person, {
        attributeName = "volunteers", 
        dependency = "destroy"
    })
end

function hasMany:teardown()
    self.Organization:selfDestruct()
    self.Person:selfDestruct()
end


function hasMany:testAttributes()
    -- Assert injected function(s) and attributes
    assert_function(self.Organization.people)
    assert_true(self.Person:hasAttribute(self.Organization:foreignKey{ attributeName = "people"}))
    
    assert_function(self.Organization.volunteers)
    assert_true(self.Person:hasAttribute(self.Organization:foreignKey{ attributeName = "volunteers"}))
end

function hasMany:testAdd()
    self.Organization:deleteAll()
    self.Person:deleteAll()

    local org = assert_not_nil( self.Organization:create { name = "Acme Corporation"} )
    local joe = assert_not_nil( self.Person:create { name = "Joe" } )
    local jim = assert_not_nil( self.Person:create { name = "Jim"} )
    local jane = assert_not_nil( self.Person:create { name = "Jane"} )
    
    assert_equal(org, org:peopleAdd(joe))
    assert_equal(org, org:peopleAdd(jim))
    
    assert_equal(org, org:volunteersAdd(jane))

    assert_equal(1, org:volunteers():count())
    
    local people = assert_not_nil(org:people())
    assert_equal(2, people:count())
    for _,person in ipairs(people) do
        assert_equal(org:id(), person:getAttribute("people_organization_id"))
    end
    
end


function hasMany:testDestroy()    
    self.Organization:deleteAll()
    self.Person:deleteAll()

    local jim = assert_not_nil(self.Person:create { name = "Jim"})
    local john = assert_not_nil(self.Person:create { name = "John"})
    local org = assert_not_nil(self.Organization:create { name = "Volunteers"})
    
    org:volunteersAdd(jim) -- destroy
    org:peopleAdd(john) -- nullify
    
    org:destroy()
    
    assert_equal(0, org:people():count())
    
    assert_nil(self.Person:first(jim:id())) -- destroy
    assert_not_nil(self.Person:first(john:id())) -- nullify
end


---
--- HasAndBelongsToMany
---

local habtm = lunit.TestCase("HasAndBelongsToMany Association")

function habtm:setup()
    self.Developer = Base:extend("Developer", {
        name = "string"
    })
    self.Project = Base:extend("Project", {
        name = "string"
    })
    self.Developer:hasAndBelongsToMany(self.Project, {attributeName = "projects"})
    self.Project:hasAndBelongsToMany(self.Developer, {attributeName = "developers"})
end

function habtm:teardown()
    self.Developer:selfDestruct()
    self.Project:selfDestruct()
end

function habtm:testAttributes()
    -- Assert injected function(s) and attributes
    assert_function(self.Developer.projects)
    assert_function(self.Developer.projectsAdd)
    
    assert_function(self.Project.developers)
    assert_function(self.Project.developersAdd)
end

function habtm:testAdd()
    self.Developer:deleteAll()
    self.Project:deleteAll()
    
    local al = assert_not_nil(self.Project:create{ name = "ActiveLua" })
    local lsql = assert_not_nil(self.Project:create { name = "LuaSQL" })
    local joe = assert_not_nil(self.Developer:create { name = "Joe" })
    local jim = assert_not_nil(self.Developer:create { name = "Jim"})
    
    assert_equal(0, joe:projects():count())
    assert_equal(0, jim:projects():count())
    
    assert_equal(joe, joe:projectsAdd(al))
    assert_equal(joe, joe:projectsAdd(lsql))
    
    assert_equal(jim, jim:projectsAdd(lsql))
    
    assert_equal(2, joe:projects():count())
    assert_equal(1, jim:projects():count())
    
    assert_equal("LuaSQL", jim:projects()[1]:name())
end

function habtm:testDestroy()
    self.Developer:deleteAll()
    self.Project:deleteAll()

    local al = assert_not_nil(self.Project:create{ name = "ActiveLua" })
    local lsql = assert_not_nil(self.Project:create { name = "LuaSQL" })
    local joe = assert_not_nil(self.Developer:create { name = "Joe" })
    local jim = assert_not_nil(self.Developer:create { name = "Jim"})
    
    joe:projectsAdd(al)
    joe:projectsAdd(lsql)
    jim:projectsAdd(lsql)
    
    al:destroy()
    
    assert_equal(0, al:developers():count())
    assert_equal(2, lsql:developers():count())
    assert_equal(1, joe:projects():count())
    assert_equal(1, jim:projects():count())
end
