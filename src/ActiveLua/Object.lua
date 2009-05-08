---
--- See LICENSE file in top directory for copyright information

local getmetatable  = getmetatable
local setmetatable  = setmetatable
local Class         = require("ActiveLua.Class")

module ("ActiveLua.Object")
Class.subclass(nil, _M)

-- 
-- Class methods
--

--- Returns whether instances of this class are indexable. Object and its
--- sunbclasses are not by default indexable using numeric indexes. 
--
-- @return false
function isIndexed(class)
    return false
end

--- Constructs a basic new instance of the class with the given table as it's
--- instance variables. Subclasses can override the new method, but should
--- call basicNew to maintain the inheritance tree
-- 
-- @param tbl Table of attributes and functions for instance
-- @return instantiated object
function basicNew(class, tbl)
    return setmetatable(tbl or {}, class)
end


--- Returns a new instance of the given class. Subclasses can override this to
--- provide different new behavior but should ensure to call basicNew to
--- maintain the inheritance tree
--
-- @param tbl Table of attributes and functions for instance
-- @return instantiated object
function new(class, tbl)
    return basicNew(class, tbl)
end

-- 
-- Instance methods
--
function super(object)
    return object:class():super()
end

function class(object)
    return getmetatable(object)
end

function instanceOf(object, class)
    return object:class():subclassOf(class)
end


