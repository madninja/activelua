-- Defines methods for classes
---
--- See LICENSE file in top directory for copyright information

local setmetatable  = setmetatable

module "ActiveLua.Class"

function indexFor(cls)
    return function(object, key)
        local val = cls[key]
        if val then return val end
        local super = object:super()
        if super then return super[key] end
        return nil
    end
end

__index = indexFor(_M)

function subclass(super, tbl)
    local newClass = setmetatable(tbl or {}, _M)
    newClass.__super = super
    newClass.__index = indexFor(newClass)
    return newClass
end

function subclassOf(class, super)
    while class do
        if class == super then return true end
        class = class:super()
    end
    return class == super
end

function super(class)
    return class.__super
end



