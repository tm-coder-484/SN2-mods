# Codex Handoff Prompt 2 — In-Game Feature Verification & Class Discovery

Open Codex in `[SN2 game folder]/Binaries/Win64/` and paste the entire block below. This builds a probe mod, has the player perform specific in-game actions to capture real class/component names, then patches `SeamlessGlass/Scripts/config.lua` with the discovered values.

---

```
SeamlessGlass is installed and its hooks are loading without errors in the UE4SS console. We now need to verify the actual gameplay features work, and if they don't, capture real Subnautica 2 class names by writing a probe mod.

WORKING DIRECTORY: D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64 (the SN2 Win64 folder)

MOD INSTALL LOCATION:
  ue4ss\Mods\SeamlessGlass\Scripts\config.lua  ← what we're refining
  ue4ss\Mods\SeamlessGlass\Scripts\main.lua    ← already wired correctly
  ue4ss\Mods\Mariana\                          ← required dependency, already working

CURRENT KNOWN-GOOD CONFIG VALUES (in config.lua):
  Config.BUILDER_VALIDITY_FUNC = "/Script/Subnautica2.SN2BuilderAbility:HasValidConstructTarget"
  Config.BUILDER_PLACE_FUNC    = "/Game/Blueprints/AbilitySystem/Abilities/Tools/Builder/BuilderActions/PlaceGhost/GA_BaseEdit.GA_BaseEdit_C:TryApply"
  Config.BUILDER_REMOVE_FUNC   = "/Script/Subnautica2.SN2BaseEditAbility:ServerDeconstructActor"

CURRENT UNVERIFIED CONFIG VALUES (placeholders, likely wrong):
  Config.WINDOW_PIECE_CLASSES    = { "BP_Window_C", "BP_WindowLarge_C" }
  Config.POST_COMP_NAME_PATTERN  = "PostMesh"

WHAT TO DO

=== PHASE A — Observe in-game behavior ===

1. Ask the user to launch SN2, load a save, and prepare a small base with at least one room. Tell them to wait at this point.

2. Tail the UE4SS log live so we can see what fires:
   Get-Content -Wait "ue4ss\UE4SS.log" -Tail 50

3. Have the user equip the Habitat Builder, select any window piece, then perform these three actions in order, pausing 5 seconds between each so we can see distinct log entries:
   a) Aim at a vertical WALL (the normal case) and place a window
   b) Aim at the FLOOR — note whether the ghost preview turns red or green, and whether a click places anything
   c) Aim at the CEILING — same observation

4. Report what you see in the log for each action. Specifically watch for:
   - Whether [SeamlessGlass] log lines fire at all during these actions
   - Whether the HasValidConstructTarget / TryApply / ServerDeconstructActor hooks fire (look for "Registered native hook" and any subsequent activity)
   - Any new red error lines

If [SeamlessGlass] log lines do NOT fire when the user attempts to build, the function hooks are not catching the events. Stop and tell me before proceeding — we may need different function paths.

If features APPEAR to work (floor placement actually places, posts vanish between adjacent windows), great — skip to Phase D and document the success.

Most likely outcome: hooks fire but features don't work because WINDOW_PIECE_CLASSES doesn't match. Continue to Phase B.

=== PHASE B — Build a probe mod for window class and component names ===

5. Create a new UE4SS Lua mod at ue4ss\Mods\WindowProbe\:

   File: ue4ss\Mods\WindowProbe\enabled.txt (empty file)

   File: ue4ss\Mods\WindowProbe\Scripts\main.lua:

   local OUT = "ue4ss\\Mods\\WindowProbe\\probe.txt"

   local function appendLine(line)
       local f = io.open(OUT, "a")
       if f then f:write(line .. "\n"); f:close() end
   end

   appendLine("=== Probe started at " .. os.date() .. " ===")

   -- Hook the placement function to capture what gets spawned
   RegisterHook("/Game/Blueprints/AbilitySystem/Abilities/Tools/Builder/BuilderActions/PlaceGhost/GA_BaseEdit.GA_BaseEdit_C:TryApply",
       function() end,
       function(self, ReturnValue, Params)
           appendLine("--- TryApply post-hook fired ---")
           -- Try to find the most recently placed actor
           local actors = FindAllOf("Actor")
           if not actors then
               appendLine("FindAllOf(Actor) returned nil")
               return
           end
           -- Capture class names of any actor whose name contains Window/Glass/Pane/Hatch
           local seen = {}
           for _, a in ipairs(actors) do
               local ok, name = pcall(function() return a:GetClass():GetFName():ToString() end)
               if ok and name then
                   local lower = name:lower()
                   if lower:find("window") or lower:find("glass") or lower:find("pane") or lower:find("hatch") or lower:find("portal") then
                       if not seen[name] then
                           seen[name] = true
                           appendLine("CANDIDATE ACTOR CLASS: " .. name)
                       end
                   end
               end
           end
       end
   )

   -- Console command to dump components of the most recent window-like actor
   RegisterConsoleCommandHandler("probe_components", function(FullCommand, Parameters, OutputDevice)
       local actors = FindAllOf("Actor") or {}
       for _, a in ipairs(actors) do
           local ok, name = pcall(function() return a:GetClass():GetFName():ToString() end)
           if ok and name and (name:lower():find("window") or name:lower():find("glass")) then
               appendLine("--- Components of " .. name .. " ---")
               local comps = a:GetComponents()
               if comps then
                   for _, c in ipairs(comps) do
                       local cn = c:GetFName():ToString()
                       local ct = c:GetClass():GetFName():ToString()
                       appendLine("  COMP: " .. cn .. "  (" .. ct .. ")")
                   end
               end
           end
       end
       OutputDevice:Log("probe written to ue4ss\\Mods\\WindowProbe\\probe.txt")
       return true
   end)

   print("[WindowProbe] loaded")

6. Register WindowProbe in mods.txt (add "WindowProbe : 1" anywhere after Mariana).

7. Launch SN2, load a save, build at least one window piece on a wall.

8. Open the UE4SS GUI console and run:
       probe_components

9. Close the game, then read ue4ss\Mods\WindowProbe\probe.txt back to me. Report:
   - The CANDIDATE ACTOR CLASS lines (these are the real window class names)
   - The COMP lines for each window actor (these tell us the post mesh component naming pattern)

=== PHASE C — Identify the post mesh component pattern ===

10. From the COMP lines, identify which components look like structural posts vs glass vs other geometry. Posts will typically:
    - Have multiple instances per window (left, right, top, bottom)
    - Be of class UStaticMeshComponent
    - Have similar names like "PostMesh_0", "FramePost", "PillarLeft", "SupportL", etc.

    Find the longest substring common to all post-looking components. That string is the POST_COMP_NAME_PATTERN.

    Examples of what a correct pattern looks like:
    - If components are "PostMesh_0", "PostMesh_1", "PostMesh_2" → pattern is "PostMesh"
    - If components are "Frame_PostL", "Frame_PostR", "Frame_PostT" → pattern is "Frame_Post"
    - If components are "Pillar0", "Pillar1" → pattern is "Pillar"

    If you cannot find a clear pattern, report ALL component names and ask me which look like posts.

=== PHASE D — Update config.lua and verify ===

11. Patch ue4ss\Mods\SeamlessGlass\Scripts\config.lua. Replace the two unverified values:

    Config.WINDOW_PIECE_CLASSES = { "REAL_NAME_1", "REAL_NAME_2", ... }  -- from CANDIDATE lines
    Config.POST_COMP_NAME_PATTERN = "REAL_PATTERN"                        -- from analysis

    Leave all other values in config.lua unchanged.

12. Remove the WindowProbe mod:
    - Delete the ue4ss\Mods\WindowProbe\ folder
    - Remove the "WindowProbe : 1" line from mods.txt

13. Have the user relaunch SN2 and test all features:
    a) Place a window on a wall → should work normally
    b) Place a window on a floor → window should appear flush in the floor, glass facing up
    c) Place a window on a ceiling → window should appear flush in the ceiling, glass facing down
    d) Place two windows side by side on a wall → the structural post between them should become invisible
    e) Deconstruct one of those two adjacent windows → the post on the remaining one should reappear
    f) Place windows at a 90° corner on two perpendicular walls → the shared corner post should become invisible
    g) Save and reload → if posts reappear when isolated, that is a known v1 limitation, not a bug

14. Report which of (a)–(g) work and which don't. If any don't:
    - For placement failures: capture the relevant UE4SS log lines around the failure
    - For post-hiding failures: re-run probe_components, the pattern may need adjustment
    - For rotation issues on floor/ceiling: report whether the window appears at all but is rotated wrong

15. Once at least (a), (b), (c), (d) work, the mod is functionally complete. Update the user's config.lua values in the local install and stop. The repo maintainer (the user's friend who made this mod) will pull the verified values from your report.

CONSTRAINTS
- Do not modify Subnautica2-Win64-Shipping.exe or any .pak files
- Do not modify other mods (Mariana, BPModLoaderMod, etc.) unless absolutely necessary, and ask before doing so
- If the user reports any game crash, stop immediately, capture the last 100 lines of UE4SS.log, and report to me before proceeding
- If FindAllOf("Actor") returns thousands of results making the probe file huge, narrow the filter — but report this rather than truncating silently

Start with Phase A (observation) and report what you see before building the probe.
```
