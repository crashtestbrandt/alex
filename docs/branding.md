# Application artwork

- `assets/brand/icon.png` is the 1024 px application icon.
- `icon.icns` and `icon.ico` package the same artwork for macOS and Windows.
- `splash.png` is the transparent 384 px mark centered on the boot background.
- `project.godot` selects all four assets. The splash has no forced display delay.
- The artwork is limited to application identity and startup. In-app controls remain distance fields.
- The images were generated with the built-in imagegen tool from the owner's magnifying-glass/speech-bubble reference in issue #13's implementation request.
- PNG resizing used `sips`; native containers include multiple PNG resolutions.
- These assets use Git LFS. Run `git lfs pull` after cloning; CI fetches LFS during checkout.

## Generation prompts

Icon:

> Use case: logo-brand. Create the final square app icon artwork for a gentle language exploration app. Input image is a reference for the unified magnifying glass and speech bubble symbol, not an edit target. Preserve its instantly legible concept: a broad circular magnifier with short handle toward lower left overlaps a speech bubble whose tail points lower right, a short curved glint inside the lens. Refine this into a beautiful premium icon: sculpted smooth deep petroleum teal enamel, softly rounded edges and delicate restrained highlights, on a warm ivory full-bleed square background. A subtle soft contact shadow creates tactile depth. Minimal, calm, welcoming, precise silhouette, generous even padding but mark occupies about 70 percent of canvas. Keep inner lens ivory and open. No text, letters, extra symbols, borders or mockup. No outer rounded-square icon frame; OS applies its own mask. Produce one square 1024x1024 icon, not a presentation sheet.

Splash, using the generated icon as the edit target:

> Use case: background-extraction. Asset type: transparent splash screen logo. Keep this exact sculpted teal magnifying-glass/speech-bubble mark, its silhouette, proportions and subtle highlights. Remove the entire ivory background, including the ivory inside the lens and all the open spaces. Output the single isolated teal logo with actual alpha transparency on a square canvas, generously padded, no text or new elements. Preserve its elegant enamel material. Remove the background contact shadow; keep shading on the teal object itself. This will display centered at 320 px on a warm ivory boot screen.
