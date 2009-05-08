---
--- See LICENSE file in top directory for copyright information

local Object    = require "ActiveLua.Object"

local table     = require "table" require "ActiveLua.table_ext"
local string    = string
local tonumber  = tonumber
local error     = error
local ipairs    = ipairs
local pairs     = pairs
local xpcall    = xpcall
local pcall     = pcall
local type      = type
local tostring  = tostring
local print     = print

module "ActiveLua.Store.SQL"
Object:subclass(_M)

--- Creates an instance of the given class which is connected to the
--- underlying store. The name of the store is retrieved from the option
--- table's "source" attribute. Any flags that need to get passed as part of
--- connecting to the store can be passed in with a "flags" attribute in the
--- info table.
---
--
-- @param options Options to construct the connection to the store
-- @param env The luasql environment to initiate the connection with
-- @return An instance of the given class
function connect(class, info, env)
    local src = info.source or "store.db"
    local conn = env:connect(src, info.flags)
    if not conn then
        error("SQL environment failed to connect")
    end
    return class:new {
        _source = src;
        _connection = conn;
        _columnTypes = {};
    }
end

--- Closes a given store for further modifications. The instance of the object
--- will no longer be functional after this call. 
function close(object)
    if object._connection then
        object._connection:close()
        object._connection = nil
    end
end


function __gc(object)
    object:close()
end

--- Creates a table with a primary key called "id" and columns defined by keys
--- and values in an attribute definition table. The attribute keys define the
--- column name and are expected to be SQL safe (i.e. they'r not escaped). 
---
--- The attribute values define the column types and are mapped to SQL type
--- definitions as defined in columnTypeFor. 
---
--- The following options can be specified for table creation: force (forces
--- table creation by dropping existing table)
--   
-- @param tableName Name of table to create
-- @param options Options for table creation
-- @return the store object, an error will be raised 
-- @see columnTypeFor
function createTable(store, tableName, attrDefs, options)
    options = options or {}
    attrDefs = attrDefs or {}
    if options.force then
        pcall(store.dropTable, store, tableName)
    end
    -- Construct column definitions
    local colDefs = table.collect(attrDefs, function(k,v)
       return k, store:columnTypeFor(v)
    end)
    -- Construct columnstrings for sql statement
    local colStr = table.collect(colDefs, function(k,v)
        return k.." "..v
    end)
    if #colStr == 0 then
        error("No attributes defined for table "..tableName)
    end
    store:execute("CREATE TABLE %s ( %s )", tableName, table.concat(colStr, ", "))
    -- Cache column definitions
    store._columnTypes[tableName] = colDefs
    return store
end

--- Drops a given table from the store. 
-- 
-- @param tableName Name of table to drop
-- @return the store if successful, a raised error on failure or unknown table
function dropTable(store, tableName)
    store:execute("DROP TABLE %s", tableName)
    return store
end

--- Returns the SQL type for a given ActiveLua store type. 
-- 
-- @param type ActiveLua type
-- @return SQL type for given ActiveLua type or error if no mapping found
function columnTypeFor(store, type)
    local result = store:columnTypeMap()[type]
    if result then return result end
    error("Failed to map type "..type.." to SQL type")
end

--- Retrieves the column names and types for a given table. The column types
--- are specified in connection specific terms. All column names that start
--- with "_" are considered system specific and ommitted from the result
--
-- @param tableName Name for table to get column information for
-- @return table of columnName to columnType pairs
function columnTypes(store, tableName)
    -- Look in cache first
    local result = store._columnTypes[tableName]
    if result == nil then
        -- Not found, fetch from database
        local cur = store:execute("SELECT * FROM %s", tableName)
        local colnames, coltypes = cur:getcolnames(), cur:getcoltypes()
        cur:close()
        result = table.collect(colnames, function(i,v)
            return v, coltypes[i]
        end)
        -- Cache column types
        store._columnTypes[tableName] = result
    end
    return result
end

--- Add a column to the given table. If the column already exists and is of
--- the same type as the requested column the request is considered
--- successful. If the column exists, but is of a different type, an error is
--- raised. 
--
-- @param tableName name of table to add column too
-- @param columnName name of column to add
-- @param columnType the ActiveLua type for the column
-- @return the store object. An error is raised on failure to alter the store
function addColumn(store, tableName, columnName, columnType)
    local cType = store:columnTypeFor(columnType)
    store:execute("ALTER TABLE %s ADD %s %s", tableName, columnName, cType)
    -- Reflect in columnType cache
    if store._columnTypes[tableName] then
        store._columnTypes[tableName][columnName] = cType
    end
    return store
end

--- Inserts a record into the store. The keys and values in the given "values"
--- table are used to construct a record to insert into the store. Options are
--- ignored for the SQL store
-- 
-- @param tableName Name of table to insert into
-- @param values Table with keys and values to insert into the table
-- @param options Options for insert. Ignored for the SQL store
-- @return the id of the last inserted record or a raised error on failure
function insert(store, tableName, values, options)
    local keys = table.keys(values)
    local values = table.collect(values, function(k,v)
        return store:_tosql(v)
    end)
    if #keys == 0 then
        return true
    end
    store:execute("INSERT INTO %s (%s) VALUES (%s)",
        tableName,
        table.concat(keys, ", "),
        table.concat(values, ", ") )
    return store:getLastId()
end

--- Updates a table with given values, which are named by their column name.
--- Criteria indicates the selected criteria for which records to update and
--- effectively represents the WHERE part of the sql statement.  
--
-- @param tableName Name of the table to update
-- @param values The column name and their values to update
-- @param criteria The selection criteria for which records to update
-- @return the store or a raised error on failure
function update(store, tableName, values, criteria)
    local assigns = table.collect(values, function(k,v)
        return k.."="..store:_tosql(v)
    end)
    if #assigns > 0 then
        local sql = string.format("UPDATE %s SET %s", tableName, table.concat(assigns, ", "))
        store:execute(store:_sqlAddCriteria(sql, criteria))
    end
    return store
end

--- Deletes all the items in the given named table that match the given set of
--- criteria. Note that without any criteria, all the records in the store are
--- removed. Deleteing records that do not exist is not considered an error. 
---
--- Options are ignored for the SQLStore delete
--
-- @param tableName Name of the table to remove items from
-- @param criteria The selection criteria for the records to delete
-- @param options Options for the delete
-- @return store on success 
function delete(store, tableName, criteria, options)
    local sql = string.format("DELETE FROM %s", tableName)
    store:execute(store:_sqlAddCriteria(sql, criteria))
    return store
end


--- Executes a query for a set of records in the store. The criteria are used
--- to construct simple "AND" relationships, whereas options can be utilized
--- to construct more complex queries. The supported options in SQLite3 are:
--- select, from, order limit and offset which map pretty obviously to their
--- SQL equivalent
-- 
-- @param tableName Table to search over
-- @param criteria Name, value criteria to use in simple AND queries
-- @param options Options to override and enhance the query 
-- @return an interator function on the result of the query or false and a message otherwise
function find(store, tableName, criteria, options)
    local cur = store:execute(store:_sqlConstructSelect(tableName, criteria, options))
    return function ()
        return cur:fetch({}, 'a') 
    end
end

--- Retrieves the first entry that matches the given criteria. This is an
--- optinized version of the find method
-- 
-- @param tableName Table to search over
-- @param criteria Name, value criteria to use in simple AND queries
-- @param options Options to override and enhance the query 
-- @return the first found item, nil if not found, a raised error on failures
function first(store, tableName, criteria, options)
    local cur = store:execute(store:_sqlConstructSelect(tableName, criteria, options))
    local result = cur:fetch({}, 'a')
    cur:close()
    return result
end

--- Returns the number of records in given table
--
-- @param tableName Table to count records for
-- @return number of records in table, or a raised error on failure
function count(store, tableName, criteria, options)
    options = options or {} 
    options.select = options.select or "COUNT(*)"
    local sql = _sqlConstructSelect(store, tableName, criteria, options)

    local cur = store:execute(sql)
    val = tonumber(cur:fetch())
    cur:close()
    return val
end

--- Escape a given string using the store specific string escaping
--- semantics
--
-- @param str The string to escape
-- @return The escaped string
function escape(store, str)
    return store._connection:escape(str)
end


--- Eecutes a given function in an sql transaction. If the function succeeds
--- the transaction will be committed. Any errors will cause the transaction
--- to be rolled back
--
-- @param func Function to execute in a transaction block
-- @return the store or a raised error on failure to begin or commit the transaction
function transactionDo(store, func)
    local rolled = false;
    store:execute("BEGIN")
    xpcall(func, function(err)
        -- TODO: This may need to be proteced too
        store:execute("ROLLBACK")
        rolled = true
    end)
    if not rolled then
        store:execute("COMMIT")
    end
    return store
end

--- Exectute a given sql statement. The variable argument can be used to
--- specify parameters that are substituted in the given sql string using
--- string.format. Connection specific escaping can be achieved by calling
--- store:escape
---
--- Example: store:execute("SELECT * from %s", "people")
---
-- 
-- @param sql A string with the sql statement
-- @param ... The parameters to insert into the statement
function execute(store, sql, ...)
    if ... then
        sql = string.format(sql, ...)
    end 
    -- print(sql)
    local result, msg = store._connection:execute(sql)
    -- Check for errors and retry if changed (SQLite specific, but should
    -- do no harm) 
    if msg then 
        if string.match(msg, "database schema has changed") then
            -- Reset column type cache
            store._columnTypes = {}
        end
        result, msg = store._connection:execute(sql)
    end
    if msg then error(msg) end
    return result
end


--
-- Private functions
--


function _tosql(store, val)
    local valType = type(val)
    local str = nil
    if valType == "number" then
        str = tostring(val)
    elseif valType == "string" then
        str = string.format("'%s'", store:escape(val))
    elseif valType == "table" and type(val.id) == "function" then
        str = tostring(val:id())
    elseif valType == "nil" then
        str = "NULL"
    end
    if not str then error("Unable to convert "..valType.." to SQL") end
    return str
end


function _sqlAddSelect(store, sql, select, default)
    return sql.."SELECT "..(select or default)
end

function _sqlAddJoin(store, sql, tableName, join)
    if join == nil then return sql end
    if not join.tableName then error("Expected 'tableName' in join") end
    -- Collect ON attributes
    join.on = join.on or {}
    local ons = table.collect(join.on, function(k,v)
        return tableName.."."..k.." = "..join.tableName.."."..v
    end)
    -- Ensure we have something to join on
    if #ons == 0 then 
        error ("Expected 'on' table in join")
    end
    local joinStr = string.format(" %s JOIN %s ON %s", 
        join.type or "INNER",
        join.tableName,
        table.concat(ons, ", "))
    return sql..joinStr
end

function _sqlAddFrom(store, sql, from, default)
    return sql.." FROM "..(from or default)
end

function _sqlAddCriteria(store, sql, conds)
    if conds == nil then return sql end
    local condStr = ""
    if type(conds) == "number" then
        condStr = "id = "..store:_tosql(conds)
    elseif type(conds) == "string" then
        condStr = conds
    elseif type(conds) == "table" then
        -- A table is collected as an AND set
        local andArray = {}
        for k,v in pairs(conds) do
            -- A value that is a table is collected as an IN set
            if type(v) == "table" and #v > 0 then
                if #v == 1 then
                    -- Optimize for the case when there's only one
                    table.insert(andArray, 
                        string.format("%s = %s", k, store:_tosql(v[1])))
                else
                    local orArray = table.collect(v, function(i,val) 
                        return store:_tosql(val)
                    end, ipairs)
                    table.insert(andArray, 
                        string.format("%s IN ( %s )", k, table.concat(orArray, ", ")))
                end
            else
                table.insert(andArray, string.format("%s = %s", k, store:_tosql(v)))
            end
        end
        condStr = table.concat(andArray, " AND ")
    else
        error("Expected condition number, table or string and got a "..type(conds))
    end
    if #condStr > 0 then
        sql = sql.." WHERE "..condStr
    end
    return sql
end

function _sqlAddOrder(store, sql, order)
    if order == nil then return sql end
    return sql.." ORDER BY "..order
end

function _sqlAddLimit(store, sql, limit, offset)
    if limit then
        sql = sql.." LIMIT "..limit
        if offset then
            sql = sql.." OFFSET "..offset
        end
    end
    return sql
end

function _sqlConstructSelect(store, tableName, criteria, options)
    options = options or {}

    local sql = store:_sqlAddSelect("", options.select, "*")
    sql = store:_sqlAddFrom(sql, options.from, tableName)
    sql = store:_sqlAddJoin(sql, tableName, options.join)
    sql = store:_sqlAddCriteria(sql, criteria)
    sql = store:_sqlAddOrder(sql, options.order)
    sql = store:_sqlAddLimit(sql, options.limit, options.offset)
    return sql
end


