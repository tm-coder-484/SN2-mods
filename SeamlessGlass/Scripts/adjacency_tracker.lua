local Config = require("config")
local AdjacencyTracker = {}

-- neighbours[actorId] = { ref = actor, adjacent = { [neighbourId] = actor } }
local neighbours = {}

local function actorId(actor)
    return actor:GetFullName()
end

local function isWindowPiece(actor)
    local name = actor:GetClass():GetFName():ToString()
    for _, cls in ipairs(Config.WINDOW_PIECE_CLASSES) do
        if name:find(cls, 1, true) then return true end
    end
    return false
end

-- Returns window actors from candidates that are within SNAP_DISTANCE.
-- candidateOverride: list of actors (used in unit tests to bypass FindAllOf).
-- In-game, pass nil to auto-discover via FindAllOf.
local function findNearby(origin, candidateOverride)
    local candidates = candidateOverride or FindAllOf("Actor") or {}
    local origin_pos = origin:GetActorLocation()
    local result = {}
    for _, candidate in ipairs(candidates) do
        if candidate ~= origin and isWindowPiece(candidate) then
            local cp = candidate:GetActorLocation()
            local dx = cp.X - origin_pos.X
            local dy = cp.Y - origin_pos.Y
            local dz = cp.Z - origin_pos.Z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            if dist <= Config.SNAP_DISTANCE then
                table.insert(result, candidate)
            end
        end
    end
    return result
end

-- Register a newly placed piece. Returns list of discovered neighbours.
-- candidateOverride: optional actor list for unit tests.
function AdjacencyTracker.onPieceBuilt(actor, candidateOverride)
    local id = actorId(actor)
    neighbours[id] = { ref = actor, adjacent = {} }

    local nearby = findNearby(actor, candidateOverride)
    for _, neighbour in ipairs(nearby) do
        local nid = actorId(neighbour)
        neighbours[id].adjacent[nid] = neighbour
        if neighbours[nid] then
            neighbours[nid].adjacent[id] = actor
        end
    end

    return nearby
end

-- Unregister a deconstructed piece. Returns its former neighbours.
function AdjacencyTracker.onPieceDeconstructed(actor)
    local id = actorId(actor)
    local former = {}
    if neighbours[id] then
        for nid, nactor in pairs(neighbours[id].adjacent) do
            table.insert(former, nactor)
            if neighbours[nid] then
                neighbours[nid].adjacent[id] = nil
            end
        end
        neighbours[id] = nil
    end
    return former
end

function AdjacencyTracker.getNeighbours(actor)
    local id = actorId(actor)
    if not neighbours[id] then return {} end
    local result = {}
    for _, v in pairs(neighbours[id].adjacent) do
        table.insert(result, v)
    end
    return result
end

function AdjacencyTracker.hasNeighbour(actor)
    local id = actorId(actor)
    if not neighbours[id] then return false end
    for _ in pairs(neighbours[id].adjacent) do return true end
    return false
end

-- Test helper only — wipes all state between test cases
function AdjacencyTracker._reset()
    neighbours = {}
end

return AdjacencyTracker
