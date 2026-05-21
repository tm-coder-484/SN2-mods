# Codex Handoff Prompt 4 — Decode SN2ItemBrushActionData and Find Real Validity Function

Paste the block below into Codex.

---

```
The SeamlessGlass mod is now stable and diagnostics are firing, but floor/ceiling placement still fails. The previous test showed three critical things:

1. PLACE_PRE hook fires with 3 args:
     [1] userdata(GA_BaseEdit_C)         -- the ability instance
     [2] userdata(SN2ItemBrushActionData) -- the placement payload (THE KEY)
     [3] userdata                         -- return value slot

2. VALIDITY hook (on SN2BuilderAbility:HasValidConstructTarget) NEVER fires.
   This means SN2 does NOT use that function to gate floor/ceiling placement.

3. PLACE_POST also doesn't fire, suggesting TryApply early-returns when the action data is invalid.

WE NEED TWO PIECES OF INFORMATION:
A) The full field layout of SN2ItemBrushActionData (so we can find/modify the validity-determining field)
B) The real function SN2 uses to reject floor/ceiling placement (it's not HasValidConstructTarget)

WORKING DIRECTORY: D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64

STEPS

=== PHASE 1: Dump the SDK and find SN2ItemBrushActionData ===

1. Have the user launch SN2, load a save, and in the UE4SS GUI console run:
   dump_uht_compatible_headers

   Wait for completion. The output lands in ue4ss\UHTHeaderDump or similar.

2. After the dump completes, the user can close SN2. Then find the header file containing SN2ItemBrushActionData:
   $dump = "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\UHTHeaderDump"
   if (-not (Test-Path $dump)) { $dump = "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\CXXHeaderDump" }
   Get-ChildItem -Recurse $dump | Select-String -Pattern "SN2ItemBrushActionData" -List | Select Path

3. Show me the FULL definition of SN2ItemBrushActionData from that header. Just the struct/class body — typically 20-50 lines listing all UPROPERTY fields. Look for fields containing words like:
   - Hit, Normal, Impact, Surface, Face
   - Valid, Can, IsAllowed, IsBlocked
   - Buildable, Piece, Ghost, Target
   - Location, Position, Rotation, Transform

4. Also search for any class/struct whose name contains "Brush", "Builder", "BaseEdit", or "Construct" and show me their function signatures (just the public methods, not bodies):
   Get-ChildItem -Recurse $dump | Select-String -Pattern "(class|struct)\s+[FUSA]?[A-Za-z0-9_]*(?:Brush|Builder|BaseEdit|Construct)[A-Za-z0-9_]*" -List | Select Path

   For each matched file, show me the function declarations inside the class. We're looking for candidates like:
     IsValidPlacement, CanConstruct, GetSnappedTransform, EvaluateGhost, CheckConstraints, etc.

=== PHASE 2: Live probe to enumerate SN2ItemBrushActionData fields ===

5. While the user has SN2 closed, create a probe mod at ue4ss\Mods\BrushDataProbe\:

   File: ue4ss\Mods\BrushDataProbe\enabled.txt (empty)

   File: ue4ss\Mods\BrushDataProbe\Scripts\main.lua:

   local OUT = "ue4ss\\Mods\\BrushDataProbe\\probe.txt"

   local function append(s)
       local f = io.open(OUT, "a")
       if f then f:write(s .. "\n"); f:close() end
   end

   append("=== BrushDataProbe started " .. os.date() .. " ===")

   local printed = false

   RegisterHook("/Game/Blueprints/AbilitySystem/Abilities/Tools/Builder/BuilderActions/PlaceGhost/GA_BaseEdit.GA_BaseEdit_C:TryApply",
       function(Context, ActionData, RetSlot)
           if printed then return end
           printed = true

           append("--- TryApply PRE first fire ---")
           local ad = ActionData
           if type(ad) == "userdata" then
               local ok, inner = pcall(function() return ad:get() end)
               if ok and inner then ad = inner end
           end
           append("ActionData type after unwrap: " .. type(ad))

           -- Try to enumerate fields by iterating common UE field names
           local fieldNames = {
               "HitResult", "Hit", "HitNormal", "ImpactNormal", "Normal",
               "ImpactPoint", "Location", "HitLocation",
               "TargetActor", "TargetComponent", "TargetSurface",
               "Buildable", "BuildableClass", "Ghost", "GhostActor",
               "Piece", "PieceClass", "ItemClass", "Item",
               "Transform", "Rotation", "SnapRotation",
               "IsValid", "bIsValid", "bCanPlace", "bAllowed", "bIsBlocked",
               "ConstructTarget", "Target",
               "PlacementMode", "BuildMode",
               "Player", "Instigator", "Owner",
           }

           for _, name in ipairs(fieldNames) do
               local ok, val = pcall(function() return ad[name] end)
               if ok and val ~= nil then
                   local repr
                   if type(val) == "userdata" then
                       local ok2, inner = pcall(function() return val:get() end)
                       if ok2 and inner then
                           local ok3, cls = pcall(function() return inner:GetClass():GetFName():ToString() end)
                           repr = "userdata(" .. (ok3 and cls or "?") .. ")"
                       else
                           repr = "userdata(opaque)"
                       end
                   elseif type(val) == "table" then
                       local keys = {}
                       for k, _ in pairs(val) do table.insert(keys, tostring(k)) end
                       repr = "table{" .. table.concat(keys, ",") .. "}"
                   else
                       repr = type(val) .. "(" .. tostring(val) .. ")"
                   end
                   append("FIELD " .. name .. " = " .. repr)
               end
           end

           -- Also iterate over the userdata via UE reflection if available
           local okIter, _ = pcall(function()
               for k, v in pairs(ad) do
                   append("ITER " .. tostring(k) .. " = " .. type(v))
               end
           end)
           if not okIter then
               append("pairs() iteration not supported on ActionData")
           end

           append("--- end of first fire dump ---")
       end,
       function() end
   )

   print("[BrushDataProbe] loaded")

6. Add "BrushDataProbe : 1" to ue4ss\Mods\mods.txt (after Mariana).

7. Have the user launch SN2, load a save, and attempt ONE window placement (anywhere — wall is fine; we just need TryApply to fire once).

8. The user closes SN2. Read ue4ss\Mods\BrushDataProbe\probe.txt and show me its full contents.

=== PHASE 3: Hook search ===

9. With the SDK dump still available, search for functions whose names suggest placement validation that might be called BEFORE TryApply:
   Get-ChildItem -Recurse $dump | Select-String -Pattern "(CanPlace|CanConstruct|IsValid.*Placement|CheckConstraint|EvaluateGhost|IsValidGhost|GetSnap|SnapTo|AllowPlace)" | Select Path, Line | Format-Table -Wrap -AutoSize

   Show me the matches.

=== STOP AND REPORT ===

10. Stop after Phase 3 and send me ALL of:
    - The SN2ItemBrushActionData struct definition (from Phase 1)
    - The list of *Brush*/*Builder*/*BaseEdit*/*Construct* classes and their method signatures (Phase 1)
    - The BrushDataProbe probe.txt output (Phase 2)
    - The Phase 3 search matches

    DO NOT patch SeamlessGlass yet. Once I see the field layout, I will write a targeted patch (likely overriding a specific field in the PRE hook, or hooking a different function entirely).

CONSTRAINTS
- Do not modify SeamlessGlass at all this round
- If the user reports a crash during the SDK dump or the placement test, capture the last 200 lines of UE4SS.log and stop
- If the SDK dump fails to produce headers, try the fallback dump_sdk command and report what folder it creates

Start by running the dump (Phase 1) and showing me the SN2ItemBrushActionData definition.
```
