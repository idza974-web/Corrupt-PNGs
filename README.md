# Corrupt-PNGs

A PowerShell script that applies visual glitch and corruption effects to PNG files recursively.

Originally made to corrupt a Minecraft resource pack for a video, but works on any folder of PNGs.

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)

---

## Effects

Each image gets 1–3 randomly selected effects applied, scaled by the `-Intensity` parameter.

| Effect | Description |
|---|---|
| **PixelSort** | Sorts pixels by brightness along random horizontal spans, creating streaky data-moshing |
| **ChannelShift** | Offsets the red channel horizontally to produce RGB chromatic aberration |
| **ScanlineGlitch** | Shifts entire horizontal scanlines left or right by random amounts |
| **BlockCorruption** | Copies random rectangular chunks of the image onto other random positions |
| **ColorInvert** | Inverts colors in random rectangular regions |
| **ChannelDrop** | Zeroes out an entire color channel (R, G, or B) on random rows |
| **HorizontalTear** | Creates thick horizontal bands that shift sideways, like a VHS tracking error |
| **Pixelate** | Applies chunky mosaic pixelation to random regions |

---

## Requirements

- Windows
- PowerShell 5.1 or later (built into Windows 10/11)
- No external dependencies — uses `System.Drawing` which ships with .NET

---

## Usage

### Basic

```powershell
.\Corrupt-PNGs.ps1 -Directory "C:\path\to\images"
```

### All parameters

```powershell
.\Corrupt-PNGs.ps1 -Directory <path> [-Intensity <0.1–1.0>] [-BackupOriginals] [-OutputDirectory <path>]
```

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Directory` | `string` | *(required)* | Path to the folder containing PNGs. Searched recursively. |
| `-Intensity` | `double` | `0.5` | How destructive the effects are. Range: `0.1` (subtle) to `1.0` (mayhem). Also controls how many effects are applied per image. |
| `-BackupOriginals` | `switch` | off | Saves a copy of each original file as `filename.png.bak` next to the source before modifying it. |
| `-OutputDirectory` | `string` | *(none)* | Write corrupted files here instead of overwriting originals. Preserves the source folder's directory structure. |

### Examples

```powershell
# Subtly glitch everything in a folder
.\Corrupt-PNGs.ps1 -Directory "C:\textures" -Intensity 0.2

# Maximum chaos
.\Corrupt-PNGs.ps1 -Directory "C:\textures" -Intensity 1.0

# Keep originals safe, write glitched copies elsewhere
.\Corrupt-PNGs.ps1 -Directory "C:\textures" -OutputDirectory "C:\textures-glitched"

# Modify in-place but back everything up first
.\Corrupt-PNGs.ps1 -Directory "C:\textures" -BackupOriginals

# Combine: max intensity, non-destructive output
.\Corrupt-PNGs.ps1 -Directory "C:\textures" -Intensity 0.9 -OutputDirectory "C:\glitched"
```

---

## First run: execution policy

Windows blocks unsigned scripts by default. Run this once to allow scripts for the current PowerShell session only (nothing is permanently changed):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Or permanently for your user account:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

## Making a corrupted Minecraft texture pack

### 1. Extract the vanilla assets

Minecraft's textures are stored inside the game's `.jar` file, which is just a zip archive.

1. Open **File Explorer** and navigate to:
   ```
   %AppData%\.minecraft\versions\<version>\
   ```
   For example: `C:\Users\You\AppData\Roaming\.minecraft\versions\1.21.4\`

2. Find the file named `<version>.jar` (e.g. `1.21.4.jar`), right-click it, and open it with a zip tool like **7-Zip** or **WinRAR**. Alternatively, rename the extension to `.zip` temporarily.

3. Inside the archive, navigate to `assets\minecraft\textures\` and extract that entire folder somewhere, e.g. `C:\mc-textures\`.

### 2. Run the script

Point the script at your extracted textures folder. Using `-OutputDirectory` is strongly recommended so your originals stay intact:

```powershell
.\Corrupt-PNGs.ps1 -Directory "C:\mc-textures" -OutputDirectory "C:\mc-textures-glitched" -Intensity 0.5
```

Adjust `-Intensity` to taste — `0.3` is unsettling, `0.7`+ is barely recognisable.

### 3. Package it as a resource pack

1. Create a new folder for your pack, e.g. `C:\MyCorruptedPack\`.

2. Inside it, recreate the following structure:
   ```
   MyCorruptedPack\
   ├── pack.mcmeta
   └── assets\
       └── minecraft\
           └── textures\
               └── (your glitched textures go here, preserving subfolders)
   ```

3. Create `pack.mcmeta` in a text editor with the following content. Set `"pack_format"` to match your Minecraft version ([format numbers here](https://minecraft.wiki/w/Pack_format)):
   ```json
   {
       "pack": {
           "pack_format": 46,
           "description": "Corrupted"
       }
   }
   ```

4. Copy the glitched textures from `C:\mc-textures-glitched\` into `assets\minecraft\textures\`, preserving subfolder structure (`block`, `item`, `entity`, etc.).

5. Select `pack.mcmeta` and the `assets` folder together, right-click, and compress them into a `.zip`. The `pack.mcmeta` file must be at the **root** of the zip — not inside a subfolder.

### 4. Install in Minecraft

1. Open Minecraft and go to **Options → Resource Packs → Open Pack Folder**.
2. Drop your `.zip` file into that folder.
3. Back in the Resource Packs screen, move your pack to the **Selected** column and click **Done**.

The world will reload with your corrupted textures active. To uninstall, deselect the pack the same way.

### Tips

- **Selective corruption:** run the script on specific subfolders only (e.g. just `textures\block` or `textures\item`) to leave menus and HUD elements untouched.
- **Intensity recommendation:** `0.4`–`0.6` gives a good balance — recognisably wrong but still playable. Go higher for something more extreme.
- **Re-running:** effects are randomised per image every run, so running the script again on the same folder produces a completely different result.
- **Pack format:** if Minecraft ignores your pack or shows a warning, double-check the `pack_format` number in `pack.mcmeta` matches your game version.

## Notes

- **Handles tiny images** — Minecraft particle and UI textures can be as small as 4×8 pixels. The script guards against out-of-bounds errors on images of any size.
- **Recursive** — all subdirectories are processed.
- **Random per image** — each file gets a different random combination of effects, so results vary across a run even at the same intensity.
- **Effect count** — at `Intensity 0.5`, each image gets ~1–2 effects. At `1.0`, up to 3 effects are stacked per image.
- The script uses `System.Drawing.Bitmap` for pixel manipulation. For very large images or huge folder sets, processing may take a while.

---

## License

MIT
