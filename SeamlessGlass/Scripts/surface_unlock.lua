local SurfaceUnlock = {}

SurfaceUnlock._pendingRemove = nil
SurfaceUnlock._registered    = false

-- The previous crash was caused by a SEPARATE diagnostic mod (BrushDataProbe)
-- auto-loading via a leftover enabled.txt file. This module did NOT crash
-- on its own — its hooks register cleanly and TryApply was observed to fire
-- through them. Confirmed safe to re-enable.
--
-- Approach: hook the three SDK-confirmed legality UFunctions and force their
-- return values to true. This is the StackAll-proven pattern.
--
-- Confirmed via SDK dump (UHT headers, SN2 build CL-113109):
--   USN2AbilityTask_UpdateBaseEdit:IsLegal           -> bool
--   USN2AbilityTask_UpdateBaseEdit:CurrentBrushIsValid -> bool
--   ASN2BuilderGhost:IsPlacementLegal                -> bool
--
-- CAVEAT: this is broad — it lets ALL buildables on ALL surfaces, not just
-- windows. If this works for floor/ceiling windows, the next iteration will
-- narrow the filter using a confirmed-safe field read on FSN2EditBrush.

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
