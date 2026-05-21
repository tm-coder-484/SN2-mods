# Codex Handoff Prompt 7 — AllowedSurfaces Bitmask Patch

The clean v6 test showed the force-true legality hooks are STABLE but INSUFFICIENT. The placement rejection happens upstream of `IsLegal` — the ghost preview never even shows on floor/ceiling surfaces. So the legality bypass alone can't unlock placement.

The real gate is `FSN2PlacementParams.AllowedSurfaces` — an `int32` bitmask on each brush's placement params. Window brushes have it set to `2` (BaseWall only). We need to flip it to `14` (BaseWall | BaseFloor | BaseCeiling).

The new SeamlessGlass version (commit fe0075a) walks the SDK-confirmed structure:

  USN2ItemBrushActionData.EditModes : TArray<FSN2EditMode>
    FSN2EditMode.EditBrushes : TMap<FSN2EditBrushKey, FSN2EditBrush>
      FSN2EditBrush.InitialPiecePlacementParams.AllowedSurfaces : int32

These are CONFIRMED fields from the SDK header dump. This is NOT speculative — we are reading and writing only fields we know exist.

Paste the block below into Codex.

---

```
SeamlessGlass has been updated upstream to patch FSN2PlacementParams.AllowedSurfaces directly on all loaded SN2ItemBrushActionData instances. The patch sets AllowedSurfaces from its current value (likely 2 = BaseWall only) to 14 (BaseWall | BaseFloor | BaseCeiling). The force-true legality hooks remain as a secondary safety net.

REPO COMMIT TO PULL: fe0075a "feat: patch AllowedSurfaces bitmask on SN2ItemBrushActionData..."

This uses ONLY SDK-confirmed field access:
  ad.EditModes          -- confirmed: TArray<FSN2EditMode>
  editModes:Num()       -- standard UE4SS TArray method
  editModes[i]          -- standard UE4SS TArray indexer
  mode.EditBrushes      -- confirmed: TMap<FSN2EditBrushKey, FSN2EditBrush>
  brushes:ForEach(fn)   -- standard UE4SS TMap iterator (may not be available)
  brush.InitialPiecePlacementParams              -- confirmed: FSN2PlacementParams
  params.AllowedSurfaces                         -- confirmed: int32

Every read and write is wrapped in pcall. NO speculative obj[unknown_name] access.

STEPS

1. Confirm helper mod folders are still neutralised (belt-and-suspenders):
   Test-Path "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\BrushDataProbe\enabled.txt"
   Test-Path "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\HeaderDumpTrigger\enabled.txt"
   Both must be False. If True, delete them.

2. Pull the latest SeamlessGlass:
   cd C:\Temp
   Remove-Item -Recurse -Force SN2-mods-v7 -ErrorAction SilentlyContinue
   git clone https://github.com/tm-coder-484/SN2-mods C:\Temp\SN2-mods-v7
   git -C C:\Temp\SN2-mods-v7 log -1 --oneline
   Expected: commit fe0075a or newer.

3. Overwrite installed SeamlessGlass Scripts:
   Copy-Item -Recurse -Force `
     "C:\Temp\SN2-mods-v7\SeamlessGlass\Scripts\*" `
     "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\SeamlessGlass\Scripts\"

4. Verify the new surface_unlock.lua has the AllowedSurfaces patch:
   Select-String -Path "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\SeamlessGlass\Scripts\surface_unlock.lua" -Pattern "AllowedSurfaces"
   Expected: multiple matches including "TARGET_MASK" and "params.AllowedSurfaces".

5. Delete the old UE4SS log:
   Remove-Item "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\UE4SS.log" -ErrorAction SilentlyContinue

6. Ask the user to launch SN2, load a save, and:
   a) Open the UE4SS GUI console BEFORE attempting any placement
   b) Watch for these lines as the game starts:
        [SeamlessGlass] surface unlock hooks registered (AllowedSurfaces patch + force-true)
        [SeamlessGlass] scan: N new ActionData(s), M brush(es) patched
        Or:
        [SeamlessGlass] note: TMap ForEach not available on EditBrushes for ...
   c) Wait ~15 seconds after loading the save (lets the periodic re-scan run)
   d) Then try to place a window on the floor, then ceiling
   e) Close the game

7. CRITICAL — if at any point the game crashes, STOP and report the crash dump path. We are accessing more fields than before, so although every step is pcall'd, native crashes are possible.

8. After the test, extract from UE4SS.log:
   - All lines containing "[SeamlessGlass" — especially the "scan: ..." or "patched brush" or "TMap ForEach not available" lines
   - Any new "Error:" "Fatal" or "lua_pcall" lines
   Show me the filtered output.

9. Report observations:
   - Did game stay stable?
   - Did the scan log lines appear? How many brushes were reported patched?
   - Did floor placement work this time?
   - Did ceiling placement work?
   - Did wall placement still work (regression check)?

POSSIBLE OUTCOMES AND WHAT THEY MEAN

A) "M brush(es) patched" with M > 0, and floor/ceiling now works
   -> Success. We'll narrow this to windows only in the next round.

B) "M brush(es) patched" with M > 0, but floor/ceiling STILL doesn't work
   -> AllowedSurfaces isn't the only gate. We'll add another scan target.

C) "TMap ForEach not available" appears
   -> UE4SS Lua doesn't expose TMap iteration the way we tried. We'll need a different access pattern (likely a get-by-key approach using FSN2EditBrushKey).

D) Scan finds zero ActionData instances
   -> FindAllOf("SN2ItemBrushActionData") returns empty. Either the class name is wrong or the assets aren't UObjects accessible to FindAllOf. We'll try a different class name or rely on hooking when ActionData is referenced.

CONSTRAINTS
- Do NOT re-enable BrushDataProbe or HeaderDumpTrigger
- Do NOT modify mod files
- If crash occurs, stop immediately
```
