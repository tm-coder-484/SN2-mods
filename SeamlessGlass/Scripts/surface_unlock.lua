local Config = require("config")
local SurfaceUnlock = {}

-- Internal state shared between pre- and post-hooks on the same function call
SurfaceUnlock._pendingNormalZ = nil
SurfaceUnlock._pendingRemove  = nil

local function isWindowPiece(buildable)
    if not buildable then return false end
    local name = buildable:GetClass():GetFName():ToString()
    for _, cls in ipairs(Config.WINDOW_PIECE_CLASSES) do
        if name:find(cls, 1, true) then return true end
    end
    return false
end

function SurfaceUnlock.register()

    -- Override face-validity to accept horizontal surfaces for window pieces.
    -- The post-hook fires after the original check; we can force the return to true.
    -- UE4SS requires both pre- and post- hooks to be functions; we no-op the pre-hook.
    RegisterHook(Config.BUILDER_VALIDITY_FUNC,
        function() end,
        function(self, ReturnValue, Params)
            if not isWindowPiece(Params and Params.Buildable) then return end

            local hitResult = Params and Params.HitResult
            local normal = hitResult and hitResult.ImpactNormal
            if not normal then return end

            -- |Z| > cos(15°) ≈ 0.966 means the face is near-horizontal (floor or ceiling)
            if math.abs(normal.Z or 0) > 0.966 then
                ReturnValue.ReturnValue = true
            end
        end
    )

    -- On placement, capture the face normal so the post-hook can rotate the piece.
    RegisterHook(Config.BUILDER_PLACE_FUNC,
        function(self, Params)
            local hitResult = Params and Params.HitResult
            local normal = hitResult and hitResult.ImpactNormal
            if normal and math.abs(normal.Z or 0) > 0.966 then
                SurfaceUnlock._pendingNormalZ = normal.Z
            else
                SurfaceUnlock._pendingNormalZ = nil
            end
        end,
        function(self, ReturnValue, Params)
            if not SurfaceUnlock._pendingNormalZ then return end

            local placedActor = ReturnValue and ReturnValue.ReturnValue
            if not placedActor then return end

            if SurfaceUnlock._pendingNormalZ > 0 then
                -- Floor face (normal points up): rotate piece 180° so glass faces upward
                placedActor:SetActorRotation({ Pitch = 180, Yaw = 0, Roll = 0 })
            else
                -- Ceiling face (normal points down): default orientation, glass faces down
                placedActor:SetActorRotation({ Pitch = 0, Yaw = 0, Roll = 0 })
            end

            SurfaceUnlock._pendingNormalZ = nil
        end
    )

    print("[SeamlessGlass] surface unlock hooks registered")
end

return SurfaceUnlock
