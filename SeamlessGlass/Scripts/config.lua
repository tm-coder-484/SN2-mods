local Config = {}

-- Replace each string value with what you find in the UE4SS SDK dump.
-- The examples shown use plausible names based on SN1's class conventions.

-- Full UFunction path for the builder's face-validity check
Config.BUILDER_VALIDITY_FUNC = "/Script/Subnautica2.BuilderComponent:IsValidBuildSurface"

-- Full UFunction path for piece placement
Config.BUILDER_PLACE_FUNC = "/Script/Subnautica2.BuilderComponent:PlacePiece"

-- Full UFunction path for piece removal/deconstruction
Config.BUILDER_REMOVE_FUNC = "/Script/Subnautica2.BuilderComponent:RemovePiece"

-- Class names of all buildable window pieces (as returned by GetFName():ToString())
Config.WINDOW_PIECE_CLASSES = {
    "BP_Window_C",
    "BP_WindowLarge_C",
}

-- Substring present in all structural post mesh component FNames
Config.POST_COMP_NAME_PATTERN = "PostMesh"

-- Asset path of the transparent material created in the pak step
Config.TRANSPARENT_MAT_PATH = "/Game/SeamlessGlass/Materials/M_Invisible"

-- Neighbour detection radius in UE units (cm).
-- Must be >= the diagonal size of one window piece. Tune if detection misses or false-positives.
Config.SNAP_DISTANCE = 220.0

return Config
