local Config = require("config")
local U      = require("unreal_util")
local SurfaceUnlock = {}

SurfaceUnlock._pendingNormalZ = nil
SurfaceUnlock._pendingRemove  = nil
SurfaceUnlock._registered = false
SurfaceUnlock._diagCount  = 0
SurfaceUnlock.DIAG_LIMIT  = 10

-- Candidate field names on SN2ItemBrushActionData that might control validity.
-- The PRE hook tries each one. Update this list once the SDK dump reveals
-- the real field names.
local VALIDITY_FIELDS = {
    "bIsValid", "IsValid",
    "bCanPlace", "CanPlace",
    "bAllowed", "Allowed",
    "bIsBlocked", "IsBlocked",
    "bIsAllowedOnSurface", "IsAllowedOnSurface",
    "bSurfaceValid", "SurfaceValid",
    "bGhostValid", "GhostValid",
    "bIsValidTarget", "IsValidTarget",
}

-- Candidate paths to a surface normal Z value we can rewrite.
-- Each entry is a list of nested property names to walk.
local NORMAL_PATHS = {
    { "HitResult", "ImpactNormal", "Z" },
    { "Hit",       "ImpactNormal", "Z" },
    { "HitResult", "Normal",       "Z" },
    { "Hit",       "Normal",       "Z" },
    { "Normal",    "Z" },
    { "TargetNormal", "Z" },
    { "SurfaceNormal", "Z" },
}

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

-- Safe property get/set wrappers (Mariana's pattern)
local function getProp(obj, name)
    if not obj then return nil end
    local ok, v = pcall(function() return obj[name] end)
    if ok then return v end
    return nil
end

local function setProp(obj, name, value)
    if not obj then return false end
    local ok = pcall(function() obj[name] = value end)
    return ok
end

-- Walk a nested property path; returns the final value or nil
local function getNestedProp(obj, path)
    local cur = U.unwrap(obj)
    for _, name in ipairs(path) do
        if cur == nil then return nil end
        cur = U.unwrap(getProp(cur, name))
    end
    return cur
end

-- Walk a nested property path stopping at second-to-last, then set the last field
local function setNestedProp(obj, path, value)
    local cur = U.unwrap(obj)
    for i = 1, #path - 1 do
        if cur == nil then return false end
        cur = U.unwrap(getProp(cur, path[i]))
    end
    if cur == nil then return false end
    return setProp(cur, path[#path], value)
end

-- For the FIRST hook fire, log everything we can find on the action data.
-- This is invaluable when probing — once the mod is working, set DIAG_LIMIT to 0.
local function deepInspect(actionData)
    if SurfaceUnlock._diagCount >= SurfaceUnlock.DIAG_LIMIT then return end
    local ad = U.unwrap(actionData)
    if not ad then return end
    print("[SeamlessGlass.deep] ActionData inspection:")
    for _, fieldName in ipairs({
        "HitResult", "Hit", "Normal", "TargetActor", "TargetComponent",
        "Buildable", "BuildableClass", "Ghost", "Piece", "Item", "ItemClass",
        "bIsValid", "IsValid", "bCanPlace", "bAllowed", "bIsBlocked",
        "Transform", "Rotation", "Location", "Player", "Instigator",
    }) do
        local v = getProp(ad, fieldName)
        if v ~= nil then
            print("[SeamlessGlass.deep]   ." .. fieldName .. " = " .. U.describe(v))
        end
    end
end

-- Attempt to "fix" the action data so the placement passes.
-- Returns true if any modification was made (for logging).
local function patchActionData(actionData)
    local ad = U.unwrap(actionData)
    if not ad then return false end
    local changed = false

    -- 1) Rewrite the surface normal Z toward a wall-ish value (small Z)
    --    Existing floor normal Z is +1; ceiling is -1. We push toward 0.
    --    Note: this only helps if the game re-reads the modified normal.
    for _, path in ipairs(NORMAL_PATHS) do
        local z = getNestedProp(ad, path)
        z = U.tonum(z, nil)
        if z ~= nil and math.abs(z) > 0.5 then
            if setNestedProp(ad, path, 0.0) then
                print("[SeamlessGlass] rewrote " .. table.concat(path, ".") .. " from " .. z .. " to 0.0")
                changed = true
                break
            end
        end
    end

    -- 2) Force any validity-flag we can find to true
    for _, field in ipairs(VALIDITY_FIELDS) do
        local existing = getProp(ad, field)
        if existing ~= nil and (existing == false or existing == 0) then
            if setProp(ad, field, true) then
                print("[SeamlessGlass] forced " .. field .. " = true")
                changed = true
            end
        end
    end

    return changed
end

function SurfaceUnlock.register()
    if SurfaceUnlock._registered then
        print("[SeamlessGlass] surface_unlock already registered, skipping")
        return
    end

    -- PRE hook on TryApply: inspect + patch the SN2ItemBrushActionData
    local ok = pcall(function()
        RegisterHook(Config.BUILDER_PLACE_FUNC,
            function(Context, ActionData, RetSlot)
                diagLog("PLACE_PRE", Context, ActionData, RetSlot)
                if SurfaceUnlock._diagCount <= 2 then deepInspect(ActionData) end
                local ad = U.unwrap(ActionData)
                -- Record the normal Z (if we can find it) for rotation in the post-hook
                for _, path in ipairs(NORMAL_PATHS) do
                    local z = U.tonum(getNestedProp(ad, path), nil)
                    if z ~= nil then
                        SurfaceUnlock._pendingNormalZ = z
                        break
                    end
                end
                patchActionData(ad)
            end,
            function(Context, ActionData, RetSlot)
                diagLog("PLACE_POST", Context, ActionData, RetSlot)
                -- After placement: if it was on a horizontal surface, apply rotation
                local z = SurfaceUnlock._pendingNormalZ
                SurfaceUnlock._pendingNormalZ = nil
                if not z or math.abs(z) < 0.5 then return end

                -- Find the placed actor — typically in ActionData.Ghost, .Piece, .TargetActor
                local ad = U.unwrap(ActionData)
                local placed = nil
                for _, fld in ipairs({ "PlacedActor", "Ghost", "Piece", "TargetActor", "Buildable" }) do
                    local v = U.unwrap(getProp(ad, fld))
                    if v and U.fullName(v) then placed = v; break end
                end
                if not placed then return end

                local pitch = z > 0 and 180 or 0
                pcall(function()
                    placed:K2_SetActorRotation({ Pitch = pitch, Yaw = 0, Roll = 0 }, false)
                end)
            end
        )
    end)
    if not ok then print("[SeamlessGlass] WARN: place hook failed to register") end

    -- Validity hook — leave registered in case the function path is used elsewhere
    pcall(function()
        RegisterHook(Config.BUILDER_VALIDITY_FUNC,
            function() end,
            function(_, ret)
                diagLog("VALIDITY", _, ret)
                if ret then pcall(function() ret:set(true) end) end
            end
        )
    end)

    SurfaceUnlock._registered = true
    print("[SeamlessGlass] surface unlock hooks registered")
end

return SurfaceUnlock
