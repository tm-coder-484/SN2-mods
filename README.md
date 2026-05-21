# SeamlessGlass — Subnautica 2 Mod

Allows window base pieces to be placed on **floors and ceilings**, and removes the metal posts between adjacent windows so glass looks fully seamless around corners.

---

## What you need

- Subnautica 2 (Steam or Epic, Early Access)
- About 30–60 minutes the first time

---

## Step 1 — Install UE4SS (experimental build)

UE4SS is the mod loader. **You must use the experimental build, not the stable v3.0.1** — the stable release doesn't include UE 5.6 signatures, and SN2 won't load mods without them.

1. Go to https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest
2. Download `UE4SS_v3.0.1-...-experimental-latest.zip` (the one with "experimental" in the name)
3. Extract **all files** into `[SN2 game folder]/Binaries/Win64/` — after extracting, you should have a new `ue4ss/` folder and a `dwmapi.dll` file in `Binaries/Win64/` alongside `Subnautica2-Win64-Shipping.exe`
4. Open `Binaries/Win64/ue4ss/UE4SS-settings.ini` and make sure these sections exist (add or update as needed):
   ```ini
   [General]
   bUseUObjectArrayCache = false

   [EngineVersionOverride]
   MajorVersion = 5
   MinorVersion = 6

   [Debug]
   ConsoleEnabled = 1
   GuiConsoleEnabled = 1
   GuiConsoleVisible = 1
   GraphicsAPI = dx11
   ```
   The `bUseUObjectArrayCache = false` and `[EngineVersionOverride]` lines are **critical** — without them, UE4SS scan will time out.
5. Launch SN2. A floating UE4SS GUI console window should appear with no red errors. Close the game.

---

## Step 2 — Install Mariana

Mariana is the SN2 modding framework SeamlessGlass is built on.

1. Go to https://github.com/GOD-GAMER/mariana-sn2 and click **Code → Download ZIP**
2. Extract the zip. Inside you'll find a `Mariana/` folder.
3. Copy that `Mariana/` folder into:
   ```
   [SN2 game folder]/Binaries/Win64/ue4ss/Mods/
   ```
   After this, `Mods/Mariana/enabled.txt` should exist.

---

## Step 3 — Deploy the mod files

1. Copy the `SeamlessGlass/` folder into:
   ```
   [SN2 game folder]/Binaries/Win64/ue4ss/Mods/SeamlessGlass/
   ```
2. Open `Binaries/Win64/ue4ss/Mods/mods.txt` in Notepad and add these lines (Mariana must come before SeamlessGlass):
   ```
   Mariana : 1
   SeamlessGlass : 1
   ```
   Mods not listed in `mods.txt` will not load.
3. Launch SN2. The UE4SS GUI console should show:
   ```
   [Mariana] v1.1.0 initialised for Subnautica2
   [SeamlessGlass] initialising...
   [SeamlessGlass] surface unlock hooks registered
   [SeamlessGlass] ready.
   ```
   If you see errors instead, skip to the Troubleshooting section at the bottom.

---

## Step 4 — Find the game's class names (SDK dump)

> **This is the one technical step.** SeamlessGlass needs to know the internal names SN2 uses for its builder functions. These names can change between game updates, so you look them up once and write them into a config file.

### 4a — Run the dump

1. Launch SN2 and load any save (you need to be in-game)
2. Press `~` to open the UE4SS console
3. Type `dump_sdk` and press Enter. Wait until it says done.
4. Type `dump_uht_compatible_headers` and press Enter. Wait until it says done.
5. Close the game.

A folder called `CXXHeaderDump` (or `UHTCompatibleHeaders`) will appear inside `Binaries/Win64/ue4ss/`.

### 4b — Search the dump

Open **PowerShell** (search for it in the Start menu) and run these commands one at a time. Replace `[SN2 game folder]` with the actual path to your game (e.g. `C:\Program Files\Steam\steamapps\common\Subnautica2`).

**Find the builder class and its functions:**
```powershell
$dump = "[SN2 game folder]\Binaries\Win64\ue4ss\CXXHeaderDump"
Get-ChildItem -Recurse $dump -Filter "*.hpp" | Select-String -Pattern "Build|Habitat" | Format-Table Path, Line -AutoSize
```
Look for a class like `UBuilderComponent` or `UHabitatBuilderComponent`. Note the package name at the top of its file (looks like `// Package: /Script/Subnautica2`) and find three methods:
- One that checks if a surface is valid (returns `bool`, takes a `HitResult`)
- One that places/builds a piece
- One that removes/deconstructs a piece

**Find window piece class names:**
```powershell
Get-ChildItem -Recurse $dump -Filter "*.hpp" | Select-String -Pattern "Window|Glass|Pane" | Format-Table Path, Line -AutoSize
```
Look for Blueprint actor classes ending in `_C` that represent window pieces.

**Find the post mesh component name:**

Load a save, build one window piece, then in the UE4SS console type:
```
DumpComponents [paste the full actor name from LogAllObjects here]
```
Look for component names containing "Post", "Frame", or "Pillar".

### 4c — Fill in config.lua

Open `SeamlessGlass/Scripts/config.lua` in Notepad. Replace the example values with what you found:

```lua
Config.BUILDER_VALIDITY_FUNC = "/Script/Subnautica2.BuilderComponent:IsValidBuildSurface"
Config.BUILDER_PLACE_FUNC    = "/Script/Subnautica2.BuilderComponent:PlacePiece"
Config.BUILDER_REMOVE_FUNC   = "/Script/Subnautica2.BuilderComponent:RemovePiece"

Config.WINDOW_PIECE_CLASSES  = { "BP_Window_C", "BP_WindowLarge_C" }

Config.POST_COMP_NAME_PATTERN = "PostMesh"
```

The format is `/Script/PackageName.ClassName:FunctionName` — use the package name, class name, and function name exactly as they appear in the dump.

---

## Step 5 — Install the transparent material pak

> Your friend may have already built this file (`SeamlessGlass-Assets_P.pak`) and included it. If so, skip to sub-step 3.

### If you need to build it yourself:

1. Install Unreal Engine 5.6 from the [Epic Games Launcher](https://store.epicgames.com/en-US/download) (free, ~30 GB)
2. Launch UE 5.6 → New Project → Games → Blank → No Starter Content → name it `SeamlessGlassAssets` → Create
3. In the Content Browser, create the folder path: `Content/SeamlessGlass/Materials/`
4. Right-click inside that folder → **Create Material** → name it `M_Invisible`
5. Open the material. In the Details panel set **Blend Mode: Translucent** and **Shading Model: Unlit**
6. In the graph, right-click → add a `Constant` node → set value to `0.0` → drag its output to the **Opacity** pin
7. Click **Apply** then **Save**
8. Top menu → **Platforms → Windows → Package Project** → pick an output folder → wait ~2 minutes
9. In the output folder, find the `.pak` file inside `WindowsNoEditor/SeamlessGlassAssets/Content/Paks/`
10. Rename it to `SeamlessGlass-Assets_P.pak`

### Deploy the pak:

Copy `SeamlessGlass-Assets_P.pak` to:
```
[SN2 game folder]/Subnautica2/Content/Paks/~mods/SeamlessGlass-Assets_P.pak
```
Create the `~mods/` folder if it doesn't exist.

---

## Step 6 — Test it

Launch SN2 and load a save. Try these:

- **Floor window:** Equip Habitat Builder → select a window → aim at a floor → place it
- **Ceiling window:** Same, aim at a ceiling
- **Seamless wall:** Place two windows side by side → the post between them should disappear
- **Corner:** Place windows on two perpendicular walls at a corner → corner post disappears

If anything doesn't work, check the UE4SS console for error messages and compare them against the Troubleshooting section below.

---

## Troubleshooting

**`[SeamlessGlass] loaded` doesn't appear**
- Confirm `SeamlessGlass/enabled.txt` exists in the Mods folder
- Confirm `ConsoleEnabled = 1` in `UE4SS-settings.ini`

**`attempt to call nil` error on a hook**
- The function path in `config.lua` is wrong — go back to Step 4 and re-check the dump

**Posts don't disappear**
- The `POST_COMP_NAME_PATTERN` in `config.lua` doesn't match the actual component names — use the `DumpComponents` command in-game to find the exact names

**Transparent material not found / posts swap to black instead of invisible**
- The pak isn't loading — confirm the file is named `SeamlessGlass-Assets_P.pak` (note the `_P`) and is in the `~mods/` folder
- In the UE4SS console, type `FindObject("/Game/SeamlessGlass/Materials/M_Invisible")` — if it returns nil, the pak path doesn't match

**Posts re-appear after reloading a save**
- This is a known v1 limitation — adjacency state is rebuilt on the next build/deconstruct action. A full fix is noted in the plan for a future update.

---

## Updating after a game update

If SN2 updates and the mod breaks, the only file you usually need to update is `SeamlessGlass/Scripts/config.lua`. Re-run the SDK dump (Step 4) and update the function paths. The rest of the mod stays the same.
