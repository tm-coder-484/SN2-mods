# Codex Handoff Prompt 6 — Clean v5 Test After Probe Contamination

The last "v5 crash" was actually caused by `BrushDataProbe` auto-loading via a leftover `enabled.txt` file — UE4SS has a fallback scanner that loads any mod folder containing `enabled.txt`, regardless of what `mods.txt` says. You've already removed those stale `enabled.txt` files. Time for a clean test.

Paste the block below into Codex.

---

```
GOOD NEWS: The previous "v5 crash" was NOT caused by SeamlessGlass v5. It was caused by the leftover BrushDataProbe/enabled.txt file auto-starting the dangerous diagnostic probe again. You already removed those enabled.txt files in the cleanup. SeamlessGlass v5's force-true hooks registered cleanly and TryApply was observed to fire through them before the probe crashed the game.

The repo has been updated: surface_unlock.lua is back to force-true mode at commit cdc1e5b. The previous safe-mode no-op (commit a45d224) was a precaution we no longer need.

WORKING DIRECTORY: D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64

STEPS

1. Verify both leftover diagnostic mods are fully neutralised:
   Test-Path "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\BrushDataProbe\enabled.txt"
   Test-Path "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\HeaderDumpTrigger\enabled.txt"
   Both must return False. If either returns True, delete the file.

2. As extra insurance, rename the entire helper mod folders so UE4SS cannot scan them at all:
   Rename-Item "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\BrushDataProbe" "_DISABLED_BrushDataProbe" -ErrorAction SilentlyContinue
   Rename-Item "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\HeaderDumpTrigger" "_DISABLED_HeaderDumpTrigger" -ErrorAction SilentlyContinue

3. Pull the latest SeamlessGlass:
   cd C:\Temp
   Remove-Item -Recurse -Force SN2-mods-v6 -ErrorAction SilentlyContinue
   git clone https://github.com/tm-coder-484/SN2-mods C:\Temp\SN2-mods-v6
   cd C:\Temp\SN2-mods-v6
   git log -1 --oneline
   Expected: commit cdc1e5b (or newer).

4. Overwrite installed SeamlessGlass Scripts:
   Copy-Item -Recurse -Force `
     "C:\Temp\SN2-mods-v6\SeamlessGlass\Scripts\*" `
     "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\SeamlessGlass\Scripts\"

5. Verify the installed surface_unlock.lua is in force-true mode (NOT safe mode):
   Select-String -Path "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\SeamlessGlass\Scripts\surface_unlock.lua" -Pattern "force-true mode"
   Expected: at least one match. If no match, the copy didn't take or the wrong version was pulled.

6. Delete the old UE4SS log so we get a clean capture:
   Remove-Item "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\UE4SS.log" -ErrorAction SilentlyContinue

7. Ask the user to launch SN2, load a save, and try these placements with ~5s gaps:
   a) Place a window on a WALL  — should still work like vanilla
   b) Place a window on the FLOOR — was rejected before; should now succeed
   c) Place a window on the CEILING — was rejected before; should now succeed
   d) Place two windows side by side on a wall — observe whether the post between them is hidden
   e) Deconstruct one of those two windows — observe whether the post reappears on the remaining one

   IMPORTANT WARNING TO RELAY TO THE USER: This force-true mode is BROAD — every buildable can be placed on every surface (corridors on the ceiling, etc.). We're testing whether the legality bypass works at all. If it does, the next iteration will narrow this to windows only.

   IF the game crashes again, capture the crash dump path and stop immediately.

8. After the test, extract from UE4SS.log:
   - Lines containing "[SeamlessGlass" (init, hook registration)
   - Lines containing "Registered native hook" — confirm all three legality hooks landed
   - Lines containing "Error:" "ERROR" "Failed" or "Fatal"

9. Report:
   - Game stayed stable? (yes/no)
   - Wall placement: worked? (yes/no)
   - Floor placement: ghost shown? click accepted? piece visible?
   - Ceiling placement: ghost shown? click accepted? piece visible?
   - Any new weird behaviour (e.g. pieces snapping wrong, visual glitches)

CONSTRAINTS
- Do NOT re-enable BrushDataProbe or HeaderDumpTrigger
- Do NOT add ANY new diagnostic code that does speculative obj[name] field access on UE4SS userdata
- If user reports a crash, capture the crash dump path and last 200 lines of UE4SS.log, then stop
```
