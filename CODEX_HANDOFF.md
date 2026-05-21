# Codex Handoff Prompt — SeamlessGlass Install

Open Codex in `[SN2 game folder]/Binaries/Win64/` and paste the entire block below as your first message. Codex will diagnose the current state and apply all fixes autonomously.

---

```
You are installing a Subnautica 2 mod called SeamlessGlass on my machine. The working directory I have opened you in IS the Subnautica 2 Binaries/Win64 folder — the one containing Subnautica2-Win64-Shipping.exe. You have read/write access to this folder.

CONTEXT
- Subnautica 2 runs on Unreal Engine 5.6 (Early Access)
- The mod loader is UE4SS — specifically the EXPERIMENTAL build, not the stable v3.0.1, because stable lacks UE 5.6 AOB signatures
- The mod also requires Mariana — a community Lua framework for SN2 modding built on UE4SS
- Mod source repo: https://github.com/tm-coder-484/SN2-mods
- Mariana source repo: https://github.com/GOD-GAMER/mariana-sn2
- Experimental UE4SS release page: https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest

CURRENT KNOWN ISSUE
The UE4SS console launches but logs:
  - "Failed to find EngineVersion"
  - "Failed to find GUObjectArray"
  - "Fatal Error: PS scan timed out"
Root cause: I currently have stable UE4SS (or partial/broken install). Need to fully replace with experimental + correct settings.

YOUR JOB
1. AUDIT the current state of this folder. Report what you see:
   - Is `dwmapi.dll` present? What size? When was it modified?
   - Is `ue4ss/` folder present? List its top-level contents.
   - Is `ue4ss/UE4SS-settings.ini` present? Show me the [General], [EngineVersionOverride], and [Debug] sections (if any).
   - Is `ue4ss/Mods/` present? What folders are inside? Does `mods.txt` exist? Show its contents.
   - Is the old `Mods/` folder (at Win64 root, NOT under ue4ss/) present? If so, what's inside?
   - Is `UE4SS_Signatures/` present? List contents.

2. BACK UP anything I might lose:
   - If `ue4ss/Mods/SeamlessGlass/` or `ue4ss/Mods/Mariana/` exist, copy them to `[SN2 game folder]/_modbackup/` first
   - Same for any in the old `Mods/` root folder

3. CLEAN INSTALL of experimental UE4SS:
   - Delete: `dwmapi.dll`, `UE4SS-settings.ini` (if at Win64 root level), `UE4SS.log`, `UE4SS.dll`, `UE4SS.exe`, `UE4SS.pdb`, `imgui.ini`, `UE4SS_Signatures/`, the `ue4ss/` folder, and the `Mods/` folder at Win64 root
   - Download the experimental UE4SS zip. The latest experimental release is at:
     https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest
     Find the asset whose filename contains "experimental-latest" (typical name: `UE4SS_v3.0.1-XXX-experimental-latest.zip`). Use `Invoke-WebRequest` to download it.
   - Extract the zip directly into the current folder (Binaries/Win64/). After extracting, `dwmapi.dll` and a fresh `ue4ss/` folder should exist here.

4. PATCH UE4SS-settings.ini at `ue4ss/UE4SS-settings.ini`. Make sure these sections exist with these values (create section headers if absent, overwrite existing keys if different):

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

5. INSTALL Mariana:
   - Clone `https://github.com/GOD-GAMER/mariana-sn2` into a temp folder
   - From inside the clone, copy `Subnautica2/Binaries/Win64/Mods/Mariana/` into `ue4ss/Mods/Mariana/` of the current install
   - Verify: `ue4ss/Mods/Mariana/main.lua` exists

6. INSTALL SeamlessGlass:
   - Clone `https://github.com/tm-coder-484/SN2-mods` into a temp folder
   - Copy the `SeamlessGlass/` folder from the clone into `ue4ss/Mods/SeamlessGlass/` of the current install
   - Verify: `ue4ss/Mods/SeamlessGlass/Scripts/main.lua` and `enabled.txt` exist

7. UPDATE `ue4ss/Mods/mods.txt` so it contains these lines near the top (Mariana before SeamlessGlass — order matters):

   Mariana : 1
   SeamlessGlass : 1

   Preserve any other lines already in mods.txt.

8. RESTORE BACKUPS if applicable:
   - If `_modbackup/` had any custom mods I'd built, copy them back into `ue4ss/Mods/` and remind me to register them in mods.txt

9. VERIFY by listing the final state:
   - Show me the contents of `ue4ss/Mods/` folder
   - Show me the patched `[General]`, `[EngineVersionOverride]`, and `[Debug]` sections of UE4SS-settings.ini
   - Show me the contents of `ue4ss/Mods/mods.txt`
   - Tell me to launch Subnautica2.exe and report whether the UE4SS console shows:
       [Lua] [Mariana] v1.1.0 initialised for Subnautica2
       [SeamlessGlass] loaded
     ...with NO red "Fatal Error" lines.

CONSTRAINTS
- Do not modify Subnautica2-Win64-Shipping.exe or any .pak files
- If a download or clone fails, stop and tell me exactly which command failed
- If a file you're about to delete looks like personal/save data (not UE4SS-related), stop and ask first
- After every destructive step, briefly confirm what you did

Start with step 1 (audit) and report findings before proceeding.
```
