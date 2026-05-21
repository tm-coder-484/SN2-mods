local Config = require("config")
local U      = require("unreal_util")
local SurfaceUnlock = {}

SurfaceUnlock._pendingNormalZ = nil
SurfaceUnlock._pendingRemove  = nil
SurfaceUnlock._registered = false
SurfaceUnlock._diagCount  = 0
SurfaceUnlock.DIAG_LIMIT  = 5  -- log first N hook fires for diagnostics

local function diagLog(label, ...)
    if SurfaceUnlock._diagCount >= SurfaceUnlock.DIAG_LIMIT then return end
    SurfaceUnlock._diagCount = SurfaceUnlock._diagCount + 1
    local args = { ... }
    local parts = { "[SeamlessGlass.diag] " .. label .. " argc=" .. #args }
    for i, v in ipairs(args) do
        table.insert(parts, "  [" .. i .. "] " .. U.describe(v))
    end
    print(table.concat(parts, "\n"))
end

local function isWindowPiece(buildable)
    buildable = U.unwrap(buildable)
    if buildable == nil then return false end
    local name = U.className(buildable)
    if not name then return false end
    for _, cls in ipairs(Config.WINDOW_PIECE_CLASSES) do
        if name:find(cls, 1, true) then return true end
    end
    return false
end

-- Pull a normal Z and a Buildable reference out of however the SN2 ability
-- presents them. We don't know the exact param order, so we search.
local function extractContext(args)
    local hitNormalZ = nil
    local buildable  = nil

    for _, raw in ipairs(args) do
        local v = U.unwrap(raw)
        if v ~= nil and (type(v) == "userdata" or type(v) == "table") then
            -- Try a HitResult-shaped value
            local ok, hr = pcall(function() return v.HitResult or v.Hit or v end)
            if ok and hr then
                local hru = U.unwrap(hr)
                local ok2, n = pcall(function() return hru.ImpactNormal or hru.Normal end)
                if ok2 and n then
                    local nu = U.unwrap(n)
                    local ok3, z = pcall(function() return nu.Z end)
                    if ok3 and z ~= nil then
                        hitNormalZ = U.tonum(z, nil)
                    end
                end
            end
            -- Try a Buildable-shaped value (anything with a class name containing Window/Glass)
            if not buildable then
                local cn = U.className(v)
                if cn and (cn:find("Window") or cn:find("Glass") or cn:find("Buildable") or cn:find("Piece")) then
                    buildable = v
                end
            end
            -- Or a field literally named Buildable / Piece / Ghost
            if not buildable then
                local ok4, b = pcall(function() return v.Buildable or v.Piece or v.Ghost end)
                if ok4 and b then
                    buildable = U.unwrap(b)
                end
            end
        end
    end

    return hitNormalZ, buildable
end

function SurfaceUnlock.register()
    if SurfaceUnlock._registered then
        print("[SeamlessGlass] surface_unlock already registered, skipping")
        return
    end

    -- Wrap registrations in pcall — Blueprint UFunctions can be unloaded between inits
    local ok1 = pcall(function()
        RegisterHook(Config.BUILDER_VALIDITY_FUNC,
            function() end,
            function(...)
                diagLog("VALIDITY", ...)
                local args = { ... }
                local z, buildable = extractContext(args)
                if not buildable or not isWindowPiece(buildable) then return end
                if z == nil then return end
                if math.abs(z) > 0.966 then
                    -- Force result to true. UE4SS exposes return value as last argument.
                    local rv = args[#args]
                    if rv and type(rv) == "userdata" then
                        pcall(function() rv:set(true) end)
                    end
                end
            end
        )
    end)
    if not ok1 then print("[SeamlessGlass] WARN: validity hook failed to register") end

    local ok2 = pcall(function()
        RegisterHook(Config.BUILDER_PLACE_FUNC,
            function(...)
                diagLog("PLACE_PRE", ...)
                local args = { ... }
                local z = select(1, extractContext(args))
                if z and math.abs(z) > 0.966 then
                    SurfaceUnlock._pendingNormalZ = z
                else
                    SurfaceUnlock._pendingNormalZ = nil
                end
            end,
            function(...)
                diagLog("PLACE_POST", ...)
                if not SurfaceUnlock._pendingNormalZ then return end
                local args = { ... }
                -- The placed actor is typically the return value (last arg) or one of the params
                for i = #args, 1, -1 do
                    local v = U.unwrap(args[i])
                    if v and U.className(v) then
                        local pitch = SurfaceUnlock._pendingNormalZ > 0 and 180 or 0
                        pcall(function()
                            v:K2_SetActorRotation({ Pitch = pitch, Yaw = 0, Roll = 0 }, false)
                        end)
                        break
                    end
                end
                SurfaceUnlock._pendingNormalZ = nil
            end
        )
    end)
    if not ok2 then print("[SeamlessGlass] WARN: place hook failed to register") end

    SurfaceUnlock._registered = true
    print("[SeamlessGlass] surface unlock hooks registered")
end

return SurfaceUnlock
