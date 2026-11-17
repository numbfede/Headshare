<h1 align="center">Headshare</h1>

<p align="center">
  <b>Play your Mac's audio on several headphones and speakers at once.</b><br>
  Free, open source, no subscription, no limits.
</p>

<p align="center">
  <a href="../../releases/latest"><b>⬇︎ Download for macOS</b></a>
  &nbsp;·&nbsp;
  <a href="README.it.md">🇮🇹 Leggi in italiano</a>
</p>

---

macOS can only play through one Bluetooth headset at a time. iPhone has "Share Audio", the Mac doesn't. **Headshare fixes that**: pick your outputs in the menu bar, flip a switch, and everything your Mac plays comes out of all of them, in sync.

Watch a movie with a friend on two pairs of AirPods, play music on headphones and a speaker together, or send sound to the Mac speakers and a TV over HDMI at the same time.

## Features

- **Any number of outputs**: AirPods, Beats, any Bluetooth headphones or speakers, USB, HDMI, DisplayPort and the Mac's own speakers
- **Per-device volume and delay** to keep every output perfectly lined up, plus a master volume
- **Sync reference** (👑): choose which device keeps the clock; the others follow it with drift correction
- **One-click connect** for paired Bluetooth devices, right from the menu
- **Auto-share** as soon as your selected devices connect
- **Global keyboard shortcut** to start or stop sharing from any app
- **Keeps audio quality high**: uses the Mac's microphone so Bluetooth headsets don't drop into low-quality call mode
- **Restores your previous output** when you stop sharing or quit
- **Liquid Glass design** on macOS 26, a guided tour on first launch, a full Settings window, open at login
- **Available in 34 languages**, following your Mac's language
- **No drivers, no kernel extensions, no admin password**: public CoreAudio APIs only

## Install

1. Download **`Headshare-x.y.z.dmg`** from [Releases](../../releases/latest).
2. Open it and drag **Headshare** into the **Applications** folder.
3. Open Headshare from Applications. The first time, macOS may say it can't verify the developer, because the app isn't notarized by Apple yet:
   - open **System Settings › Privacy & Security**, scroll down and click **Open Anyway**, or
   - run once in Terminal: `xattr -dr com.apple.quarantine /Applications/Headshare.app`
4. Allow Bluetooth access when asked, so Headshare can show your paired devices.

**Requirements:** macOS 14 Sonoma or later, Apple Silicon or Intel.

## How to use

1. Click the 🎧 icon in the menu bar.
2. Select at least two outputs. Click anywhere on a row.
3. Flip the switch. Done.

Use the sliders button on each output for volume and delay, and the crown to choose the sync reference. Everything else is in **Settings** (⌘,).

## Languages

English, Italian, German, French (France and Canada), Spanish (Spain and Latin America), Portuguese (Brazil and Portugal), Dutch, Swedish, Danish, Norwegian, Finnish, Polish, Czech, Slovak, Hungarian, Romanian, Croatian, Catalan, Greek, Turkish, Russian, Ukrainian, Arabic, Hebrew, Hindi, Thai, Vietnamese, Indonesian, Malay, Japanese, Korean, Chinese (Simplified, Traditional, Hong Kong).

Found a translation that could be better? Open an issue or a pull request: translations live in [`Localization/translations`](Localization/translations).

## Known macOS limits

- AirPods volume often can't be changed by apps. Use the buds themselves.
- Keyboard volume keys don't control a multi-output device. Use the slider in the Headshare menu.

## Build from source

```bash
git clone https://github.com/numbfede/Headshare.git
cd Headshare
./build.sh install      # build and install to /Applications
./make-dmg.sh           # optional: create the installer DMG in ./build
```

Requires Xcode 26 (Liquid Glass UI and the Icon Composer app icon).

To update translations: edit `Localization/translations/<lang>.json`, then run `python3 Localization/generate.py`.

## Releasing

Bump `CFBundleShortVersionString` in `Resources/Info.plist` (for example `1.1.0`) and push to `main`. GitHub Actions builds a universal app, packages the DMG and publishes release `v1.1.0` with the DMG as its download.

## Credits

App icon designed by numbfede in Icon Composer. Headphones glyph by [Icons8](https://icons8.com).

## License

MIT © numbfede (code). The app icon is licensed separately and is not covered by the MIT license.
