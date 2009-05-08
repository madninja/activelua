---
--- See LICENSE file in top directory for copyright information

local SQL   = require "ActiveLua.Store.SQL"
local lsql  = require "luasql.sqlite3"


module "ActiveLua.Store.SQLite3"
SQL:subclass(_M)

--- Creates an instance of the SQLite3 class that is connected to the
--- underlying store. The name of the store is retrieved from the option
--- table's "source" attribute
--
-- @param options Options to construct the connection to the store
-- @return An instance of the given class
function connect(class, info)
    local store = class:super().connect(class, info, lsql.sqlite3())
    store:busytimeout(info.busytimeout or 2000)
    return store
end

--- Returns the last inserted row id
-- 
-- @return last inserted row id
function getLastId(store)
    return store._connection:getlastautoid()
end

--- Sets the busy wait time for a locked database. Previous settings of the
--- busytimeout are overridden
--
-- @param msecs milliseconds to wait for a busy database
-- @return the store
function busytimeout(store, msecs)
    store._connection:busytimeout(msecs)
    return store
end

--- Returns the mapping from ActiveLua types to SQL column types as understood
--- by SQLite3
--
-- @return table of ActiveLua names to SQL type names
function columnTypeMap(store)
    return _columnTypeMap
end

_columnTypeMap = {
    pk          = "INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL";
    integer     = "INTEGER";
    float       = "FLOAT"; 
    string      = "TEXT";
    text        = "TEXT";
    decimal     = "DECIMAL";
    timestamp   = "TIMESTAMP";
    date        = "DATE";
    binary      = "BINARY";
}

