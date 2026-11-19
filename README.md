# World of Warplanes for Mac — v1

The first release.

## What v1 was

- A Wineskin wrapper (Porting Kit) running **CrossOver 23.7.1 Wine**.
- Graphics: Direct3D 9 translated by **WineD3D on OpenGL** (Wine's built-in translation layer; no DXVK, no D3DMetal).
- **Flight Deck**: a small setup app that walks you through copying the game app to Applications, getting the Wargaming installer, and installing Game Center.
- A Pilot's Manual (HTML) with setup and troubleshooting.

Not in v1: the launcher menu, automatic engine switching, Low Power, resolution matching, and macOS Game Mode.

## Files

- `flightdeck/FlightDeck.swift`, `art.swift`, `bookmark.swift`: source for the Flight Deck setup app (SwiftUI).
- `flightdeck/dsstore2.py`: makes the DMG window layout.
- `flightdeck/manual.template.html` and `Pilot's Manual.html`: the manual.
- `wrapper/wineskinlauncher.sh`: the small script inside the app that waits for Wine to fully exit.
