# App icon artwork

`minidesk-midnight-source.png` is the current artwork, generated with the built-in imagegen tool on 2026-10-02. The user's dark icon screenshot was used as a style reference: white surround, midnight navy circle, restrained stars, and a white desktop-computer silhouette. The screenshot's lock badge and caption are excluded.

Export the source to an opaque 1024px iOS icon:

```sh
swift scripts/make-icon.swift MiniDesk/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Generation prompt

Use case: logo-brand. Produce one finished MiniDesk iOS application icon, square full-bleed opaque white 1024x1024 canvas. Image 1 is a STYLE REFERENCE ONLY: borrow its white surround, large dark navy circular field, small tasteful twinkling stars, and strong white central symbol. Replace its airplane with an original white desktop-computer mark: clean rounded rectangular monitor outline, open inner screen showing the dark navy field, short centered stem and modest rounded base. The computer must be centered, simple, bold and readable at small app-icon sizes. Dark navy circle occupies 86% of square width, computer about 55% of square width. A handful of tiny white four-point star sparkles and quieter muted slate-blue diamond specks sprinkled in the negative space around the monitor; no stars inside the screen, no overlapping the computer. Restrained midnight palette, almost flat dark navy with an extremely subtle lighter upper-right gradient. Crisp edges and balanced minimalist geometry. White background reaches every edge, do not bake outer rounded corners or an outline into the asset (iOS applies its mask). No purple lock badge, no padlock, no Telegram logo, no airplane, no letters, no text including the Chinese caption, no app screenshot, no mockup, no external shadows. Export just the icon.

## Previous gradient prompt

Use case: logo-brand. Create a production-ready MiniDesk iOS app icon, square 1024x1024 full-bleed opaque white canvas. The attached screenshot is STYLE REFERENCE ONLY: borrow its clean white surround, large vivid circular gradient from electric blue at lower-left through violet to pink/coral upper-right, and bold simple white center symbol. Replace the paper airplane with an ORIGINAL clean white desktop computer silhouette: rounded rectangular monitor frame with a transparent/open inner screen showing the gradient through it, plus a short centered stem and modest rounded base. Use a strong, instantly readable monitor outline, balanced geometry, no fine details. Gradient circle centered occupying about 86% of canvas; computer centered within it occupying about 55% of canvas width. Slight luminous gradient polish, predominantly flat crisp design. White canvas reaches every edge: do NOT bake rounded outer app corners into image, iOS applies its own mask. No text, no Telegram mark, no phone screenshot, no wallpaper, no drop shadow outside icon, no mockup, no extra glyphs. Export one finished icon.

## Previous artwork

`minidesk-gradient-source.png` is retained as the earlier blue/violet/pink version.

`mini-desk-pwa-icon-512.png` is retained as the earlier Mini Desk PWA pixel-cat artwork from `public/icons/icon-512.png` in https://github.com/xiangjianan/mini-desk (reference commit `dc13c6cd3db0b863cec523a6dc9fb3f0717bfc10`).
