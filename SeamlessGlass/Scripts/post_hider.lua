local Config = require("config")
local U      = require("unreal_util")
local PostHider = {}

-- Stores original materials per actor so showPosts can restore them.
-- originals[actorId][compName] = originalMaterialObject
local originals = {}

local function getPostComponents(actor)
    actor = U.unwrap(actor)
    if not actor then return {} end
    local cls = FindFirstOf("StaticMeshComponent")
    cls = cls and cls:GetClass() or nil
    local ok, all = pcall(function() return actor:GetComponentsByClass(cls) end)
    if not ok or type(all) ~= "table" then return {} end

    local posts = {}
    for _, comp in ipairs(all) do
        local c = U.unwrap(comp)
        if c then
            local fname = U.safeCall(c, "GetFName")
            fname = U.unwrap(fname)
            local name = fname and U.safeCall(fname, "ToString")
            if name and name:find(Config.POST_COMP_NAME_PATTERN, 1, true) then
                table.insert(posts, c)
            end
        end
    end
    return posts
end

function PostHider.hidePosts(actor)
    actor = U.unwrap(actor)
    if not actor then return end
    local id = U.fullName(actor)
    if not id then return end
    originals[id] = originals[id] or {}

    local mat = StaticFindObject(Config.TRANSPARENT_MAT_PATH)
    if not mat then
        print("[SeamlessGlass] WARNING: transparent material not found at " .. Config.TRANSPARENT_MAT_PATH)
        return
    end

    for _, comp in ipairs(getPostComponents(actor)) do
        local fname = U.safeCall(comp, "GetFName")
        local name = fname and U.safeCall(U.unwrap(fname), "ToString")
        if name then
            if not originals[id][name] then
                local cur = U.safeCall(comp, "GetMaterial", 0)
                originals[id][name] = U.unwrap(cur)
            end
            pcall(function() comp:SetMaterial(0, mat) end)
        end
    end
end

function PostHider.showPosts(actor)
    actor = U.unwrap(actor)
    if not actor then return end
    local id = U.fullName(actor)
    if not id or not originals[id] then return end

    for _, comp in ipairs(getPostComponents(actor)) do
        local fname = U.safeCall(comp, "GetFName")
        local name = fname and U.safeCall(U.unwrap(fname), "ToString")
        if name then
            local orig = originals[id][name]
            if orig then
                pcall(function() comp:SetMaterial(0, orig) end)
            end
        end
    end
end

function PostHider.reevaluate(actor, hasAnyNeighbour)
    if hasAnyNeighbour then
        PostHider.hidePosts(actor)
    else
        PostHider.showPosts(actor)
    end
end

return PostHider
