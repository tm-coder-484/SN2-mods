local Config = {}

-- Function paths verified against Subnautica 2 Early Access build CL-113109 (May 2026)
-- via a runtime UFunction probe. SN2 uses the Gameplay Ability System, not a simple
-- BuilderComponent — placement is a Blueprint ability (GA_BaseEdit) and removal is
-- a server RPC on SN2BaseEditAbility.
--
-- If a game update breaks these paths, build a probe mod that enumerates loaded
-- UFunctions and search for "Build", "Construct", "BaseEdit", or "Place" candidates.

-- Face-validity check on the builder ability
Config.BUILDER_VALIDITY_FUNC = "/Script/Subnautica2.SN2BuilderAbility:HasValidConstructTarget"

-- Blueprint ability that actually applies / spawns the placed piece
Config.BUILDER_PLACE_FUNC = "/Game/Blueprints/AbilitySystem/Abilities/Tools/Builder/BuilderActions/PlaceGhost/GA_BaseEdit.GA_BaseEdit_C:TryApply"

-- Server-side deconstruction RPC
Config.BUILDER_REMOVE_FUNC = "/Script/Subnautica2.SN2BaseEditAbility:ServerDeconstructActor"

-- Class names of all buildable window pieces (as returned by GetFName():ToString()).
-- These are placeholders until verified against the live game; check the probe output
-- for actors whose class name contains "Window" once a window piece is in the world.
Config.WINDOW_PIECE_CLASSES = {
    "BP_Window_C",
    "BP_WindowLarge_C",
}

-- Substring present in all structural post mesh component FNames.
-- Verify in-game via DumpComponents on a placed window actor.
Config.POST_COMP_NAME_PATTERN = "PostMesh"

-- Asset path of the transparent material created in the pak step
Config.TRANSPARENT_MAT_PATH = "/Game/SeamlessGlass/Materials/M_Invisible"

-- Neighbour detection radius in UE units (cm).
-- Must be >= the diagonal size of one window piece. Tune if detection misses or false-positives.
Config.SNAP_DISTANCE = 220.0

return Config
