# Suppose sticker artwork

Generated with the built-in image generation tool on September 7, 2026. The
source illustration is preserved in `artwork.png`. The hex geometry, cream
wordmark band, and Avenir Next Bold lettering follow the existing Graft and
Tempest stickers. `render.py` is adapted from Tempest's renderer, with explicit
artwork size and vertical position controls.

The mascot is a curious fox watching dandelion seeds drift along different
paths. The palette uses cinnamon orange, cream, lavender, and dark aubergine.
The artwork is illustrative; the paths do not encode quantitative probabilities.

Style references inspected locally:
- `../graft/tools/hex-sticker/artwork.png`
- `../graft/man/figures/hex-sticker.png`
- `../tempest/tools/hex-sticker/artwork.png`
- `../tempest/man/figures/hex-sticker.png`

These paths are relative to the Suppose project root.

## Generation prompt

Use case: logo-brand
Asset type: square source illustration for the Suppose R package hex sticker.
Input images: Image 1 is the Graft frog artwork, Image 2 is the Tempest storm-petrel artwork. Both are style references only. Match their confident dark outlines, vivid controlled colors, flat illustrative shapes, charming expressive animal mascot, subtle hand-drawn finish, and clarity at a printed size of two inches. Create a new original subject.
Primary request: a thoughtful, curious red fox carefully holding a dandelion seed head and watching a few seeds drift along distinct graceful paths. This evokes expressing a belief, exploring possible consequences, and looking carefully at what happens.
Subject: one endearing cinnamon-orange fox, seated in three-quarter view with a slight inquisitive head tilt, large alert ears, bright dark eyes, warm cream cheek and chest markings, a generous curled cream-tipped tail. One visible front paw gently holds the slim green dandelion stem; the other rests naturally. It gazes toward three clearly separated floating dandelion seeds. Draw the dandelion head simply and boldly enough to read small; each drifting seed has a fine stem and a recognizable little parachute tuft. Three subtle curved breeze strokes suggest distinct possible paths, with no arrows or chart axes.
Composition: square full-bleed illustration, no hexagon or border. Center the fox in the upper-middle, fox face around 40 percent image height, seed head to its right and floating seeds above. Keep all important anatomy, seed head, drifting seeds and tail comfortably within the central 70 percent width and between 17 and 72 percent height so a later point-up hex crop and bottom wordmark will not cut them off. Keep the bottom 24 percent quiet with only background; all corners contain only background. The silhouette must remain instantly legible at small size.
Palette: warm rust and cinnamon orange fox, cream accents, deep aubergine outlines, a flat softly saturated pale lavender background, restrained leafy teal and golden accents. Match the polish and boldness of the two family references, while retaining this distinct palette.
Constraints: NO TEXT, no letters, no numbers, no logo, no label panel, no hexagon, no border. No clothes, no spectacles, no laboratory equipment, no other animals. No photorealism, no 3D, no gradients, no drop shadows, no faux paper texture. One clean cohesive composition with generous simple shapes.

## Framing refinement

The following edit was applied to the initial generated illustration:

Use case: precise-object-edit. This is the source artwork for an R package hex sticker. Change ONLY the composition and framing of this exact illustration. Preserve the same fox character, pose, expression, anatomy, orange and cream colors, dandelion, three seeds, lavender background, dark outlines and drawing style.
Reduce the entire fox and held dandelion slightly so its ears, paws and full tail fit comfortably between 16 percent and 74 percent of the square image height and between 23 percent and 77 percent of its width. Move the three floating seeds down and left, closer to the dandelion: all seed tufts and breeze lines must fall within 20 to 37 percent image height and 60 to 78 percent image width. Keep them clearly separated, natural and readable. Leave the bottom 25 percent as uninterrupted lavender background. Keep the original full-bleed lavender background filling the entire square. No rectangular inset, no visible frame, no added objects, no text, no hexagon, no border. The result should feel like the exact same illustration with more breathing room, composed to survive a point-up hexagonal crop and a wordmark across the lower portion.

## Render

From the project root, with Python, Pillow, and Avenir Next installed:

```sh
python3 tools/hex-sticker/render.py \
  tools/hex-sticker/artwork.png suppose man/figures/hex-sticker.png \
  --ink '#3b163f' --art-size 2000 --art-y -200
```

The script writes `man/figures/hex-sticker.png` at 1600 x 1848 pixels and
`man/figures/logo.png` at 400 x 462 pixels. Both have transparent corners.
A different bold font can be supplied with `--font` and `--font-index`.

The finished hex and README-size logo were visually reviewed for complete ears,
tail and seeds, continuous borders, and legible lowercase lettering.

