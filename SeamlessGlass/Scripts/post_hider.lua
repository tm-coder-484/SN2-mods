local Config = require("config")
local PostHider = {}

-- Stores original materials per actor so showPosts can restore them.
-- originals[actorId][compName] = originalMaterialObject
local originals = {}

local function getPostComponents(actor)
    -- GetComponentsByClass accepts nil in both tests (mock ignores it) and
    -- in-game (UE4SS finds StaticMeshComponent class lazily).
    local cls = FindFirstOf("StaticMeshComponent")
    cls = cls and cls:GetClass() or nil
    local all = actor:GetComponentsByClass(cls)
    if type(all) ~= "table" then return {} end

    local posts = {}
    for _, comp in ipairs(all) do
        local name = comp:GetFName():ToString()
        if name:find(Config.POST_COMP_NAME_PATTERN, 1, true) then
            table.insert(posts, comp)
        end
    end
    return posts
end

function PostHider.hidePosts(actor)
    local id = actor:GetFullName()
    originals[id] = originals[id] or {}

    local mat = StaticFindObject(Config.TRANSPARENT_MAT_PATH)
    if not mat then
        print("[SeamlessGlass] WARNING: transparent material not found at " .. Config.TRANSPARENT_MAT_PATH)
        return
    end

    for _, comp in ipairs(getPostComponents(actor)) do
        local name = comp:GetFName():ToString()
        if not originals[id][name] then
            originals[id][name] = comp:GetMaterial(0)
        end
        comp:SetMaterial(0, mat)
    end
end

function PostHider.showPosts(actor)
    local id = actor:GetFullName()
    if not originals[id] then return end

    for _, comp in ipairs(getPostComponents(actor)) do
        local name = comp:GetFName():ToString()
        local orig = originals[id][name]
        if orig then
            comp:SetMaterial(0, orig)
        end
    end
end

-- Hide posts if the piece has any neighbour; restore them if isolated.
function PostHider.reevaluate(actor, hasAnyNeighbour)
    if hasAnyNeighbour then
        PostHider.hidePosts(actor)
    else
        PostHider.showPosts(actor)
    end
end

return PostHider
