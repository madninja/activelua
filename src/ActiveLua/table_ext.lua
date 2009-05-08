module ("table", package.seeall)

function table.collect(t, f, iter)
    local r = {}
    if not t then return r end
    iter = iter or table.pairs
    for k,v in iter(t) do
        local _k, _v = f(k,v)
        if _k and _v then 
            -- Key, value return is inserted as such
            r[_k] = _v
        elseif _k or _v then
            -- Single value return, just insert into result
            table.insert(r, _k or _v)
        else
            -- no inserts of any kind 
        end
    end
    return r
end

function table.keys(t, iter)
    local r = {}
    iter = iter or table.pairs
    for k,_ in iter(t) do
        table.insert(r, k)
    end
    return r
end

function table.values(t, iter)
    local r = {}
    iter = iter or table.pairs
    for _,v in iter(t) do 
        table.insert(r, v)
    end
    return r
end

function table.rsort(t, comp)
    table.sort(t, comp)
    return t
end

