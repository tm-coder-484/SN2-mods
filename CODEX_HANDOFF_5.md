# Codex Handoff Prompt 5 — Safe Legality Override (Post-Crash)

The previous diagnostic round crashed the game due to dangerous speculative field access on UE4SS userdata. The SDK dump from that round revealed the real placement architecture, and an upstream fix has been pushed that uses the proven safe pattern from Mariana's StackAll sample.

Paste the block below into Codex.

---

```
The previous test produced a fatal native crash inside the BrushDataProbe mod. The crash happened because broad ad[name] probing on UE4SS userdata triggers a native fault that pcall cannot catch. The crash dump landed at ue4ss/crash_2026_05_21_20_29_56.0304681.dmp.

GOOD NEWS: The SDK dump from that same session succeeded and gave us the real answer.

KEY FINDINGS FROM THE SDK DUMP

1. USN2ItemBrushActionData is a data asset, NOT a placement payload. Its only field is:
   TArray<FSN2EditMode> EditModes;

2. The real placement-validity is controlled by:
   FSN2PlacementParams.AllowedSurfaces  // int32 bitmask

   Enum EBuilderPlacementSurface values:
       None=0, Floating=1, BaseWall=2, BaseFloor=4, BaseCeiling=8,
       TerrainWall=16, TerrainFloor=32, TerrainCeiling=64

   A wall+floor+ceiling mask = 2 | 4 | 8 = 14.

3. The real legality gates are (confirmed in headers):
   /Script/Subnautica2.SN2AbilityTask_UpdateBaseEdit:IsLegal           -> bool
   /Script/Subnautica2.SN2AbilityTask_UpdateBaseEdit:CurrentBrushIsValid -> bool
   /Script/Subnautica2.SN2BuilderGhost:IsPlacementLegal               -> bool
   NOT SN2BuilderAbility:HasValidConstructTarget (the one we tried earlier — never fires).

UPSTREAM FIX (already pushed):
The SeamlessGlass surface_unlock.lua has been rewritten. It no longer does ANY speculative obj[name] field access. Instead it uses the StackAll-proven force-true pattern: hook each of the three legality functions and call ret:set(true) on the return value in the post-hook. This is broad — it makes ALL placements legal, not just windows — but it's a safe first step that should let us actually test floor/ceiling placement without crashing.

REPO COMMIT TO PULL: d3fb143 "fix: remove crash-causing speculative field probing..."

STEPS

1. Confirm the BrushDataProbe is disabled (it was already disabled in the safety cleanup, but verify):
   Get-Content "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\mods.txt"
   BrushDataProbe must show ": 0" (or be absent). HeaderDumpTrigger must show ": 0".

2. Pull the upstream fix:
   git clone https://github.com/tm-coder-484/SN2-mods C:\Temp\SN2-mods-v5
   cd C:\Temp\SN2-mods-v5
   git log -1 --oneline
   Expected: commit d3fb143 or newer.

3. Overwrite the installed SeamlessGlass Scripts folder:
   Copy-Item -Recurse -Force `
     "C:\Temp\SN2-mods-v5\SeamlessGlass\Scripts\*" `
     "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\SeamlessGlass\Scripts\"

4. Verify surface_unlock.lua no longer has the dangerous code. Search for the string "deepInspect" — it must NOT be found:
   Select-String -Path "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\SeamlessGlass\Scripts\surface_unlock.lua" -Pattern "deepInspect"
   Expected: no matches. If matches found, the copy didn't take.

5. Also verify the new function paths are present:
   Select-String -Path "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\SeamlessGlass\Scripts\surface_unlock.lua" -Pattern "SN2AbilityTask_UpdateBaseEdit"
   Expected: matches for IsLegal and CurrentBrushIsValid lines.

6. Delete the old UE4SS log to get a clean capture:
   Remove-Item "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\UE4SS.log" -ErrorAction SilentlyContinue

7. Ask the user to launch SN2, load a save, and try these placements with ~5s gaps:
   a) Place a window on a WALL (sanity check)
   b) Place a window on the FLOOR
   c) Place a window on the CEILING
   d) Place two windows side by side on a wall
   e) Deconstruct one of the adjacent windows
   Then close the game cleanly.

   IMPORTANT — warn the user that this fix is BROAD: any buildable can now be placed on any surface (e.g. a corridor on the ceiling, a hatch on a wall). Tell them to test windows first and report whether floor/ceiling placement is now accepted.

   IF the game crashes again, capture the new crash dump path and the last 200 lines of UE4SS.log and STOP — do not retry.

8. After the test, extract from UE4SS.log:
   - Lines containing "[SeamlessGlass" (init, hook registration, diag)
   - Lines containing "Registered native hook" for SN2AbilityTask_UpdateBaseEdit and SN2BuilderGhost
   - Any "Error:" or "Failed to find" lines

   Show me the filtered output.

9. Report observations:
   - Did the game stay stable (no crash)?
   - Did floor placement work (window appears in the floor)?
   - Did ceiling placement work?
   - Did adjacent post-hiding work at all?
   - Did anything weird happen (e.g. pieces placing in unexpected ways)?

CONSTRAINTS
- Do NOT re-enable BrushDataProbe — it crashes
- Do NOT add any new ad[name] / obj[name] field-probing code
- Do NOT modify surface_unlock.lua or any other mod file — just deploy what's in the repo
- If the user reports any crash, stop immediately and report

After this round, depending on what we see:
- If floor/ceiling placement works: we'll narrow the force-true to only fire for window pieces (using a confirmed-safe field read pattern)
- If it still doesn't work: we'll search for additional UFunctions in the SDK dump that may also gate placement, and add them to the force-true list
```
