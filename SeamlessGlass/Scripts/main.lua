local Config        = require("config")
local Tracker       = require("adjacency_tracker")
local PostHider     = require("post_hider")
local SurfaceUnlock = require("surface_unlock")

RegisterInitGameStatePostHook(function()
    print("[SeamlessGlass] initialising...")

    SurfaceUnlock.register()

    -- After a piece is placed: track it and hide posts on it + its new neighbours
    RegisterHook(Config.BUILDER_PLACE_FUNC,
        nil,
        function(self, ReturnValue, Params)
            local placed = ReturnValue and ReturnValue.ReturnValue
            if not placed then return end

            local newNeighbours = Tracker.onPieceBuilt(placed, nil)

            PostHider.reevaluate(placed, Tracker.hasNeighbour(placed))
            for _, neighbour in ipairs(newNeighbours) do
                PostHider.reevaluate(neighbour, Tracker.hasNeighbour(neighbour))
            end
        end
    )

    -- Before a piece is removed: capture it so the post-hook can re-evaluate neighbours
    RegisterHook(Config.BUILDER_REMOVE_FUNC,
        function(self, Params)
            SurfaceUnlock._pendingRemove = Params and Params.Piece
        end,
        function(self, ReturnValue, Params)
            local removed = SurfaceUnlock._pendingRemove
            SurfaceUnlock._pendingRemove = nil
            if not removed then return end

            local formerNeighbours = Tracker.onPieceDeconstructed(removed)
            for _, neighbour in ipairs(formerNeighbours) do
                PostHider.reevaluate(neighbour, Tracker.hasNeighbour(neighbour))
            end
        end
    )

    print("[SeamlessGlass] ready.")
end)
