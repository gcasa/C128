# C128 icon

Created with the built-in image generation tool. The source is `AppIcon.png`,
with transparent margins. GNUstep uses this PNG directly. Cocoa Makefile and
Xcode builds use `AppIcon.icns`, containing 16–1024 pixel representations.

Regenerate the ICNS on macOS with `sh tools/build-icon.sh` after updating the
PNG. The Makefile regenerates it automatically when the source changes.

## Generation prompt

Use case: stylized-concept. Asset type: native desktop application icon, square 1024x1024. Create a polished distinctive icon for a Commodore 128 emulator. A sculpted slim ivory Commodore 128 style wedge computer keyboard in the foreground with charcoal gray keys and a distinct separate numeric keypad on the right; behind it a compact charcoal CRT screen displaying only large crisp mint-green pixel numerals "128" and a small block cursor. Bold simplified geometry readable at small Dock sizes, subtly dimensional tactile cream plastic, green phosphor screen glow. Centered unified composition on a rounded-square deep forest-green tile with subtle highlights. Entire icon fully within canvas with a small genuinely transparent outer margin, preserve alpha outside rounded square. Straight-on slightly elevated view, keyboard and monitor fill the tile. Premium classic desktop icon finish. No extra words, no watermark, no scenery, no tiny labels. Emphasize the slim angular C128 keyboard profile, not the rounded C64 breadbin.
