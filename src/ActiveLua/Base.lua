---
--- See LICENSE file in top directory for copyright information

local Object        = require "ActiveLua.Object"
local Associations  = require "ActiveLua.Associations"
local Array         = require "ActiveLua.Array"

local pairs     = pairs
local ipairs    = ipairs
local type      = type
local string    = require "string"
local table     = require "table" require "ActiveLua.table_ext"
local setmetatable = setmetatable
local error     = error
local pcall     = pcall
local require   = require

local print     = print
local tostring  = tostring

module ("ActiveLua.Base")
Object:subclass(_M)


--
-- Class methods
--

--- Extends a base class, creating a new named subclass with a given set of
--- attributes. The attributes are defined using attrName = "attrType" table
--- syntax where attrName is the name of the attribute and attrType represents
--- the ActiveLue type for the attribute. 
---
--- There are a number of special attributes that are required for an
--- extension to work. These are:
---     
--- The base class will use the store connection returned by the
--- defaultConnection method which will receieve the store name to use from
--- the defaultSource method. See those two methods for additional
--- information. 
---
--- Once connected, the base class will ensure that the store has the
--- appropriate columns for the attributes and inject getter and setter
--- functions for the declared attribute. 
---
--- Note that attributeNames end up as methods in the class overriding
--- existing methods. Make sure that your attributes don't collide with the
--- other methods defined in Base.
---
--- An example class definition is:
---
--- Person = Base:extend ("Person", { 
---     firstName = "string",
---     lastName = "string"
--- })
---
--- This will create a table called "people" (not "person" which would be the
--- default behavior) in an SQLite3 store called "store.db" with columns
--- called "firstName" and "lastName" and generate methods on the new class
--- Person called Person.firstName() and Person.firstNameSet(newVal) as well
--- as Person.lastName() and Person.lastNameSet(newVal) to get and set the
--- values on instances of the object as well save them to the backing store
--- (on set).
---
--- The store name can be overriden by either overriding the defaultSource
--- method in derived classes or passing a "source" in the options table.
---
---
-- @param clsName Name of new class
-- @param def Attribute defitions for new class
-- @param options options for new class
--
-- @see ActiveLua.Store for connection specification details
-- @see defaultSource
-- @see defaultConnection
function extend(super, clsName, def, options)
    local cls = super:subclass(def)
    if not clsName then error("Expected classname in definition", 1) end
    -- Set class name
    cls:_injectClassName(clsName)
    -- Connect to store
    options = options or {}
    options.source = options.source or cls:defaultSource()
    cls:_injectConnection(cls:defaultConnection(options.source))

    -- Pick out attribute definitions and create table.
    local attrDefs = table.collect(def, function(k,v)
        if type(v) == "string" then
            return k,v
        end
        return nil
    end)
    -- Define primary key
    attrDefs.id = "pk"
    -- Try table creation, ignoring table existence errors
    pcall(cls:connection().createTable, cls:connection(), cls:tableName(), attrDefs)
    -- If the table already exists, the following loop will ensure that the
    -- attributes match up typewise and any new attributes are created. 
    for k,v in pairs(attrDefs) do
        if not cls:hasAttribute(k) then
            cls:addAttribute(k,v)
        end
        -- Inject getter and setter for each attribute 
        cls:_injectAccessors(k)
    end
    return cls
end

--- Returns the default name of the store. Unless overridden by subclasses
--- this returns "store.db"
--
-- @return the name of the store to connect to
function defaultSource(cls)
    return "store.db"
end

--- Creates and returns an instance of the connection to be used for instances
--- of this class. Unless overridden in exteded classes an instance of an
--- SQLite3 store is connected the given named store
--
-- @param storeName the name of the store to connect to
-- @return an instance of a default connection
-- @see defaultSource
function defaultConnection(cls, storeName)
    local storeClass = require "ActiveLua.Store.SQLite3"
    return storeClass:connect{
        source = storeName
    }
end


--- Returns the string that can be used to refer to this class in a foreign
--- key column. This is deduced by taking the className of the class,
--- lowercasing it and adding "_id" to to it if no options are passed. If
--- options is a table that containt an "attributeName" key then the value for
--- that key is prefixed onto the result.
-- 
-- @param options options table for foreignKey
-- @return a string representing the foreign key to this class 
function foreignKey(cls, options)
    local result = cls:className().."_id"
    if options and options.attributeName then
        result = options.attributeName.."_"..result
    end
    return string.lower(result)
end

--- Returns the string that can be used as an attribute name representing this
--- class. This is deduced by taking the className of the class and
--- lowercasing it. If an options table is passed and it contains an
--- "attributeName" key then the value for that key is returned instead
--
-- @param options option table for attributeKey
-- @return An attribute name for this class
function attributeKey(cls, options)
    if options and options.attributeName then
        return options.attributeName
    end
    return string.lower(cls:className())
end

--- Returns the table name in the store for this class. The tableName defaults
--- to the attributeKey for the class. In order to specify a different
--- tablename in the store override this method in your class definition. For
--- example:
---
--- <pre>
---     Person = Base:extend("Person", {
---         tableName = function()
---             return "people"
---         end,
---         firstName = "string"
---     })
--- </pre>
--
-- @return The table name for this class in the store
function tableName(cls)
    return cls:attributeKey()
end

--- Returns whether a given attribute is defined for this class. If the
--- attribute is defined in the store it's store type is also returned.
--
-- @param attrName Attribute name to check for
-- @return true if attribute is defined, false otherwise
function hasAttribute(class, attrName)
    local attrType = class:attributeTypes()[attrName]
    return  attrType ~= nil, attrType
end

--- Adds an attribute to the class with a given name and type. The attribute
--- type must be one of the supported types. This will extend the store with
--- an attribue of the given type as well.
---
--- Corresponding methods for getting the attribute "attrName()" and setting
--- the attribute "attrNameSet()" are injected into the class
---
--- Supported types are: pk, string, text, integer, float, decimal, timestamp,
--- date, binary and boolean
--
-- @param attrName Name of the new attribute. 
-- @param attrType Type of the new attribute
-- @return the class the attribute was added to
function addAttribute(class, attrName, attrType)
    local conn = class:connection()
    local dbDef, dbType = class:hasAttribute(attrName)
    if dbDef then
        if dbType ~= conn:columnTypeMap()[attrType] then
            error("Attribute "..attrName.." defined different in store")
        end
    else
        -- Column does not exist, add it
        conn:addColumn(class:tableName(), attrName, attrType)
    end
    class:_injectAccessors(attrName)
    return class
end


function _injectClassName(class, name)
    class.className = function()
        return name
    end
end

function _injectConnection(class, conn)
    class.connection = function()
        return conn
    end
end

function _injectAccessors(class, attrName)    
    class:injectGetter(attrName, function (object)
        return _defaultGetAttribute(object, attrName)
    end)
    class:injectSetter(attrName, function (object, value, persist)
        return _defaultSetAttribute(object, attrName, value, persist)
    end)
end

--- Returns the column types as defined in the backing store for this class.
--- The table has the column names as keys and the native store types as
--- values.
--
-- @return the store column types for the given class
function attributeTypes(class)
    return class:connection():columnTypes(class:tableName())
end

--- Classes offer a standard way for interested parties to listen for changes
--- to state. State changes are classified by "tag". The given function is
--- added to a list of maintained hooks, which is weakly referenced so
--- functions can be garbage collected if the real owner gives up on the
--- function. 
---   
--- There are a number of pre-defined hooks in ActiveLua which allow action to
--- be taken based on certain events in the lifecycle of an object. The
--- currently reserved tags are: "before-destroy" and "after-destroy"
---
--- The tag and it's related documentation describe what parameters the called
--- hook function can expect. For example, the before/after-destroy hooks will
--- pass in the id of the object that is being destroyed. 
---
--- Person:addHook("before-destroy", function(id) print(tostring(id)) end)
---
--
-- @param tag Tag identifying the hook set
-- @param func the function to call 
-- @see removeHook
-- @see callHook
function addHook(class, tag, func)
    class._hooks = class._hooks or {}
    class._hooks[tag] = class._hooks[tag] or {}
    table.insert(class._hooks[tag], func)
    return class
end

--- Removes a given function from the hook-set identified by the given tag. 
--
-- @param tag Name of the hook set
-- @param func Funtion to remove from hook-set
function removeHook(class, tag, func)
    if class._hooks and class._hooks[tag] then
        local hooks = class._hooks[tag]
        for i,v in ipairs(hooks) do
            if v == func then
                table.remove(hooks, i)
                break
            end
        end
    end
    return class
end

--- Calls all the function in a given named hook-set passing in the passed
--- arguments. Note that the hooks are called in the order they were added.
--- Errors raised in any of the called hook funtions will cause the remaining
--- functions not to be executed so be sure to implement the hook functions
--- accordingly
--
-- @param tag Tag identifying the hook-set
-- @param ... Parameters for the called hook functions
function callHook(class, tag, ...)
    if class._hooks and class._hooks[tag] then
        for _,v in ipairs(class._hooks[tag]) do
            v(...)
        end
    end
end

function injectSetter(class, name, func)
    class._setters = class._setters or {}
    class._setters[name] = func
    class[name.."Set"] = func
end

function injectGetter(class, name, func)
    class._getters = class._getters or {}
    class._getters[name] = func
    class[name] = func
end

--- Deletes the representation of this class in the underlying store and
--- closes it's connection to the store. Most methods on the class will not be
--- useable after this returns so use with extreme caution
function selfDestruct(class)
    class:callHook("before-selfdestruct")
    pcall(class:connection().dropTable, class:connection(), class:tableName())
    class:callHook("after-selfdestruct")
    return class
end

--
-- Object lifecycle. Creation, Saving, Destruction, Hooks
--

--- Creates an instance of a class as if constructed from the store. This
--- means that the given attributes are assumed to be persisted in the store
--- and the object has a valid id. The given attributes should be a attrName =
--- attrValue table where attrName is the name of the column in the store and
--- hence the name of the attribute in the class
---
--- Note: Do NOT use this method to construct arbitrary objects. Use "new"
--- instead 
--
-- @param attr Attributes as read from the store
function instantiate(class, attr)
    if attr == nil then return nil end
    local obj = class:new()
    for k,v in pairs(attr) do 
        obj:_setAttribute(k,v)
    end
    return obj
end


--- Creates an instance of the given base class with passed in attributes. The
--- object is not saved to the store. Use this method to construct new
--- instances of classes without saving them to the store immediately. At any
--- point in time you can save the object to store by calling the save method. 
--
-- @param attr Attribute names and values for the new instance
-- @return an unsaved instance of the class 
-- @see isCreated
-- @see isDirty
function new(class, attr)
    local object = class:basicNew()
    for k, v in pairs(attr or {}) do
        object:setAttribute(k,v, false)
    end
    return object
end

--- Creates an instance of the given class with the attribute and saves it in
--- the store. Attributes that are not in the definition of the class are not
--- saved, but will be available in the instance. 
---
--- Example:
---
--- Person:create {
---     firstName = "Jane",
---     lastName = "Doe"
--- }
--
-- @param attr Attribute names and values table for this instance
-- @return instance of the class with given attribute which is in the store 
function create(class, attr)
    return class:new(attr):save()
end

--- Creates and stores a number of instances of a given class. This is a
--- utility method to create many objects in the store at once. Note that the
--- creation of all items may not happen in a single transaction. To ensure
--- this wrap the call to this method in a transaction
---
--- Example:
---
--- Person:createAll {
---     {
---         firstName = "Jane",
---         lastName = "Doe"
---     },
---     {
---         firstName = "John",
---         lastName = "Smith"
---     }
--- }
--
-- @param list list of instances to create and store
-- @returns nothing
-- @see Connection.transactionDo
function createAll(class, list)
    for _,attr in ipairs(list) do
        class:create(attr)
    end
end

--- Updates the set of items in the store that match the given criteria, and
--- constrained by the given options with a new set of values. Values is a
--- table of name/value pairs where the names are filtered for valid
--- attributes in the store. 
--
-- @param values Values to update in matched items in the store
-- @param criteria Criteria to match items agains
-- @param options Options for the query
function updateAll(class, values, criteria, options)
    local colInfo = class:attributeTypes()
    -- Collect names and values of modified attributes that the connection
    -- recognizes
    local assigns = table.collect(values, function(k,v)
        if colInfo[k] then return k, v end
        return nil
    end)
    class:connection():update(class:tableName(), assigns, criteria, options)
    return class
end


--- Deletes one or more items in the backing store without invoking any of
--- registered hooks. Use this method with caution as associations use hooks
--- to maintain consistency in the backing store
--
-- @param criteria Criteria for the query
-- @param options Options for the query
-- @return the class where the deletions happened
function deleteAll(class, criteria, options)
    class:connection():delete(class:tableName(), criteria, options)
    return class
end

--- Destroys one or more items while invoking all the correct hooks. 
--
-- @param criteria for the destruction
-- @param options options for the query
-- @return the class where the destruction happened
function destroyAll(class, criteria, options)
    -- Destroy can cause updates in the store so first call destroy hooks
    options = options or {}
    local ids = class:ids(criteria, options)
    if #ids > 0 then 
        -- Call pre-destroy hook for each id
        for _,id in ipairs(ids) do
            class:callHook("before-destroy", id)
        end
        -- Delete all collected ids
        class:deleteAll{ id = ids }
        -- Then call post-destroy hooks for all
        for _,id in ipairs(ids) do
            class:callHook("after-destroy", id)
        end
    end
    return class
end

--- Executes a given function in a store transaction context, meaning that the
--- store will reflect the original state if the given function throws an
--- error at any point. Nested transactions are not supported by all stores
--- (like sqlite) so ensure that you do not nest calls to this method
--
-- @param func The function to protect in a store transaction
-- @return the class that executed the transaction
function transactionDo(class, func)
    class:connection():transactionDo(func)
    return class
end


--
-- Association shortcut declarations
--

--- @see ActiveLua.Associations.belongsTo
belongsTo = Associations.belongsTo

--- @see ActiveLua.Associations.hasOne
hasOne = Associations.hasOne

--- @see ActiveLua.Associations.hasMany
hasMany = Associations.hasMany

--- @see ActiveLua.Associations.holdsOne
holdsOne = Associations.holdsOne

--- @see ActiveLua.Associations.hasAndBelongsTomany
hasAndBelongsToMany = function(attrClass, assocClass, options)
    Associations.hasAndBelongsToMany(_M, attrClass, assocClass, options)
end


--
-- Finder methods
--

--- Locates the first entry in the store that matches the given criteria,
--- where criteria are a table of named attributes and their values
--- interpreted as logical AND expressions. Options are a table that contains
--- attribute names and values (which are all required to match in the query)
--- or a number of support special attribute names: order, limit, offset
--
-- @param criteria Criteria for the query
-- @param options Options for the query
-- @returns an instance of the given class if found, nil if not found
function first(class, criteria, options)
    return class:instantiate(class:rawFirst(criteria, options))
end

--- Locates all the entries in the store that match the given criteria, where
--- criteria are a table of named attributes and their values, interpreted as
--- a logical AND query. Options are in a table that contains attribute names
--- and values and affect the query. Supported options include: order, limit,
--- offset
--
-- @param criteria Criteria for the query
-- @param options Options for the query
-- @return an Array of results for the given query. The array may be empty
function all(class, criteria, options)
    -- Collect instances into an array
    local array = Array:new()
    for row in class:rawFind(criteria, options) do
        array:add(class:instantiate(row))
    end
    return array
end


--- Constructs and executes an sql query based on the options table. The
--- following options are supported: conditions, order, limit, offset
--
-- @param options Options for the query
-- @param criteria Criteria for the query interpreted as AND 
-- @return an iterator over the result of the find where each iteration is a table of values
function rawFind(class, criteria, options)
    return class:connection():find(class:tableName(), criteria, options)
end

--- Constructs an sql query based on the given criteria and limited by the
--- options table and returns the raw table representing the matching record
--- or nil if not found 
--
-- @param options Options for the query
-- @param criteria Criteria for the query interpreted as AND
-- @return the first matched record or nil if not found
function rawFirst(class, criteria, options)
    return class:connection():first(class:tableName(), criteria, options)
end

--- Returns the number of itmes in the store for this class that match given
--- criteria and controlled by given options
-- 
-- @param class The class to get the count for
-- @param criteria The criteria for the count
-- @param options Options for the query
-- @return The number of items in the store for this class
function count(class, criteria, options)
    return class:connection():count(class:tableName(), criteria, options)
end

--- Returns all the identifiers for the items in the store that match given
--- criteria in an indexable table
---
-- @param criteria criteria for the request
-- @param options options for the query
-- @return The ids for the given class in an indexable table
function ids(class, criteria, options)
    options = options or {}
    options.select = options.select or "id"
    local result = {}
    for row in class:rawFind(criteria, options) do 
        table.insert(result, row.id)
    end
    return result
end

--
-- Instance methods
--

function _defaultGetAttribute(object, name)
    if object._locals and object._locals[name] then
        return object._locals[name]
    elseif object._values then
        return object._values[name]
    end
    return nil
end

function _defaultSetAttribute(object, name, value, persist)
    if object:isFrozen() then
        error("Object is frozen and can not be modified", 1)
    end
    object._locals = object._locals or {}
    object._locals[name] = value
    if persist == nil or persist then 
        object:save()
    end
    return object
end

--- Gets a given attribute by name. Attributes are maintained in two sets. The
--- first is the in-memory set, called "locals" which represent all attributes
--- set on the object before they are persisted. The second is the "value" set
--- which represents the actual values persisted in the backing store. This
--- allows setting attributes before they are stored in the backing store.
---
--- In order to check whether an attribute is supported, use the hasAttribute
--- method. To check whether an object needs peristing (i.e. whether any local
--- values were set) use the isDirty method
---
--- Getting an attribute will first return a local value if set and then
--- revert to the persisted value if no local value is present. If the
--- attribute is not supported an error is thrown 
-- 
-- @param name name of the attribute to retrieve
-- @return value of attribute
-- @see setAttribute
-- @see isDirty
-- @see hasAttribute
function getAttribute(object, name)
    local getter = (object:class()._getters or {})[name]
    if getter then
        return getter(object)
    else
        error("No attribute named "..name)
    end
end

function _setAttribute(object, name, value)
    object._values = object._values or {}
    object._values[name] = value
    if object._locals then
        object._locals[name] = nil
    end
    return object
end

function _promoteAttributes(object, tbl)
    if not object._locals then return object end
    for k,_ in pairs(tbl) do
        local v = object._locals[k]
        if v then object:_setAttribute(k, v) end
    end
    return object
end

--- Sets a named attribute value on an object and saves the object to the
--- store by default unless persist is set to false. If the named attribute is
--- not supported an error is thrown
---
--- An object that has been frozen (usually by calling destroy) causes this
--- method to throw an error. 
--
-- @param name Name of attribute to set
-- @param value value of attribute to set
-- @param persist whether to persist the object to the store or not (default true)
-- @return the object on which the attribute was set or a raised error if frozen
function setAttribute(object, name, value, persist)
    local setter = (object:class()._setters or {})[name]
    if setter then
        return setter(object, value, persist)
    else
        error("No attribute named "..name)
    end
end

--- Returns whether the object was created at some point in the backing store
--- or not. 
--
-- @return true if object has a representation in the backing store
-- @see isDirty
function isCreated(object)
    return object:id() ~= nil
end

--- Returns whether the object still exists in the backing store or not. 
--
-- @return if object exists in backing store, false otherwise
function isPresent(object)
    if not object:isCreated() then return false end
    return object:class():count(object:id()) == 1
end

-- Returns whether the object needs saving or not. An object is dirty (and
-- hence needs saving) if it has not been created or if any of it's attributes
-- were changed. 
--
-- @return true if object is dirty or false if not
function isDirty(object)
    if not object:isCreated() then
        return true
    end
    for _,_ in ipairs(object._locals or {}) do
        return true
    end
    return false
end

--- Saves the object to the store, creating a new entry if it does not exist
--- or updating an existing entry if it does
--
-- @return object if saved, throws an error if a failure occured
function save(object)
    if object:isCreated() then 
        return object:_update() 
    else
        return object:_create() 
    end
end

function _create(object)
    local cls = object:class()
    local conn = cls:connection()
    local colInfo = cls:attributeTypes()
    -- Collect attributes to assign
    local assigns = table.collect(object._locals, function(k,v)
        if colInfo[k] then return k, v end
        return nil
    end)
    -- And execute statement
    local id = conn:insert(cls:tableName(), assigns)
    -- Set the primary key
    object:_setAttribute("id", id)
    -- make stored attributes permanent, leave rest as local
    return object:_promoteAttributes(assigns)
end

function _update(object)
    local class = object:class()
    class:updateAll(object._locals, object:id())
    return object:_promoteAttributes(class:attributeTypes())
end

--- Refreshes the object with attributes from the store. Any local attributes
--- that override stored attributes 
--
-- @return refreshed object if successful, nil if object is not present
-- @see isPresent
-- @see isCreated
function refresh(object)
    if not object:isCreated() then return nil end
    local attr = object:class():rawFirst(object:id())
    if not attr then return nil end
    for k,v in pairs(attr) do 
        object:_setAttribute(k,v)
    end
    return object
end


--- Freezes this object and then deletes the item in the store.
--
-- @return the frozen object
-- @see freeze
function destroy(object)
    -- Avoid endless loops through callbacks by checking if object is frozen
    if object:isFrozen() then return object end
    object:class():destroyAll(object:id())
    object:freeze()
    return object
end

--- Freezes the object so that further modifications are not saved to the
--- database. Once an object is frozen attributes can no longer be changed,
--- meaning that all Set methods will throw an error
--
-- @return the frozen object
function freeze(object)
    object._frozen = true
    return object
end

--- Returns whether the object is frozen or not
--
-- @return true if the object is frozen, false otherwise
function isFrozen(object)
    return object._frozen
end


