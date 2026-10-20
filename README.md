# Discord Portable

Discord Portable is a portable build of [Discord](https://discord.com/), the voice, video and text chat app. It runs the build that's native to the computer (x64 or ARM64), keeps itself up to date, and can load [BetterDiscord][BD] if you want it to.

It's built with the [PortableApps Compiler][PACMAN] (pac-man): every change it makes to Windows is recorded first and undone when Discord closes, or on the next launch if something went wrong.

I was given permission by Discord Inc. to continue developing this project. They can't officially endorse it because, _"...we do not have a hand in development directly."_ They go on to say:

> _"As a result, if they happen to be released, we recommend to all of our users to be cautious when using third party applications with Discord in general and any usage is at their own risk."_

 [BD]: https://betterdiscord.app/
 [PACMAN]: https://github.com/daemondevin/pac-man

## Download

Downloads are in the [Releases section][REL]. The package is in [PortableApps.com][PA] format, so it installs into the PortableApps.com Platform or any folder you like.

 [REL]: https://github.com/daemondevin/DiscordPortable/releases/latest
 [PA]: https://portableapps.com/

## Features

* The full Discord desktop app.
* **Native on every PC:** x64 and ARM64 builds. On Windows on ARM the launcher downloads and runs the ARM64 build instead of running x64 under emulation. (See [Builds](#builds))
* **Updates itself:** checks Discord's official downloads at start, and also runs any update Discord installs for itself. A failed or interrupted update keeps the version you had. (See [Updates](#updates))
* **Repairs itself:** if Discord's files are missing or damaged, the launcher offers to download Discord again instead of failing to start.
* **Optional BetterDiscord:** one setting turns it on or off. (See [BetterDiscord](#betterdiscord))
* **Your data travels with it:** settings, sign-in and BetterDiscord are kept in `Data`.
* **Leaves nothing behind:** the `discord://` link, the "Open Discord" at startup entry, the uninstall entry and the shortcuts Discord makes for itself only exist while it runs. An installed Discord's are put back exactly as they were.
* **No administrator rights:** everything is done for the current user only.

## System Requirements

* Windows 10 or later, 64-bit (x64 or ARM64). Discord has had no 32-bit build since December 2023.
* [PortableApps.com Platform][PAP] (optional).
* An internet connection.
* `Data` on a local drive (a USB drive is fine; a network share isn't). See [Data](#data).

 [PAP]: https://portableapps.com/download

## Configuration

`DiscordPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\DiscordPortable.ini` over it.

```INI
[DiscordPortable]
AdditionalParameters=
UpdateCheck=true
Architecture=auto
BetterDiscord=false
```

| Key | Values | Default | What it does |
| --- | --- | --- | --- |
| `UpdateCheck` | `true`, `false` | `true` | Check for a new Discord at start and offer to update. |
| `Architecture` | `auto`, `x64`, `arm64` | `auto` | Which build to run. `auto` picks the native one. |
| `BetterDiscord` | `true`, `false` | `false` | Load BetterDiscord into Discord. |
| `AdditionalParameters` | text | empty | Extra command line switches passed to Discord. |

## Builds

| Folder | Build | Runs on |
| --- | --- | --- |
| `App\Discord` | x64 | x64 Windows, and Windows 11 on ARM under emulation |
| `App\DiscordARM64` | ARM64 | ARM64 Windows |

Each folder is laid out the way Discord's installer leaves it, with one `app-<version>` folder per version. The launcher always starts the newest one.

The package ships the x64 build. The first time it starts on ARM64 Windows (with `UpdateCheck=true`), it offers to download the ARM64 build; until then the x64 build runs under emulation. To force a build, set `Architecture=x64` or `arm64`. The ARM64 build can only be forced on ARM64 Windows.

## Updates

Discord updates its own modules every time it starts, and sometimes installs a new version of itself too. The launcher always starts the newest version, so those updates just work.

With `UpdateCheck=true`, the launcher also asks Discord for the latest version each time it starts, the same download links [discord.com](https://discord.com/download) uses. When there's a newer version for a build the package has, it asks before doing anything.

An update is all or nothing:

1. Every installer is downloaded, with a progress bar. If a download fails, nothing changes.
2. Discord is unpacked straight out of each installer, next to the current build. The installer is never run, so nothing gets installed on the PC. If anything can't be unpacked, or isn't the version Discord announced, nothing changes.
3. The new builds are swapped in. Each swap is recorded first, so if one fails, or the launcher is interrupted halfway, the previous version is put back, on the spot or on the next launch.

The launcher carries its own copy of 7-Zip for the unpacking, so it needs no other tools.

A new version starts out the way a fresh install of Discord does: it downloads its voice and other modules the first time it runs, so that start takes a little longer.

A build can't be replaced while it's in use. If the update says so, quit Discord (also from the notification area), then try again.

### Damaged or missing Discord

If the package has no Discord it can run, or Discord's own code (`resources\app.asar`) is missing or empty, the launcher offers to download Discord before it starts. Copies that went through a sync tool or source control are the usual reason for empty files.

## BetterDiscord

Set `BetterDiscord=true` to use [BetterDiscord][BD].

* The first time, the launcher downloads the latest `betterdiscord.asar` from BetterDiscord's GitHub releases. After that, BetterDiscord updates itself from its own settings.
* BetterDiscord's folder (plugins, themes, custom CSS and settings) is kept in `Data\BetterDiscord`. Put plugins in `Data\BetterDiscord\plugins` and themes in `Data\BetterDiscord\themes`, or use the buttons in BetterDiscord's settings.
* Discord's core module is changed so that it loads BetterDiscord only when the launcher asks for it. Discord started any other way, or with `BetterDiscord=false`, runs unmodded, and `BetterDiscord=false` puts the original module back.

> [!NOTE]
> Discord downloads its core module the first time a new version starts, after the launcher has already set up BetterDiscord. BetterDiscord then shows up from the next start. The same happens when Discord updates its core module.

Older versions of Discord Portable kept BetterDiscord in `App\BetterDiscord`. It's moved to `Data\BetterDiscord` the first time the new launcher runs, or when the new version is installed over the old one.

BetterDiscord is a third-party modification. Using it is against Discord's Terms of Service, so it's at your own risk.

## Data

| Discord uses | Kept in |
| --- | --- |
| `%APPDATA%\discord` (settings, sign-in, cache) | `Data\AppData\discord` |
| `%APPDATA%\BetterDiscord` | `Data\BetterDiscord` |

While Discord runs, both are linked into `Data` with NTFS junctions, so nothing is copied back and forth. If an installed Discord already has either folder, it's moved aside for the session and put back when Discord Portable closes.

> [!IMPORTANT]
> Junctions can only point to a local drive. Running from a network share isn't supported.

An installed Discord can't run at the same time as Discord Portable. If one is open, the launcher says so; quit it from the notification area first.

## If something goes wrong

If Discord Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes everything the last session changed before it starts again. You don't need to do anything else.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version |
| `App\AppInfo\Launcher\DiscordPortable.ini` | The launcher configuration: the data links |
| `App\AppInfo\Launcher\custom.nsh` | Build and version selection, the updater, BetterDiscord and the session changes |
| `Other\Source\7-Zip` | The 7-Zip the updater uses, embedded in the launcher at compile time |

Point PortableApps Compiler at the package folder and compile. When cloning this project, either copy a Discord installation into `App\Discord` or let the launcher download Discord the first time it runs.

## Credits

* Discord Portable is a redistribution of the [Discord](https://discord.com/) app, developed by [Discord Inc.](https://discord.com/company)
* [BetterDiscord][BD] by the BetterDiscord team, downloaded on request.
* The updater uses [7-Zip](https://www.7-zip.org/) by Igor Pavlov, licensed under the GNU LGPL. See `Other\Source\7-Zip\License.txt`.
* [PortableApps.com Platform][PAP] by [PortableApps.com][PA].
* [PortableApps Compiler][PACMAN] developed by [daemon.devin](https://github.com/daemondevin).

## License

* Portable application code released under [the MIT license][L1].
* The Discord [EULA][L2].

 [L1]: https://raw.githubusercontent.com/daemondevin/DiscordPortable/master/LICENSE
 [L2]: https://raw.githubusercontent.com/daemondevin/DiscordPortable/master/App/AppInfo/EULA.txt
