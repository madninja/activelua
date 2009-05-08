---
--- See LICENSE file in top directory for copyright information

local Store = require "ActiveLua.Store.SQL"

require "lunit"

lunit.setprivfenv()
lunit.import "assertions"
lunit.import "checks"

--
-- SQL Constructs
--
local sql = lunit.TestCase("SQL Construction")

function sql:test_basic()
    local str = Store:_sqlConstructSelect("people")
    assert_equal("SELECT * FROM people", str)
end

function sql:test_limitOffset()
    local str = Store:_sqlConstructSelect ("people", nil, {
        limit = 10
    })
    assert_equal("SELECT * FROM people LIMIT 10", str)

    local str = Store:_sqlConstructSelect ("people", nil, {
        limit = 10,
        offset = 2
    })
    assert_equal("SELECT * FROM people LIMIT 10 OFFSET 2", str)
end

function sql:test_orderBy()
    local str = Store:_sqlConstructSelect ("people", nil, {
        order = "firstName ASC"
    })
    assert_equal("SELECT * FROM people ORDER BY firstName ASC", str)
    local str = Store:_sqlConstructSelect("people", nil, {
        order = "firstName ASC, lastName DESC"
    })
    assert_equal("SELECT * FROM people ORDER BY firstName ASC, lastName DESC", str)
end

function sql:test_select()
    local str = Store:_sqlConstructSelect ("people", nil, {
        select = "id, firstName"
    })
    assert_equal("SELECT id, firstName FROM people", str)
end

function sql:test_criteria()
    local str = Store:_sqlAddCriteria("", 1)
    assert_equal(" WHERE id = 1", str)
    
    local str = Store:_sqlAddCriteria("", "magic=5")
    assert_equal(" WHERE magic=5", str)
    
    local str = Store:_sqlAddCriteria("", { age = 25, id = {21, 22, 23}})
    assert_equal(" WHERE age = 25 AND id IN ( 21, 22, 23 )", str)
    
    local str = Store:_sqlAddCriteria("", { id = {22}; age = 25 })
    assert_equal(" WHERE id = 22 AND age = 25", str)
    
    assert_error("Expected sql conversion error", function()
        Store:_sqlAddCriteria("", { id = {}})
    end)
end

function sql:test_join()
    local str = Store:_sqlAddJoin("", "project", {
        tableName = "developerproject",
        on = {id = "project_id"}
    })
    assert_equal(" INNER JOIN developerproject ON project.id = developerproject.project_id", str)

    local str = Store:_sqlAddJoin("", "project", {
        type = "OUTER",
        tableName = "developerproject",
        on = {id = "project_id"}
    })
    assert_equal(" OUTER JOIN developerproject ON project.id = developerproject.project_id", str)

    assert_error("Expected missing 'on'", function()
        Store:_sqlAddJoin("", "project", {
            tableName = "developerproject"
        })
    end)
end


