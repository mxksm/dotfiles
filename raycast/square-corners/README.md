# Square Raycast window corners

A small Raycast-only companion to Apple Sharpener. Sharpener excludes floating
panels, and Raycast supplies its own corner-radius implementation. This tweak
sets the native window/frame radius to zero. It leaves controls inside the
window unchanged and does not modify the Raycast app bundle.

## Install

Requires an existing working Ammonia/Sharpener installation and Xcode Command
Line Tools. From this dotfiles checkout:

```sh
bash raycast/square-corners/install.sh
```

Choose **Raycast → Quit Raycast** from the menu bar, then reopen Raycast.
Closing the launcher does not quit its process.

The tweak is restricted to the `Raycast` process through an Ammonia whitelist,
with an additional process-name check in its source. It always requests square
corners independently of Sharpener's radius setting. No macOS security settings
are changed by the installer.

## Remove

```sh
sudo rm /private/var/ammonia/core/tweaks/libraycast_square_corners.dylib
sudo rm /private/var/ammonia/core/tweaks/libraycast_square_corners.dylib.whitelist
```

Then quit and reopen Raycast. Apple Sharpener itself remains installed.

## Compatibility

Verified with Raycast 2.11.1.0 on macOS 26.6.2. Uses private AppKit
and Raycast selectors, so future updates may require adapting the tweak. Missing
selectors are skipped. Raycast itself retains its original signature and updater.
