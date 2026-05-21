local Config = require("config")
local U      = require("unreal_util")
local SurfaceUnlock = {}

SurfaceUnlock._pendingRemove  = nil
SurfaceUnlock._registered     = false

-- IMPORTANT: this module no longer does speculative field probing on
-- SN2ItemBrushActionData. That approach caused native game crashes that
-- pcall could not catch. Instead, we use the proven StackAll pattern:
-- hook the validity-determining UFunctions and force their return to true.
--
-- Confirmed via SDK dump (UHT headers, SN2 build CL-113109):
--   USN2AbilityTask_UpdateBaseEdit:IsLegal()           -> bool
--   USN2AbilityTask_UpdateBaseEdit:CurrentBrushIsValid()-> bool
--   ASN2BuilderGhost:IsPlacementLegal(FSN2GhostPlacement) -> bool
--
-- These together gate whether the player can place a piece on the current
-- surface. Forcing them all to true lets the player place buildables on
-- floors and ceilings.
--
-- NOTE: this is broad — it lets ALL buildables, not just windows, be placed
-- anywhere. Narrowing to just windows requires reading ActionData.EditModes
-- safely, which we'll add once the FSN2EditMode/FSN2EditBrush field-access
-- pattern is verified in a controlled probe.

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
                -- The return value is always the last varargs entry for a
                -- bool-returning UFunction. Setting it overrides the caller's view.
                local args = { ... }
                local ret = args[#args]
                if ret then
                    pcall(function() ret:set(true) end)
                end
            end
        )
        print("[SeamlessGlass] forced true: " .. path)
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

    SurfaceUnlock._registered = true
    print("[SeamlessGlass] surface unlock hooks registered (force-true mode)")
end

return SurfaceUnlock
