local passed = 0
local failed = 0

function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("PASS: " .. name)
    else
        failed = failed + 1
        print("FAIL: " .. name .. "\n  " .. tostring(err))
    end
end

function assertEqual(a, b, msg)
    if a ~= b then
        error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a), 2)
    end
end

function assertNil(v, msg)
    if v ~= nil then error((msg or "") .. " expected nil, got " .. tostring(v), 2) end
end

function assertNotNil(v, msg)
    if v == nil then error((msg or "") .. " expected non-nil", 2) end
end

dofile("tests/test_adjacency.lua")
dofile("tests/test_post_hider.lua")

print("\n" .. passed .. " passed, " .. failed .. " failed")
if failed > 0 then os.exit(1) end
