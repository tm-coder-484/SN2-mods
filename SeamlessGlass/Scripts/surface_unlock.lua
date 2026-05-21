local Config = require("config")
local U      = require("unreal_util")
local SurfaceUnlock = {}

SurfaceUnlock._pendingRemove = nil
SurfaceUnlock._registered    = false
SurfaceUnlock._patched       = {}   -- actionDataFullName -> { mode-index -> bool }

-- Strategy: at game start (and periodically), scan all USN2ItemBrushActionData
-- instances. For each one, walk the SDK-confirmed structure:
--
--   ActionData.EditModes : TArray<FSN2EditMode>
--     EditMode.EditBrushes : TMap<FSN2EditBrushKey, FSN2EditBrush>
--       EditBrush.InitialPiecePlacementParams : FSN2PlacementParams
--         PlacementParams.AllowedSurfaces : int32  (bitmask)
--
-- Bitmask from EBuilderPlacementSurface enum (SDK-confirmed):
--   BaseWall=2, BaseFloor=4, BaseCeiling=8
-- Target value 14 = wall + floor + ceiling
--
-- We ALSO keep the force-true legality hooks because some flows may bypass
-- the ActionData check and use IsLegal directly.

local TARGET_MASK = 2 + 4 + 8  -- BaseWall | BaseFloor | BaseCeiling = 14

local function describeBrushKey(key)
    local ok, label = pcall(function() return key.EditorLabel end)
    if ok and label then
        local s = U.unwrap(label)
        if s and s.ToString then
            local ok2, str = pcall(function() return s:ToString() end)
            if ok2 then return str end
        end
    end
    return "<unnamed>"
end

-- Walk a single FSN2EditBrush and patch its InitialPiecePlacementParams.AllowedSurfaces.
-- Returns true if any modification was made.
local function patchBrush(brush, brushLabel)
    local ok, params = pcall(function() return brush.InitialPiecePlacementParams end)
    if not ok or params == nil then return false end

    local ok2, allowed = pcall(function() return params.AllowedSurfaces end)
    if not ok2 then return false end

    -- Only patch if current mask is restrictive (e.g. 2 = wall only) and doesn't
    -- already include floor or ceiling.
    if allowed == nil then return false end
    if (allowed >= TARGET_MASK) then return false end   -- already permissive

    local ok3 = pcall(function() params.AllowedSurfaces = TARGET_MASK end)
    if not ok3 then return false end

    print(string.format("[SeamlessGlass] patched brush '%s' AllowedSurfaces: %d -> %d",
        brushLabel or "?", allowed or -1, TARGET_MASK))
    return true
end

-- Walk all loaded USN2ItemBrushActionData and patch their brushes' AllowedSurfaces.
local function scanAndPatch()
    local actionDatas = FindAllOf("SN2ItemBrushActionData") or {}
    local total = 0
    local patched = 0
    for _, ad in ipairs(actionDatas) do
        local adName = U.fullName(ad) or "?"
        if not SurfaceUnlock._patched[adName] then
            SurfaceUnlock._patched[adName] = true
            total = total + 1

            local ok, editModes = pcall(function() return ad.EditModes end)
            if ok and editModes then
                local okNum, n = pcall(function() return editModes:Num() end)
                if okNum and n and n > 0 then
                    for i = 1, n do
                        local okMode, mode = pcall(function() return editModes[i] end)
                        if okMode and mode then
                            -- EditBrushes is a TMap; access requires TMap iteration.
                            -- UE4SS Lua exposes TMap with a ForEach method.
                            local okBrushes, brushes = pcall(function() return mode.EditBrushes end)
                            if okBrushes and brushes then
                                local okIter = pcall(function()
                                    brushes:ForEach(function(key, brush)
                                        if patchBrush(brush, describeBrushKey(key)) then
                                            patched = patched + 1
                                        end
                                    end)
                                end)
                                if not okIter then
                                    -- TMap iteration not supported via ForEach.
                                    -- Log once so we know to try a different approach.
                                    print("[SeamlessGlass] note: TMap ForEach not available on EditBrushes for " .. adName)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if total > 0 then
        print(string.format("[SeamlessGlass] scan: %d new ActionData(s), %d brush(es) patched",
            total, patched))
    end
end

-- Keep the force-true hooks too — they're harmless and may catch flows
-- the AllowedSurfaces patch misses.
local FORCE_TRUE_FUNCS = {
    "/Script/Subnautica2.SN2AbilityTask_UpdateBaseEdit:IsLegal",
    "/Script/Subnautica2.SN2AbilityTask_UpdateBaseEdit:CurrentBrushIsValid",
    "/Script/Subnautica2.SN2BuilderGhost:IsPlacementLegal",
}

local function forceTrueReturn(path)
    local ok = pcall(function()
        RegisterHook(path,
            function() end,
            function(_, ...)
                local args = { ... }
                local ret = args[#args]
                if ret then
                    pcall(function() ret:set(true) end)
                end
            end
        )
    end)
    if not ok then
        print("[SeamlessGlass] WARN: could not hook " .. path)
    end
end

function SurfaceUnlock.register()
    if SurfaceUnlock._registered then
        print("[SeamlessGlass] surface_unlock already registered, skipping")
        return
    end

    for _, path in ipairs(FORCE_TRUE_FUNCS) do
        forceTrueReturn(path)
    end

    -- Initial scan: ActionData assets may not all be loaded at first game-state
    -- init, so we run multiple times.
    scanAndPatch()
    pcall(function() ExecuteWithDelay(2000,  scanAndPatch) end)
    pcall(function() ExecuteWithDelay(10000, scanAndPatch) end)
    -- Periodic catch-up in case new ActionData loads later
    pcall(function() LoopAsync(15000, function() scanAndPatch(); return false end) end)

    SurfaceUnlock._registered = true
    print("[SeamlessGlass] surface unlock hooks registered (AllowedSurfaces patch + force-true)")
end

return SurfaceUnlock
