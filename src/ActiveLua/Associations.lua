--- Associations declare relationships between classes in ActiveLua. An
--- example a Person:belongsTo(Organization) which declares that a person can
--- be looked up by organization. An association injects one or more functions
--- into the class declaring the association and may inject attributes in
--- either the declaring or the associated class. 
---        
--- Associations can have an options table that can refine the association.
--- The following options are supported:
---      
--- * attributeName -- By default the name(s) of the injected functions in the
--- class declaring the relationship are prefixed with the attributeKey of the
--- associated Class. In the example above that would mean that Person has
--- functions that are prefixed by "organization"
---
--- See LICENSE file in top directory for copyright information

local table = require "table" require "ActiveLua.table_ext"

local print = print
local tostring = tostring

module("ActiveLua.Associations")

function _isDependDestroy(options)
    if options and options.dependency then
        return options.dependency == "destroy"
    end
    return false
end

function _addDestroyHook(class, func)
    class:addHook("before-destroy", func)
end

--- Injects the functions for belongsTo into the targetClass. For example if
--- an Employee belongs to a Company (i.e. Employee:belongsTo(Company)) the
--- following methods are defined on Employee: 
---
--- <pre>
---     company() -- Equivalent to Company:first(id=emp.company_id)
---     companySet(aCompany) -- Equivalent to emp.company_id = aCompany:id()
--- </pre>
---
--- On a Set the object that owns the association is saved in the store (the
--- employee in the example above). 
---
--- In the example above, if the company that was set on an employee is
--- destroyed the employee's reference to that company is removed. This is
--- called a "nullify" association
---
--- When the association is declared destructive (i.e.
--- Employee:belongsTo:(Company, { dependency = "destroy"})) all employees
--- that belong to a given company are destroyed when the company they belong
--- to is destroyed
--
-- @param options An option table for the association
-- @param attrClass The class the attribute is defined in and where functions are injected
-- @param assocClass The class that the association is referring to
function belongsTo(attrClass, assocClass, options)
    local foreignName = assocClass:foreignKey(options)
    local attrName = assocClass:attributeKey(options)

    -- TODO: addAttribute here injects getters and setters for the foreign key
    -- itself, which is undesirable
        attrClass:addAttribute(foreignName, "integer")

    -- When a company gets destroyed
    if _isDependDestroy(options) then 
        -- Destroy: Destroy all employees in that company        
        _addDestroyHook(assocClass, function(id)
            attrClass:destroyAll{ [foreignName] = id }
        end)
    else
        -- Nullify: Nullify all employees that refer to it
        _addDestroyHook(assocClass, function(id)
            attrClass:updateAll(
                { [foreignName] = 0},
                { [foreignName] = id} )
        end)
    end
    
    attrClass:injectGetter(attrName, function(object, options)
        return assocClass:first(object:getAttribute(foreignName), options)
    end)
    
    attrClass:injectSetter(attrName, function(object, value)
        return object:setAttribute(foreignName, value:id())
    end)
end


--- Injects functions for a one-to-one assocation between two classes. For
--- example if a Person has one Address (i.e. Person:hasOne(Address)) then the
--- following functions are defined on Person:
---
--- <pre>
---     address -- Equivalent to Address:first(person_id = person:id())
---     addressSet(addr) -- Equivalent to addr.person_id = person:id()
--- </pre>
---
--- The address that refers back to the person that owns the association is
--- saved if it is not dirty. An object is dirty if it has not been created in
--- the database yet or if it has attributes that have not yet been stored.
---
--- The lifecycle of Address in the above example is related to the lifecycle
--- of the Person referring to it. In the default (nullifying association)
--- when a person is destroyed any address referring to it will have the
--- reference to that person removed
---
--- The association can have a destructive association if the given options
--- table includes a key "dependency" with the value "destroy".  In the above
--- example a destructive association would be written as
--- Person:hasOne(Address, { depdendency = "destroy" }). Given the direction
--- of the association this means that if a person is destroyed all addresses
--- referring to that person are also destroyed
--
-- @param options An options table for the declared association
-- @param attrClass The class the attribute is defined in
-- @param assocClass The class referred to in the association
function hasOne(attrClass, assocClass, options)
    local foreignName = attrClass:foreignKey(options) 
    local attrName = assocClass:attributeKey(options)
    
    assocClass:addAttribute(foreignName, "integer")
    
    local isDestroy = _isDependDestroy(options)
    
    -- When a person gets destroyed
    if isDestroy then
        -- Destroy: destroy all addresses referring to it
        _addDestroyHook(attrClass, function(id)
            assocClass:destroyAll{ [foreignName] = id }
        end) 
    else
        -- Nullify: nullify all addresses referring to it
        _addDestroyHook(attrClass, function(id)
            assocClass:updateAll( 
                { [foreignName] = 0 }, 
                { [foreignName] = id })
        end)
    end
    
    attrClass:injectGetter(attrName, function(object, options)
        return assocClass:first({ [foreignName] = object:id() }, options)
    end)
    
    attrClass:injectSetter(attrName, function(object, value)
        -- The current referenced address
        local oldValue = object:getAttribute(attrName)
        -- Change value
        value:setAttribute(foreignName, object:id())
        -- Take care to check for oldId not being nil since otherwise all records in
        -- the store are destroyed
        if oldValue and value:id() ~= oldValue:id() then
            if isDestroy then 
                -- Destroy the previous address if the association is destructive 
                oldValue:destroy()
            else
                -- Nullify the previous address
                oldValue:setAttribute(foreignName, 0)
            end
        end
        return object
    end)
end

--- Injects the function for a one to one relationship into a class. For
--- example, if a Sport holds one image (i.e. Sport:holdsOne(Image)) the
--- following functions are defined for Sport:
---
--- <pre>
---     image() -- Equivalent to Image:first{id = sport:image_id()} 
---     imageSet(image) -- Equivalent to sport:image_id = image:id()
--- </pre>
---
--- Note that on a Set call the object is saved in the store.
---
--- When a Sport gets destroyed all images referring to that sport will get
--- destroyed or nullified (based on the dependency attribute in the options
--- table). In essence holdsOne has the get/set behavior of belongsTo but the
--- destroy behavior of hasOne
---
-- @param options An options table for the declared association
-- @param attrClass The class the attribute is defined in
-- @param assocClass The class referred to in the association
function holdsOne(attrClass, assocClass, options)
    local foreignName = assocClass:foreignKey(options)
    local attrName = assocClass:attributeKey(options)
    
    attrClass:addAttribute(foreignName, "integer")
    
    local isDestroy = _isDependDestroy(options)
    
    -- When a sport gets destroyed
    if isDestroy then
        -- destroy the image that it refers to
        _addDestroyHook(attrClass, function(objId)
            local row = attrClass:rawFirst(objId, { select = foreignName })
            if row[foreignName] then
                assocClass:destroyAll(row[foreignName])
            end
        end)
    end
       
    -- When an image gets destroyed nullify the sports that refer to it
    _addDestroyHook(assocClass, function(id)
        attrClass:updateAll(
            { [foreignName] = 0 }, 
            { [foreignName] = id } )
    end)
    
    attrClass:injectGetter(attrName, function(object, options)
        local id = object:getAttribute(foreignName)
        if id == nil or id == 0 then
            return nil
        else
            return assocClass:first(id, options)
        end
    end)
    
    attrClass:injectSetter(attrName, function(object, value)
        local oldId = object:getAttribute(foreignName)
        object:setAttribute(foreignName, value:id())
        if isDestroy and oldId and (oldId ~= value:id()) then
            -- Destroy the old image if the association is destructive and ids differ
            assocClass:destroyAll(oldId)
        end
        return object
    end)
end


--- Injects the functions for a one to many relationship into a class. For
--- example if a Sport has many teams (i.e. Sport:hasMany(Team)) the
--- following functions are defined on Sport:
---   
--- <pre>
---     team(sport) -- Equivalent to Team:all(sport_id = sport:id()). 
---                     The returned collection has normal Collection functions
---     teamAdd(sport) -- Equivalent to sport:id() = team:id()
--- </pre>
--
-- @param options An options table for the declared association
-- @param attrClass The class the attribute is defined in
-- @param assocClass The class referred to in the association
function hasMany(attrClass, assocClass, options)
    local foreignName = attrClass:foreignKey(options)
    local attrName = assocClass:attributeKey(options)

    assocClass:addAttribute(foreignName, "integer")
    
    -- When a sport gets destroyed
    if _isDependDestroy(options) then
        -- Destroy: destroy all teams referring to it
        _addDestroyHook(attrClass, function(id)
            assocClass:destroyAll{ [foreignName] = id }
        end)
    else
        -- Nullify: nullify all teams referring to it
        _addDestroyHook(attrClass, function(id)
            assocClass:updateAll(
                { [foreignName] = 0 }, 
                { [foreignName] = id })
        end)
    end
    
    attrClass:injectGetter(attrName, function(object, options)
        return assocClass:all({ [foreignName] = object:id() }, options)
    end)
    
    attrClass[attrName.."Add"] = function(object, value)
        value:setAttribute(foreignName, object:id())
        return object
    end
end

--- The hasAndBelongsToMany association creates a join table that defines a
--- many to many relationship between two classes. For example if a Developer
--- has many Projects (and vice-versa) an intermediate table is created that
--- reflects each instance of the relationship (developer<->project). The
--- declaration would be: Developer:hasAndBelongsToMany(Project).
---
--- Note that this association does not take the "dependency" attribute into
--- account at this point
---
--- The join table is named as the concatenation of the declaring and the
--- associated class in lexicographic order. So, in the example above the
--- joined class is defined as Developer:hasAndBelongsToMany(Project, {
--- attributeName = "projects" }) declares the following methods on Developer:
---
--- <pre>
---     projects -- Gets the list of projects for the developer
---     projectsAdd -- Adds a project for this developer. The project must have been created
--- </pre>
function hasAndBelongsToMany(baseClass, attrClass, assocClass, options)
    local attrName = attrClass:attributeKey(options)

    local attrForeign = attrClass:foreignKey()
    local assocForeign = assocClass:foreignKey()
    
    local joinClassName = table.concat(table.rsort{
        attrClass:className(), 
        assocClass:className()
    })
    local joinClass = baseClass:extend(joinClassName, {
        [attrForeign] = "integer",
        [assocForeign] = "integer"
    })
    local joinOption = {
        tableName = joinClass:tableName(),
        on = { id = assocForeign } 
    }
    
    attrClass:addHook("after-selfdestruct", function()
        joinClass:selfDestruct()
    end)

    -- When a developer is destroyed
    _addDestroyHook(attrClass, function(id)
        -- destroy the join table entries for the developer
        joinClass:destroyAll{ [attrForeign] = id }
    end)
    
    attrClass:injectGetter(attrName, function(object, options)
        options = options or {}
        options.join = joinOption
        return assocClass:all({
            [attrForeign] = object:id()
        }, options)
    end)
    
    attrClass[attrName.."Add"] = function(object, value)
        local descr = {
            [attrForeign] = object:id(), 
            [assocForeign] = value:id()
        }
        -- Only create if the association does not exist
        if joinClass:count(descr) == 0 then
            joinClass:create(descr)
        end
        return object
    end
end

