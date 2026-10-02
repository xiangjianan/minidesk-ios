# App icon artwork

`minidesk-gradient-source.png` is the current artwork, generated with the built-in imagegen tool on 2026-10-02. The user's Telegram icon screenshot was used as a style reference: white surround, blue/violet/pink gradient circle, and a simple white central symbol. MiniDesk uses its own desktop-computer silhouette.

Export the source to an opaque 1024px iOS icon:

```sh
swift scripts/make-icon.swift MiniDesk/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Generation prompt

Use case: logo-brand. Create a production-ready MiniDesk iOS app icon, square 1024x1024 full-bleed opaque white canvas. The attached screenshot is STYLE REFERENCE ONLY: borrow its clean white surround, large vivid circular gradient from electric blue at lower-left through violet to pink/coral upper-right, and bold simple white center symbol. Replace the paper airplane with an ORIGINAL clean white desktop computer silhouette: rounded rectangular monitor frame with a transparent/open inner screen showing the gradient through it, plus a short centered stem and modest rounded base. Use a strong, instantly readable monitor outline, balanced geometry, no fine details. Gradient circle centered occupying about 86% of canvas; computer centered within it occupying about 55% of canvas width. Slight luminous gradient polish, predominantly flat crisp design. White canvas reaches every edge: do NOT bake rounded outer app corners into image, iOS applies its own mask. No text, no Telegram mark, no phone screenshot, no wallpaper, no drop shadow outside icon, no mockup, no extra glyphs. Export one finished icon.

## Previous artwork

`mini-desk-pwa-icon-512.png` is retained as the earlier Mini Desk PWA pixel-cat artwork from `public/icons/icon-512.png` in https://github.com/xiangjianan/mini-desk (reference commit `dc13c6cd3db0b863cec523a6dc9fb3f0717bfc10`).
