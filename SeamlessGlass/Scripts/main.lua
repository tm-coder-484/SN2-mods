local Config        = require("config")
local U             = require("unreal_util")
local Tracker       = require("adjacency_tracker")
local PostHider     = require("post_hider")
local SurfaceUnlock = require("surface_unlock")

local initialised = false
local placeHookCount  = 0
local removeHookCount = 0
local spawnCount      = 0

local function diagLog(label, ...)
    if placeHookCount >= 5 and removeHookCount >= 5 and spawnCount >= 5 then return end
    local args = { ... }
    local parts = { "[SeamlessGlass.main.diag] " .. label .. " argc=" .. #args }
    for i, v in ipairs(args) do
        table.insert(parts, "  [" .. i .. "] " .. U.describe(v))
    end
    print(table.concat(parts, "\n"))
end

-- Process a freshly-detected placed window: update adjacency, then re-evaluate posts
local function processPlacement(actor)
    local placed = U.unwrap(actor)
    if not placed or not U.fullName(placed) then return end

    local ok, newNeighbours = pcall(Tracker.onPieceBuilt, placed, nil)
    if not ok then return end

    pcall(function()
        PostHider.reevaluate(placed, Tracker.hasNeighbour(placed))
        for _, neighbour in ipairs(newNeighbours or {}) do
            PostHider.reevaluate(neighbour, Tracker.hasNeighbour(neighbour))
        end
    end)
end

RegisterInitGameStatePostHook(function()
    if initialised then
        print("[SeamlessGlass] already initialised, skipping duplicate init")
        return
    end
    initialised = true

    print("[SeamlessGlass] initialising...")

    SurfaceUnlock.register()

    -- Primary placement detection: hook the placement function's POST callback.
    -- This may not fire if SN2's TryApply early-returns internally.
    pcall(function()
        RegisterHook(Config.BUILDER_PLACE_FUNC,
            function() end,
            function(...)
                placeHookCount = placeHookCount + 1
                if placeHookCount <= 5 then diagLog("PLACE_POST_MAIN", ...) end

                local args = { ... }
                -- Search args (back to front; placed actor is usually a return value or late param)
                for i = #args, 1, -1 do
                    local v = U.unwrap(args[i])
                    if v and U.fullName(v) then
                        processPlacement(v)
                        return
                    end
                end
            end
        )
    end)

    -- Fallback placement detection: NotifyOnNewObject on each window class path.
    -- This catches placements even when the POST hook doesn't fire, because
    -- it triggers on actor spawn at the engine level.
    --
    -- WINDOW_PIECE_CLASSES in config currently holds short class names; for
    -- NotifyOnNewObject we need the full Blueprint path. We try both:
    -- 1. Short name as-is (works for native Script classes)
    -- 2. The /Game/.../BP_Foo_C convention for Blueprint actors
    for _, cls in ipairs(Config.WINDOW_PIECE_CLASSES) do
        local candidates = {
            cls,
            "/Script/Subnautica2." .. cls,
            "/Game/Blueprints/Buildables/" .. cls .. "." .. cls,
        }
        for _, path in ipairs(candidates) do
            pcall(function()
                NotifyOnNewObject(path, function(actor)
                    spawnCount = spawnCount + 1
                    if spawnCount <= 5 then
                        diagLog("SPAWN(" .. cls .. ")", actor)
                    end
                    processPlacement(actor)
                end)
            end)
        end
    end

    -- Deconstruction: capture the piece in PRE, re-evaluate former neighbours in POST
    pcall(function()
        RegisterHook(Config.BUILDER_REMOVE_FUNC,
            function(...)
                removeHookCount = removeHookCount + 1
                if removeHookCount <= 5 then diagLog("REMOVE_PRE", ...) end
                local args = { ... }
                for i = 1, #args do
                    local v = U.unwrap(args[i])
                    if v and U.fullName(v) then
                        SurfaceUnlock._pendingRemove = v
                        return
                    end
                end
            end,
            function(...)
                local removed = SurfaceUnlock._pendingRemove
                SurfaceUnlock._pendingRemove = nil
                if not removed then return end

                local ok, formerNeighbours = pcall(Tracker.onPieceDeconstructed, removed)
                if not ok then return end
                for _, neighbour in ipairs(formerNeighbours or {}) do
                    pcall(function()
                        PostHider.reevaluate(neighbour, Tracker.hasNeighbour(neighbour))
                    end)
                end
            end
        )
    end)

    print("[SeamlessGlass] ready.")
end)
