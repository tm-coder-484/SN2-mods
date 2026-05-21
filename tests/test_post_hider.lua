dofile("tests/mock_ue4ss.lua")

package.preload["config"] = function()
    return {
        POST_COMP_NAME_PATTERN = "PostMesh",
        TRANSPARENT_MAT_PATH = "/Game/SeamlessGlass/Materials/M_Invisible",
    }
end

local swapLog = {}

local function makeComp(name)
    local self = {
        _name = name,
        _material = "mat_original",
    }
    self.GetFName = function() return { ToString = function() return self._name end } end
    self.GetMaterial = function(_, slot) return self._material end
    self.SetMaterial = function(_, slot, mat)
        table.insert(swapLog, { comp = self._name, mat = mat })
        self._material = mat
    end
    return self
end

local function makeActor(id, compNames)
    local comps = {}
    for _, name in ipairs(compNames) do
        table.insert(comps, makeComp(name))
    end
    return {
        GetFullName = function() return id end,
        GetComponentsByClass = function(_, cls) return comps end,
    }
end

-- Return a fake transparent material when StaticFindObject is called
StaticFindObject = function(path) return { _path = path } end

local PostHider = dofile("SeamlessGlass/Scripts/post_hider.lua")

test("hidePosts swaps material on all PostMesh components", function()
    swapLog = {}
    local a = makeActor("a", { "PostMesh_Left", "PostMesh_Right", "GlassMesh" })
    PostHider.hidePosts(a)
    assertEqual(#swapLog, 2, "only PostMesh components swapped")
    assertEqual(swapLog[1].mat._path, "/Game/SeamlessGlass/Materials/M_Invisible")
end)

test("hidePosts ignores components not matching the pattern", function()
    swapLog = {}
    local a = makeActor("a", { "GlassMesh", "FrameDecor" })
    PostHider.hidePosts(a)
    assertEqual(#swapLog, 0, "no PostMesh components — nothing swapped")
end)

test("showPosts restores the original material", function()
    swapLog = {}
    local a = makeActor("a", { "PostMesh_Left" })
    PostHider.hidePosts(a)   -- records original, swaps to transparent
    swapLog = {}
    PostHider.showPosts(a)   -- should swap back
    assertEqual(#swapLog, 1)
    assertEqual(swapLog[1].mat, "mat_original")
end)

test("reevaluate hides posts when hasNeighbour=true", function()
    swapLog = {}
    local a = makeActor("a", { "PostMesh_Left" })
    PostHider.reevaluate(a, true)
    assertEqual(#swapLog, 1)
    assertEqual(swapLog[1].mat._path, "/Game/SeamlessGlass/Materials/M_Invisible")
end)

test("reevaluate shows posts when hasNeighbour=false", function()
    swapLog = {}
    local a = makeActor("a", { "PostMesh_Left" })
    PostHider.hidePosts(a)   -- hide first so originals are recorded
    swapLog = {}
    PostHider.reevaluate(a, false)
    assertEqual(#swapLog, 1)
    assertEqual(swapLog[1].mat, "mat_original")
end)
