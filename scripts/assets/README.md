`mini-desk-pwa-icon-512.png` is the original Mini Desk PWA icon from
`public/icons/icon-512.png` in https://github.com/xiangjianan/mini-desk,
reference commit `dc13c6cd3db0b863cec523a6dc9fb3f0717bfc10`.

This source is retained as the previous pixel-cat artwork. The current app icon
uses Apple's `desktopcomputer` SF Symbol, matching the pairing screen.

Regenerate the current 1024px opaque iOS icon:

```sh
swift scripts/make-icon.swift MiniDesk/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```
