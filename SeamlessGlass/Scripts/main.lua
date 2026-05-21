local Config        = require("config")
local U             = require("unreal_util")
local Tracker       = require("adjacency_tracker")
local PostHider     = require("post_hider")
local SurfaceUnlock = require("surface_unlock")

local initialised = false
local placeHookCount  = 0
local removeHookCount = 0

local function diagLog(label, ...)
    if placeHookCount >= 5 and removeHookCount >= 5 then return end
    local args = { ... }
    local parts = { "[SeamlessGlass.main.diag] " .. label .. " argc=" .. #args }
    for i, v in ipairs(args) do
        table.insert(parts, "  [" .. i .. "] " .. U.describe(v))
    end
    print(table.concat(parts, "\n"))
end

RegisterInitGameStatePostHook(function()
    if initialised then
        print("[SeamlessGlass] already initialised, skipping duplicate init")
        return
    end
    initialised = true

    print("[SeamlessGlass] initialising...")

    SurfaceUnlock.register()

    -- After a piece is placed: track adjacency and hide posts on this + neighbours
    pcall(function()
        RegisterHook(Config.BUILDER_PLACE_FUNC,
            function() end,
            function(...)
                placeHookCount = placeHookCount + 1
                if placeHookCount <= 5 then diagLog("PLACE_POST_MAIN", ...) end

                local args = { ... }
                local placed = nil
                -- Search args for a UObject-ish value that looks like an actor
                for i = #args, 1, -1 do
                    local v = U.unwrap(args[i])
                    if v and U.fullName(v) then
                        placed = v
                        break
                    end
                end
                if not placed then return end

                local ok, newNeighbours = pcall(Tracker.onPieceBuilt, placed, nil)
                if not ok then return end
                pcall(function()
                    PostHider.reevaluate(placed, Tracker.hasNeighbour(placed))
                    for _, neighbour in ipairs(newNeighbours or {}) do
                        PostHider.reevaluate(neighbour, Tracker.hasNeighbour(neighbour))
                    end
                end)
            end
        )
    end)

    -- Before a piece is removed: capture it for the post-hook
    pcall(function()
        RegisterHook(Config.BUILDER_REMOVE_FUNC,
            function(...)
                removeHookCount = removeHookCount + 1
                if removeHookCount <= 5 then diagLog("REMOVE_PRE", ...) end
                local args = { ... }
                -- The piece being deconstructed is usually one of the first args
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
