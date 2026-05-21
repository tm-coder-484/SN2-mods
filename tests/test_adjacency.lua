dofile("tests/mock_ue4ss.lua")

-- Provide a fake config so require("config") resolves without the game
package.preload["config"] = function()
    return {
        WINDOW_PIECE_CLASSES = { "BP_Window_C" },
        SNAP_DISTANCE = 220.0,
    }
end

local function makeActor(id, x, y, z, className)
    className = className or "BP_Window_C"
    return {
        GetFullName = function() return id end,
        GetActorLocation = function() return { X = x, Y = y, Z = z } end,
        GetClass = function()
            return { GetFName = function()
                return { ToString = function() return className end }
            end }
        end,
    }
end

local Tracker = dofile("SeamlessGlass/Scripts/adjacency_tracker.lua")

test("onPieceBuilt returns empty list when no candidates", function()
    Tracker._reset()
    local a = makeActor("actor_a", 0, 0, 0)
    local result = Tracker.onPieceBuilt(a, {})
    assertEqual(#result, 0)
end)

test("onPieceBuilt links two nearby actors bidirectionally", function()
    Tracker._reset()
    local a = makeActor("actor_a", 0, 0, 0)
    local b = makeActor("actor_b", 200, 0, 0)
    Tracker.onPieceBuilt(a, {})
    local result = Tracker.onPieceBuilt(b, { a })
    assertEqual(#result, 1, "b finds a as neighbour")
    local aNeighbours = Tracker.getNeighbours(a)
    assertEqual(#aNeighbours, 1, "a is also updated")
    assertEqual(aNeighbours[1]:GetFullName(), "actor_b")
end)

test("onPieceBuilt ignores actors beyond SNAP_DISTANCE", function()
    Tracker._reset()
    local a = makeActor("actor_a", 0, 0, 0)
    local b = makeActor("actor_b", 500, 0, 0)
    Tracker.onPieceBuilt(a, {})
    local result = Tracker.onPieceBuilt(b, { a })
    assertEqual(#result, 0, "too far away")
end)

test("onPieceBuilt ignores non-window actors", function()
    Tracker._reset()
    local a = makeActor("actor_a", 0, 0, 0)
    local wall = makeActor("actor_wall", 200, 0, 0, "BP_WallPanel_C")
    Tracker.onPieceBuilt(a, {})
    local result = Tracker.onPieceBuilt(wall, { a })
    assertEqual(#result, 0, "wall is not a window piece")
end)

test("onPieceDeconstructed removes piece and updates neighbours", function()
    Tracker._reset()
    local a = makeActor("actor_a", 0, 0, 0)
    local b = makeActor("actor_b", 200, 0, 0)
    Tracker.onPieceBuilt(a, {})
    Tracker.onPieceBuilt(b, { a })
    local former = Tracker.onPieceDeconstructed(b)
    assertEqual(#former, 1)
    assertEqual(former[1]:GetFullName(), "actor_a")
    assertEqual(#Tracker.getNeighbours(a), 0, "a no longer lists b")
end)

test("hasNeighbour returns false for isolated piece", function()
    Tracker._reset()
    local a = makeActor("actor_a", 0, 0, 0)
    Tracker.onPieceBuilt(a, {})
    assertEqual(Tracker.hasNeighbour(a), false)
end)

test("hasNeighbour returns true after link is formed", function()
    Tracker._reset()
    local a = makeActor("actor_a", 0, 0, 0)
    local b = makeActor("actor_b", 200, 0, 0)
    Tracker.onPieceBuilt(a, {})
    Tracker.onPieceBuilt(b, { a })
    assertEqual(Tracker.hasNeighbour(a), true)
    assertEqual(Tracker.hasNeighbour(b), true)
end)
