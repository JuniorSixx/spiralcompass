<p align="center">
  <img src="docs/icon.png" width="128" alt="Spiral Compass icon">
</p>

<h1 align="center">Spiral Compass</h1>

<p align="center">
  Cheat panel and live mission guide for <b>Junji Ito Maniac: An Infinite Gaol</b> (single-player, PC/Steam).
  <br>
  <a href="README.pt-BR.md">🇧🇷 Leia em Português</a>
</p>

<p align="center">
  <img src="docs/screenshot.png" width="620" alt="Spiral Compass panel">
</p>

> **Note:** the panel interface is in Brazilian Portuguese. Item, room and mission names come from the
> game's own text tables, so they follow the language your game is set to.

## Features

**Player**
- Infinite stamina
- God mode (health always full)
- Invisible to enemies (AI can't see you)
- Freeze enemies
- Movement speed from 0.5x to 5x

**"What to do" tab: live mission guide**
- Shows the current mission title and description
- Lists every step with its status: ▶ a companion is waiting for you · ★ you have everything to solve it · … an item is missing · ✓ already solved
- Written solutions for the Chapter 2 puzzles (scale, clown box, Noh masks, golf machine, gold and silver sockets, piggy bank, locked doors), extracted from each puzzle's internal data
- **Automatic mode**: any place in the game that needs an item shows up on its own, with whether you have the item and where it is
- Reads your inventory: tells you if each required item is *with you*, *on the map* (room and floor) or *not available yet*

**"Items on map" tab**
- Every collectible still on the map, with name, room, floor and distance
- 🔒 warning when an item is probably behind a locked door
- **Bring item to me**: moves the item next to you so you pick it up normally (keeps story events intact)

**"Places" tab**
- Teleport to 40 places: every room on the 1st and 2nd floors, attic, safe rooms, garden, garden chalet and basements
- Asks for confirmation before going to areas from other chapters

**Everywhere**
- Compass that points to the selected target relative to your camera, with "go up / go down" hints
- Smart teleport: looks for free space around the target and turns the camera towards it
- **Receive items (skip)**: puts missing items straight into your inventory through the developers' debug cheat manager, for when you are stuck

## Requirements

- Windows 10 or 11
- *Junji Ito Maniac: An Infinite Gaol* (Steam, tested on v1.1.2, Unreal Engine 5.5)
- [UE4SS **experimental**](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) (the stable 3.0.1 release does not support UE 5.5)
- .NET Framework 4.x (already included in Windows)

## Installation

1. **Install UE4SS**
   - Download `UE4SS_v3.0.1-....zip` from the [experimental release](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest).
   - Extract `dwmapi.dll` and the `ue4ss` folder into `...\steamapps\common\JIM\JIM\Binaries\Win64\`.
   - Keep `GuiConsoleEnabled = 0` in `ue4ss\UE4SS-settings.ini` (see [Troubleshooting](#troubleshooting)).
2. **Get Spiral Compass**
   - Download the latest [release](../../releases), **or** clone this repository and run `build.bat`.
3. **Run `install.bat`.** It finds the game in the usual Steam folders. If it doesn't, pass the path:
   ```bat
   install.bat "D:\SteamLibrary\steamapps\common\JIM"
   ```
4. **Play:** start the game, load your save and open
   `...\JIM\Binaries\Win64\ue4ss\Mods\SpiralCompass\SpiralCompass.exe`.
   The panel shows **● connected to the game** in green.

> 💾 Back up your saves before using it: `%LOCALAPPDATA%\JIM\Saved\SaveGames`

## How it works

```
 SpiralCompass.exe  ──cmd.txt──▶  Lua mod (UE4SS, inside the game)  ──▶  Unreal reflection
  (WinForms panel)  ◀─state.txt──        reads / writes by name
```

- The **Lua mod** runs inside the game through UE4SS and talks to the engine through Unreal's reflection system.
  It finds things by name (`GamePlayerCharacter`, `SetStamina`, `MechanicSystem`...), so there are no memory
  addresses or pointers that break when the game restarts.
- The **panel** is a standalone C# program. The two only exchange two small text files in the mod folder.
- Item, room and mission names come from the game's own `DataTable`s and `StringTable`.
- Puzzle status comes from `MechanicSystem.MechanicStateMap`, the same source the in-game map uses for its "?" and ✓ markers.
- Room names use a world-to-map calibration taken from the game's floor-map widget.

## Known limitations

- Written puzzle **solutions** cover Chapter 2. Item-based puzzles in other chapters are listed automatically (what to use and where), but without a written solution.
- **Room names** exist only for the mansion's 1st and 2nd floors. Elsewhere only the floor is shown.
- God mode keeps health full, but some grab/execution animations can still kill you. Use **Freeze enemies** for those.
- Teleporting into areas you haven't unlocked yet can break the story order. The panel warns you, but use it with care.

## Troubleshooting

| Problem | Solution |
|---|---|
| Game crashes with `DiscordHook64.dll` in the crash dump | The Discord overlay conflicts with the UE4SS debug window. Keep `GuiConsoleEnabled = 0`, or disable the Discord overlay for this game. |
| Panel stuck on "waiting for the game" | Check that `ue4ss\UE4SS.log` contains `[SpiralCompass] carregado`, and that `SpiralCompass.exe` is inside the `Mods\SpiralCompass` folder. |
| Mission shows "—" | Open the in-game map once. After that the mission is remembered. |
| "Teleport blocked" | The game refused the spot (no free space). Pick a nearby target or use **Bring item to me**. |

## Uninstall

Delete the `ue4ss\Mods\SpiralCompass` folder. To remove UE4SS too, delete `dwmapi.dll` and the `ue4ss` folder from `JIM\Binaries\Win64`.

## Project structure

```
mod/SpiralCompass/Scripts/main.lua   game side (UE4SS Lua mod)
mod/SpiralCompass/enabled.txt        makes UE4SS load the mod automatically
panel/SpiralCompass.cs               panel (C# 5 / WinForms, no dependencies)
panel/icon.ico                       app icon
tools/                               research scripts used to map the game (see tools/README.md)
build.bat / install.bat              build and install
```

## Disclaimer

Unofficial fan-made tool for **single-player use only**. It is not affiliated with or endorsed by the game's developers or publishers,
or by Junji Ito. No game files or assets are distributed in this repository. Use at your own risk.
