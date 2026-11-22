# Security Policy

## Supported versions

Only the latest release gets fixes.

| Version | Supported |
| ------- | --------- |
| v2      | ✅ |
| v1      | ❌ |

## Reporting a vulnerability

**Please don't report security problems in a public Issue.**

Report them privately instead:

1. Go to the **Security** tab of this repository.
2. Click **Report a vulnerability**.
3. Describe the problem, how to reproduce it, and which version you used.

This is a one-person hobby project, so replies may take a few days. You'll get an answer saying whether the problem is confirmed and what will be done about it. Confirmed problems are fixed in a new release, and you'll be credited in the release notes unless you'd rather not be.

## What's in scope

- The scripts and launcher in this repository (`launcher/`, `scripts/`)
- The way the app is packaged in the released DMG

## What's not in scope

Please report these to their own projects instead:

- Wine / CrossOver Wine, Sikarugir, DXVK, MoltenVK, D3DMetal
- World of Warplanes and Wargaming Game Center (report to Wargaming)

## Staying safe

- Only download the DMG from this repository's **[Releases](../../releases)** page. Copies posted anywhere else may have been changed.
- Check the SHA-256 checksum listed on the release before opening the DMG:
  ```bash
  shasum -a 256 "World of Warplanes for Mac v2.dmg"
  ```
- The app isn't signed by a paid Apple developer account, which is why macOS asks you to click **Open Anyway** the first time. The full source of everything written for this project is in this repository, so you can check what it does.
