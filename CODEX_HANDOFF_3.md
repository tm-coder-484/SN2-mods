# Codex Handoff Prompt 3 — Pull Fixes and Capture Diagnostic Output

Paste the block below into Codex.

---

```
The SeamlessGlass mod has been substantially patched upstream. The new version:
- Adds a unreal_util.lua helper that unwraps UE4SS RemoteUnrealParam values
- Uses variadic (...) hook signatures so it doesn't matter how many params SN2 passes
- Guards RegisterInitGameStatePostHook against duplicate firing
- pcall-wraps every hook body so it cannot crash the game
- Emits diagnostic lines tagged [SeamlessGlass.diag] and [SeamlessGlass.main.diag] for the first 5 hook fires of each kind, describing every argument received

Pull this fix and re-test. The diagnostics will tell us what the real parameter shape is so any remaining issues can be fixed surgically.

WORKING DIRECTORY: D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64

UPSTREAM REPO: https://github.com/tm-coder-484/SN2-mods
LATEST COMMIT EXPECTED: 3a2c882 "fix: defensive hook callbacks with RemoteUnrealParam unwrap..."

STEPS

1. Re-clone the mod repo to a temp folder and confirm HEAD:
   git clone https://github.com/tm-coder-484/SN2-mods C:\Temp\SN2-mods-v3
   cd C:\Temp\SN2-mods-v3
   git log -1 --oneline

   Expected: commit starting "3a2c882" with message containing "RemoteUnrealParam unwrap".

2. Overwrite the installed SeamlessGlass Scripts folder (this picks up the new unreal_util.lua too):
   Copy-Item -Recurse -Force `
     "C:\Temp\SN2-mods-v3\SeamlessGlass\Scripts\*" `
     "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\SeamlessGlass\Scripts\"

3. Verify the new file is present:
   Get-ChildItem "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\SeamlessGlass\Scripts\"

   Expected listing includes: unreal_util.lua, main.lua, surface_unlock.lua, adjacency_tracker.lua, post_hider.lua, config.lua

4. Delete the old UE4SS log so we get a clean capture:
   Remove-Item "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\UE4SS.log" -ErrorAction SilentlyContinue

5. Ask the user to launch SN2, load a save, and perform these actions in order with ~5s pause between each:
   a) Place a window on a vertical WALL
   b) Try to place a window on the FLOOR
   c) Try to place a window on the CEILING
   d) Place a second window adjacent to the first wall window
   e) Deconstruct one of the adjacent wall windows
   Then have them close the game cleanly (no force-kill).

6. Read the UE4SS log and extract:
   - ALL lines containing "[SeamlessGlass" (including .diag suffixes)
   - Any lines with "Error:" or "ERROR" that occur AFTER "[SeamlessGlass] ready."
   - Any lines containing "lua_pcall" "attempt to" or "bad argument"

   Show me this filtered output. Do not truncate — there should only be a few dozen relevant lines.

7. Report observations:
   - Did the game crash or remain stable?
   - In-game: did the floor/ceiling placement ghost appear at all? Did anything actually place?
   - In-game: did the structural post between two adjacent wall windows visually disappear?
   - Were there any new red errors that did NOT appear in the prior report?

CONSTRAINTS
- Do not edit any mod files this round — we are diagnosing, not patching
- Do not delete unreal_util.lua even though it's a new file — it's required
- If the user reports a crash, capture UE4SS.log's last 200 lines and report immediately

After you give me the diagnostic dump, I will analyse it and either:
(a) Confirm features are working — in which case we will only need to verify window class names and post component names with a probe (the original Phase B/C work)
(b) Identify which specific hook is still misbehaving and prepare a targeted patch

Start by pulling the fix (step 1) and report what you see.
```
