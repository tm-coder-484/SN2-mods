local Config = require("config")
local U      = require("unreal_util")
local AdjacencyTracker = {}

-- neighbours[actorId] = { ref = actor, adjacent = { [neighbourId] = actor } }
local neighbours = {}

local function actorId(actor)
    actor = U.unwrap(actor)
    if not actor then return nil end
    return U.fullName(actor)
end

local function isWindowPiece(actor)
    actor = U.unwrap(actor)
    if not actor then return false end
    local name = U.className(actor)
    if not name then return false end
    for _, cls in ipairs(Config.WINDOW_PIECE_CLASSES) do
        if name:find(cls, 1, true) then return true end
    end
    return false
end

local function actorPos(actor)
    actor = U.unwrap(actor)
    if not actor then return nil end
    local ok, pos = pcall(function() return actor:K2_GetActorLocation() end)
    if ok and pos then
        local p = U.unwrap(pos)
        return {
            X = U.tonum(p.X, 0),
            Y = U.tonum(p.Y, 0),
            Z = U.tonum(p.Z, 0),
        }
    end
    return nil
end

-- Returns window actors from candidates that are within SNAP_DISTANCE.
local function findNearby(origin, candidateOverride)
    local candidates = candidateOverride or FindAllOf("Actor") or {}
    local origin_pos = actorPos(origin)
    if not origin_pos then return {} end
    local result = {}
    for _, candidate in ipairs(candidates) do
        local c = U.unwrap(candidate)
        if c and c ~= U.unwrap(origin) and isWindowPiece(c) then
            local cp = actorPos(c)
            if cp then
                local dx = cp.X - origin_pos.X
                local dy = cp.Y - origin_pos.Y
                local dz = cp.Z - origin_pos.Z
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                if dist <= Config.SNAP_DISTANCE then
                    table.insert(result, c)
                end
            end
        end
    end
    return result
end

function AdjacencyTracker.onPieceBuilt(actor, candidateOverride)
    local a = U.unwrap(actor)
    local id = actorId(a)
    if not id then return {} end
    neighbours[id] = { ref = a, adjacent = {} }

    local nearby = findNearby(a, candidateOverride)
    for _, neighbour in ipairs(nearby) do
        local nid = actorId(neighbour)
        if nid then
            neighbours[id].adjacent[nid] = neighbour
            if neighbours[nid] then
                neighbours[nid].adjacent[id] = a
            end
        end
    end

    return nearby
end

function AdjacencyTracker.onPieceDeconstructed(actor)
    local a = U.unwrap(actor)
    local id = actorId(a)
    if not id then return {} end
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
    if not id or not neighbours[id] then return {} end
    local result = {}
    for _, v in pairs(neighbours[id].adjacent) do
        table.insert(result, v)
    end
    return result
end

function AdjacencyTracker.hasNeighbour(actor)
    local id = actorId(actor)
    if not id or not neighbours[id] then return false end
    for _ in pairs(neighbours[id].adjacent) do return true end
    return false
end

function AdjacencyTracker._reset()
    neighbours = {}
end

return AdjacencyTracker
