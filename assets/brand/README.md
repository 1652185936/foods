# Ordin app icon

`ordin-app-icon-v1.png` is the raster brand master used by the native app
targets. It was created with the built-in image generation tool for this
project. There is no vector source, and this repository does not claim one.

## Source and colors

- Raster master: `assets/brand/ordin-app-icon-v1.png` (1254 x 1254, opaque RGB)
- Launch and adaptive background: `#FCF8EE`
- Primary dark green reference: `#1F4A32`
- Tomato reference: `#C14238`
- Grain yellow reference: `#E2B54C`
- Android monochrome layer: white alpha mask, tinted by the launcher

The master already keeps the food-and-clock mark away from the outer edge.
Android adaptive foregrounds shrink it further to about 57% of the full layer
width so circular and squircle masks do not clip the mark.

## Regeneration

The checked-in platform assets are deterministic derivatives. From the
repository root, run:

```powershell
pwsh -File assets/brand/generate_platform_assets.ps1
```

The script uses `ffmpeg` with Lanczos scaling and a fixed warm-white key
(`0xFCF8EE`, similarity `0.10`, blend `0.04`). It creates Android density
assets, opaque iOS/macOS app icons, transparent launch marks, and the PNG
frames packed into the multi-size Windows ICO. The current derivatives were
generated with ffmpeg 8.1.1.

Do not resize the platform files by hand. Replace the raster master with a new
versioned file and update the script deliberately when the brand artwork
changes.
