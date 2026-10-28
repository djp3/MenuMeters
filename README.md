# MenuMeters: fixed for macOS 27.2 (unofficial)

This is an unofficial fork of [yujitach/MenuMeters](https://github.com/yujitach/MenuMeters), for one reason: MenuMeters 2.1.6.1 crashes at launch wherever `/var/run/pppconfd` is missing, the socket its network meter asked for PPP status. So far that's macOS 27.2, Sequoia 15.8.2 and a Sonoma beta ([yujitach/MenuMeters#324](https://github.com/yujitach/MenuMeters/issues/324), [#325](https://github.com/yujitach/MenuMeters/issues/325), [#326](https://github.com/yujitach/MenuMeters/issues/326), [#327](https://github.com/yujitach/MenuMeters/issues/327)).

**Do you need it?** If 2.1.6.1 still starts on your Mac, no. To check, run this in Terminal; "No such file or directory" means your Mac is affected:

```bash
ls -l /var/run/pppconfd
```

What's different from 2.1.6.1:

- **It starts without pppconfd.** The fix is Alexander Botev's, [posted in yujitach/MenuMeters#325](https://github.com/yujitach/MenuMeters/issues/325#issuecomment-6178898754), and is his commit here.
- **A ppp interface, such as an L2TP VPN, should still be counted,** from the system's own traffic counters, as every other interface is. That hasn't been tried with a VPN. Without pppconfd, a PPP service's status line and its Connect and Disconnect menu items aren't shown.
- **It builds with Xcode 27**, for Intel and Apple silicon, and needs macOS 12 or later. On macOS 11 or earlier it won't open; 2.1.6.1 is the one to use there.
- **It also carries upstream's own changes made after 2.1.6.1, which were never released** (November 2021 to March 2022): a Turkish translation, a French fix, a change to how the login item is found ([yujitach/MenuMeters#282](https://github.com/yujitach/MenuMeters/issues/282)), building on older SDKs, and a check for whether macOS has hidden the menu item for lack of space (its alert is shown by this build, which includes Sparkle). [The full list](https://github.com/yujitach/MenuMeters/compare/2.1.6.1...e91b746).
- **It updates itself from this fork's releases.** It's signed with a Developer ID and notarized by Apple, and Sparkle checks the [releases of github.com/djp3/MenuMeters](https://github.com/djp3/MenuMeters/releases) for new builds.

It has been tried only on macOS 27.2, on an Apple silicon Mac.

The same fix is offered upstream as [yujitach/MenuMeters#328](https://github.com/yujitach/MenuMeters/pull/328). Once upstream ships a fix, use that, and this fork will be archived.

## Download and install

Download the newest **MenuMeters-<version>.zip** under Assets on the [Releases](https://github.com/djp3/MenuMeters/releases) page (not "Source code"). The app is signed with a Developer ID and notarized by Apple, so it opens without warnings.

1. Quit MenuMeters if it's in your menu bar.
2. Double-click the zip to unzip it, if your browser hasn't already.
3. Drag **MenuMeters** into your **Applications** folder, replacing the old copy. Your settings stay as they were, though macOS may ask again before MenuMeters can open Activity Monitor.
4. Open it from Applications. From then on it offers new builds itself, through Sparkle.

## Build it yourself

With Xcode 27, run `./build-release.sh`. It archives the "MenuMeters" scheme, signs the app with the Developer ID of team 9B6T3L36ML through `exportOptions.plist`, notarizes and staples it, zips it with THIRD-PARTY-NOTICES.md into `build/release/MenuMeters-<version>.zip`, and writes the Sparkle appcast for every release so far next to it. `./build-release.sh --publish` then tags `v<version>`, pushes to the `djp3` remote and creates the GitHub release with both files attached; `./build-release.sh --no-notarize` makes a local test build. The version is `MM_VERSION` in `InfoPlistPreprocessor.h`, and the release notes, shown both on GitHub and in Sparkle, are `release-notes/<version>.md`. The script's header lists what it needs.

## Changes in this tree

Dated, as the GNU General Public License asks; each changed source file also carries its own note.

- 2026-10-14, Alexander Botev: MenuMeters starts when pppconfd is missing (MenuMeterNetConfig.m, MenuMeterNetExtra.m, MenuMeterNetStats.m).
- 2026-10-27, Joe Moreno: without pppconfd, ppp interfaces count as up (MenuMeterNetConfig.m) and are counted from the sysctl counters (MenuMeterNetStats.m); `(void)` prototypes so it builds with Xcode 27 (smc_reader.m, applesilicon_hardware_reader.m); in MenuMeters.xcodeproj/project.pbxproj, a deployment target of macOS 12.0 in all four target configurations and both architectures in the No Sparkle target's Release; the third-party notices, in THIRD-PARTY-NOTICES.md and the two hardware readers; version 2.1.6.2 (InfoPlistPreprocessor.h); this README section; and build-release.sh.
- 2026-10-27, Don Patterson: Sparkle checks this fork's GitHub releases for updates and verifies them with its EdDSA key (MenuMetersApp/AppDelegate.m, MenuMeters-Info.plist; the DSA key file dsa_pub.pem is gone, from MenuMeters.xcodeproj/project.pbxproj too); version 2.1.6.2-djp3.1 with build number 2.1.6.2.1 (InfoPlistPreprocessor.h); build-release.sh signs with a Developer ID, notarizes and publishes, with exportOptions.plist, scripts/appcast.py and release-notes/; this README.

## Support and license

There's no support: it's offered as is, with no warranty, under the GNU General Public License version 2, like MenuMeters itself (see [LICENSE](LICENSE)). MenuMeters is Copyright (c) 2002-2014 Alex Harper, and its later contributors. The third-party code it contains is listed, with its licenses, in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Issues are turned off here. If you find a problem in MenuMeters itself, report it on MenuMeters' [issues page](https://github.com/yujitach/MenuMeters/issues) and say you were using this unofficial build.

---

*Upstream's README follows.*

# MenuMeters
My fork of MenuMeters for El Capitan, Sierra, High Sierra, Mojave, Catalina and Big Sur.

# Usage:
If you just want to use it, please go to http://member.ipmu.jp/yuji.tachikawa/MenuMetersElCapitan/ or https://github.com/yujitach/MenuMeters/releases and download the binary. The detailed installation instruction is given in the former.

# Other versions & related open source softwares:

If you run sufficiently new mac OS, try one of

- https://github.com/exelban/stats
- https://iglance.github.io
- https://github.com/gao-sun/eul

which are all menubar monitors with more modern look and feel and more capability. What is more, they are maintained actively. They are heavily recommended.

There are also further forks of my version of MenuMeters, which implement more features. You might want to try them out:

- https://github.com/emcrisostomo/MenuMeters which has DMG installers 
- https://gitlab.com/axet/MenuMeters which has new features in the CPU meter, etc.

If you'd like your version mentioned here, please tell me at the issues page.

# Background:

It's a great utility originally developed at http://www.ragingmenace.com/software/menumeters/ .
The original version does not work on El Capitan and later, due to the fact that SystemUIServer doesn't load Menu Extras not signed by Apple any longer.

I'm making here a minimal modification so that it runs as a faceless app, putting NSStatusItem's instead of NSMenuExtra's.
Since then, many people contributed pull requests, most of which have been incorporated.

More recently, starting from Catalina, MenuMeters was changed from a preference pane within System Preferences to an independent app. This is due to an increasing amount of security features imposed by Apple on preference panes running within System Preferences, which made it too cumbersome to develop MenuMeters as a preference pane.

# To hack:
Clone the git repo, open MenuMeters.xcodeproj, and build the target *MenuMeters*. This will create an independent app which runs outside of System Preferences. 
