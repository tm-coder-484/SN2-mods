local U = {}

-- Unwrap a UE4SS RemoteUnrealParam wrapper to its underlying value.
-- Safe to call on anything — returns the input unchanged if no :get() is available.
function U.unwrap(v)
    if v == nil then return nil end
    if type(v) == "userdata" then
        local ok, inner = pcall(function() return v:get() end)
        if ok and inner ~= nil then return inner end
    end
    return v
end

-- Coerce a possibly-wrapped value into a Lua number, or fallback if not numeric.
function U.tonum(v, fallback)
    v = U.unwrap(v)
    if type(v) == "number" then return v end
    return tonumber(v) or fallback or 0
end

-- Safely call obj:methodName() and return its result, or nil if it errors.
function U.safeCall(obj, methodName, ...)
    if obj == nil then return nil end
    local args = { ... }
    local ok, result = pcall(function() return obj[methodName](obj, table.unpack(args)) end)
    if ok then return result end
    return nil
end

-- Get the class name of a UObject (handles wrapped objects).
function U.className(obj)
    obj = U.unwrap(obj)
    if obj == nil then return nil end
    local cls = U.safeCall(obj, "GetClass")
    cls = U.unwrap(cls)
    if cls == nil then return nil end
    local fname = U.safeCall(cls, "GetFName")
    fname = U.unwrap(fname)
    if fname == nil then return nil end
    return U.safeCall(fname, "ToString")
end

-- Get the full name of a UObject as a string (handles wrapped objects).
function U.fullName(obj)
    obj = U.unwrap(obj)
    if obj == nil then return nil end
    return U.safeCall(obj, "GetFullName")
end

-- Inspect a value for diagnostic logging — returns a short string describing it.
function U.describe(v)
    if v == nil then return "nil" end
    local t = type(v)
    if t == "userdata" then
        local inner = U.unwrap(v)
        local cls = U.className(inner)
        if cls then return "userdata(" .. cls .. ")" end
        return "userdata"
    end
    if t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "table(" .. n .. " keys)"
    end
    if t == "number" or t == "string" or t == "boolean" then
        return t .. "(" .. tostring(v) .. ")"
    end
    return t
end

return U
