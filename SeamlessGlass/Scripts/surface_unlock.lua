local SurfaceUnlock = {}

-- SAFE MODE (no-op): a previous attempt to force-true the SN2 legality
-- UFunctions caused native crashes (the hook signature or state machine
-- interaction is not yet understood). Until we have a confirmed-safe
-- approach, this module does NOT hook any game functions.
--
-- The mod is otherwise inert. SeamlessGlass can stay enabled in mods.txt
-- without causing crashes. Placement, adjacency, and post-hiding all fall
-- back to no-op until the next diagnostic round.
--
-- This field is referenced by main.lua but never set in safe mode.
SurfaceUnlock._pendingRemove = nil

function SurfaceUnlock.register()
    print("[SeamlessGlass] surface unlock disabled (safe-mode after crash investigation)")
end

return SurfaceUnlock
