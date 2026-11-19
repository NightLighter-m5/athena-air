# World of Warplanes for Mac (unofficial)

A ready-made Mac app for running **World of Warplanes** on Apple Silicon Macs. It's a Wine wrapper (Sikarugir) with two engines and a launcher menu, so you don't have to set up Wine yourself.

> Unofficial fan project. Not made by, affiliated with, or endorsed by Wargaming. World of Warplanes is a trademark of Wargaming. The game itself is **not** included. You download it through Wargaming's own Game Center.

## Download

Get the latest DMG from **[Releases](../../releases)**.

## Install

1. Open the DMG and drag **WorldOfWarplanes** into **Applications**. It won't run from the DMG.
2. Open it from Applications. macOS will block it the first time because it isn't signed by a paid Apple developer account.
3. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to WorldOfWarplanes.
4. In the menu, pick **Game Center**. Choose your region, then download and run the Game Center installer.
5. Install World of Warplanes in Game Center. When it's done, close Game Center, reopen the app, and pick **Play**.

## The menu

| Option | What it does |
|---|---|
| **Play** | Starts the game on the game engine. Resolution is matched to your screen. On battery at 50% or less, it starts in Low Power automatically. |
| **Game Center** | Switches to the Game Center engine and opens Game Center, which handles installs and updates. When everything has closed, it switches back to the game engine by itself. |
| **Settings…** | Play in Low Power, Wrapper settings, Open the game folder. |

## Why two engines?

No single Wine build handles both well:

- **Game engine:** CrossOver 23.7.1 Wine with DXVK 2.3 (Direct3D 9 → Vulkan → Metal via MoltenVK). Runs the game smoothly.
- **Game Center engine:** Sikarugir Wine 10 with D3DMetal. Game Center's installer and updater need it.

The launcher swaps them automatically, so you never have to pick one.

## Low Power

Caps the game at 30 FPS and turns down heavy graphics settings. Your own settings are put back after the game closes.

## Requirements

- Apple Silicon Mac (M1 or newer)
- macOS 14 Sonoma or newer
- About 2 GB for the app, plus the game itself (about 10 GB)

## Known issues

- **Mouse can stop turning in one direction in battle.** A trackpad works fine. A fix is being tested.
- **In fullscreen, don't switch apps or swipe to another desktop.** If you Cmd+Tab away or swipe between Spaces, the game minimizes, the same as many other fullscreen Mac games, like Minecraft Java. Stay in the game while you play, or use windowed mode if you need to switch apps.

## What's in this repo

The DMG is under Releases. This repo holds the readable source of the parts I wrote, so you can check exactly what the app does:

- `launcher/wowp-launcher.c`: the small app binary. It runs the menu script and then starts Wine. It's compiled so macOS Game Mode still works.
- `scripts/prelaunch.sh`: the menu, engine switching, Game Center install, and Low Power on battery.
- `scripts/display-sync.sh`: matches the game's resolution to your screen.
- `scripts/lowpower.py`: applies and restores the Low Power graphics settings.
- `scripts/starter-preferences.xml`: default settings used on first run. No account data.

Build the launcher:

```bash
clang -O2 -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 -o launcher launcher/wowp-launcher.c
```

## Verify your download

Each release lists a SHA-256 checksum. Check it with:

```bash
shasum -a 256 "World of Warplanes for Mac v2.dmg"
```

## Credits

- [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) wrapper
- Wine / CrossOver Wine (LGPL)
- [DXVK](https://github.com/doitsujin/dxvk) and [MoltenVK](https://github.com/KhronosGroup/MoltenVK)
- D3DMetal (Apple Game Porting Toolkit)

## Problems?

Open an **[Issue](../../issues)**. Say which Mac you have, your macOS version, and what happened.
