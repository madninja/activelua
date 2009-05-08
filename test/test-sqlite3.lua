---
--- See LICENSE file in top directory for copyright information

Store = require "ActiveLua.Store.SQLite3"

require "lunit"

lunit.setprivfenv()
lunit.import "assertions"
lunit.import "checks"

--
-- Connection methods
--

local schema = lunit.TestCase("SQLite3 Store")

function schema:setup()
    connection = Store:connect {
        source = ":memory:"
    }
end

function createPeople(conn)
    return connection:createTable("people", { id = "pk"}, { force = true})
end

function schema:test_connect()
    assert_not_nil(connection)
end

function schema:test_createTable()
    assert_equal(connection, createPeople(connection))
    -- Ensure creation of same table fails
    assert_error("Create existing table", function () connection:createTable("people") end)

    -- Creation with attribute definition
    assert_equal(connection, connection:createTable("games", {
       name = "string",
       time = "timestamp",
    }, { force = true }))
    assert_equal(connection:columnTypeFor("string"), connection:columnTypes("games").name)
    assert_equal(connection:columnTypeFor("timestamp"), connection:columnTypes("games").time)
end

function schema:test_dropTable()
    -- Force table creation
    assert_equal(connection, createPeople(connection))
    -- Drop table
    assert_equal(connection, connection:dropTable("people"))
    -- Ensure re-creation succeeds (meaning drop worked)
    assert_equal(connection, createPeople(connection))
    -- Check for unknown drop failing
    assert_error("Unknown table drop", function () connection:dropTable("unknown") end)
end

function schema:test_addColumn()
    assert_equal(connection, createPeople(connection))
    assert_equal(connection, connection:addColumn("people", "name" , "string"))
    assert_equal(connection:columnTypeFor("string"), connection:columnTypes("people").name)
    -- Add some data
    connection:insert("people", { name = "Jane Doe"})
    -- Add another column
    assert_not_nil(connection:addColumn("people", "age" , "integer"))
    
    -- Try unknown type
    assert_error("Unknown column type", 
        function () connection:addColumn("people", "last", "foo") end)
    -- Try unknown tableName
    assert_error("Unknown table column add", 
        function () connection:addColumn("unknownTable", "age", "integer") end)
    -- Try nil params
    assert_error("Nil params on column add", 
        function () connection:addColumn() end)
end

function schema:test_columnTypes()
    connection:createTable("people", {
        name = "string",
        age = "integer"
    }, { force = true })

    assert_equal(connection:columnTypeMap()["string"], 
                connection:columnTypes("people")["name"])
    assert_equal(connection:columnTypeMap()["integer"], 
                connection:columnTypes("people")["age"])
    -- Unknown or nil table
    assert_error("Unknown table column types", 
        function () connection:columnTypes("unknownTable") end)
    assert_error("Nil table column types",
        function () connection:columnTypes() end)
end

function schema:test_insert()
    connection:createTable("people", {
        name = "string",
        age = "integer"
    }, { force = true })
    -- Insert returns the record id for the inserted item
    assert_equal(1, connection:insert("people", {
        name = "Jane Doe";
        age = 22
    }))
    assert_equal(1, connection:count("people"))
end

function schema:test_count()
    connection:createTable("people", {
        name = "string",
        age = "integer"
    }, { force = true })
    -- Insert returns the record id for the inserted record
    connection:insert("people", {
        name = 'Jane Doe';
        age = 22
    })
    connection:insert("people", {
        name = 'Joe Smith';
        age = 22
    })
    assert_equal(2, connection:count( "people", { age = 22 }))

    assert_error("Unknown table count", 
        function () connection:count("unknownTable") end)
end

function schema:test_find()
    connection:createTable("people", {
        name = "string",
        age = "integer"
    }, { force = true })
    -- Insert returns the record id for the inserted record
    assert_equal(1, connection:insert("people", {
        name = 'Jane Doe';
        age = 22
    }))

    assert_equal(2, connection:insert("people", {
        name = 'Joe Smith';
        age = 22
    }))

    for row in connection:find("people", { name = 'Jane Doe'}) do
        assert_equal("Jane Doe", row.name)
        assert_equal("number", type(row.age))
        assert_equal(22, row.age)
    end
end

function schema:test_first()
    connection:createTable("people", {
        id = "pk",
        name = "string",
    }, { force = true })
    -- Insert returns the record id for the inserted record
    connection:insert("people", { name = 'Jane Doe' })
    connection:insert("people", { name = 'Joe Smith' })
    assert_equal("Jane Doe", connection:first("people", 1).name)
    assert_equal("Joe Smith", connection:first("people", 2).name)
end

function schema:test_delete()
    connection:createTable("people", {
        id = "pk",
        name = "string",
    }, { force = true })
    connection:insert("people", { name = 'Jane Doe' })
    connection:insert("people", { name = 'Joe Smith' })
    connection:insert("people", { name = 'John Goodwill' })
    -- Remove one item by name
    assert_equal(connection, 
        connection:delete("people", { name = "Jane Doe" }))
    -- Remove one item by id
    assert_equal(connection, connection:delete("people", 3))
    assert_equal(1, connection:count("people"))
    assert_equal("Joe Smith", 
        connection:first("people ", { name = "Joe Smith" }).name)
    -- Remove all items
    assert_equal(connection, connection:delete("people"))
    assert_equal(0, connection:count("people"))
end

function schema:test_update()
    connection:createTable("people", {
        id = "pk",
        name = "string",
        age = "integer"
    }, { force = true })
    connection:insert("people", {
        name = 'Jane Doe';
        age = 22
    })
    connection:insert("people", {
        name = 'Joe Smith';
        age = 22
    })
    -- Do update
    assert_not_nil(connection:update("people", {
        age = 44
    }, {
        name = 'Jane Doe'
    }))
    for row in connection:find("people", { name = 'Jane Doe'}) do 
        assert_equal("Jane Doe", row.name)
        assert_equal(44, row.age)
    end
    -- Unknown update
    assert_error("Unknown table update", 
        function () 
            connection:update("unknownTable", { age = 44 }, { name = "Jane Doe" })
        end)
end


function schema:test_transaction()
    connection:createTable("people", {
        id = "pk",
        name = "string",
        age = "integer"
    }, { force = true })
    -- Succesful transaction
    connection:transactionDo(function()
        connection:insert("people", {
            name = 'Jane Doe';
            age = 22
        })
        connection:insert("people", {
            name = 'Joe Smith';
            age = 22
        })
    end)
    assert_equal(2, connection:count("people"))
    -- Fail transaction
    connection:transactionDo(function()
        connection:insert("people", {
            name = 'John Worthington';
            age = 54
        })
        error("Transaction error throw")
    end)
    assert_equal(2, connection:count("people"))
end
