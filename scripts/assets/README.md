`mini-desk-pwa-icon-512.png` is the original Mini Desk PWA icon from
`public/icons/icon-512.png` in https://github.com/xiangjianan/mini-desk,
reference commit `dc13c6cd3db0b863cec523a6dc9fb3f0717bfc10`.

Generate the 1024px opaque iOS icon without smoothing the pixel edges:

```sh
swift scripts/make-icon.swift MiniDesk/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```
