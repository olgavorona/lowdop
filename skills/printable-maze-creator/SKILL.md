---
name: printable-maze-creator
description: Create and revise Denny's Maze seasonal printable collections in this repository, including maze structures, themed artwork, color and black-and-white PDFs, website previews, ZIP packs, and Pinterest copy.
---

# Printable Maze Creator

Create calm, educational seasonal maze packs for children ages 2–6 by extending the existing generators.

## Product and copy

- Keep Denny the same recognizable red crab. Seasonal changes belong in clothing and accessories, not identity or proportions.
- Keep imagery friendly and low stimulation: no frightening details, violence, neon color, or clutter.
- Ship Easy, Medium, and Hard in color and printer-friendly B&W unless explicitly narrowed.
- Vary structures across wall mazes, recognizable silhouettes, wide corridors, collect tasks, and avoid tasks.
- Use a two-sentence Denny-centered setup, one concrete instruction, one accurate child-friendly fact, and one completion sentence.
- Make starts and goals visually clear. For a detached destination, use an endpoint dot and connector; do not add endpoint words unless requested.

## Pinterest is part of the deliverable

Create one Pinterest title and description for every maze and difficulty and save them with the collection.

- Title pattern: `<Difficulty> <Theme> Maze Printable for Kids`.
- Description: naturally include free printable, difficulty and theme, ages 2–6, preschool or kindergarten, quiet-use contexts, and pencil or crayon.
- Mention the actual task or distinctive structure. Keep entries readable and distinct instead of mechanically stacking keywords.

## Artwork

- When finished color pictures are requested, generate each reusable object separately as a transparent raster cutout using themed Denny as the style reference.
- Prompt for soft rounded 3D children's illustration, controlled saturation, clean silhouette, generous padding, no text, scenery, border, or watermark.
- Inspect before naming: parallel generation can return assets in a different order from the prompt list.
- Preserve the generated original, then copy the selected file into the collection. Normalize small printable objects to about 600 px before embedding.
- Keep B&W assets as crisp line art or deterministic SVG icons with minimal fill.

## SVG/PDF caveats

- Website previews display SVGs through HTML `<img>`. Relative PNG references inside those SVGs can disappear because of browser image-document isolation.
- Embed required raster artwork as `data:image/png;base64,...` in published SVGs. Directly open a published color SVG in Chrome to verify the pictures appear.
- Cache encoded bytes while generating, resize source icons first, and check output size; repeated full-resolution data URIs inflate the repository quickly.
- PDF conversion uses headless Chrome. A sandboxed run may exit `-6`; rerun the existing generator with required execution permission rather than altering PDF logic for that environmental failure.

## Maze caveats

- Add reusable masks in `content-generator/maze_generator.py` for missing silhouettes and inspect Easy and Hard.
- Use `render_style: "corridor"` for wide paths such as Acorn Shell. Place Denny and the goal in page coordinates so they do not cover the route.
- Avoid positions and obstacle identities are separate. Define an explicit render sequence when the requested ghost/bat mix matters.
- Scale obstacle art independently on dense Medium/Hard grids when default scaling makes it unreadable.
- Keep avoid obstacles off the solution and retain alternate routes.

## Website behavior

- Full Color is the default on Fall and Halloween collection pages.
- Keep synchronized Color/B&W controls in the global toolbar, every maze row, preview modal, and full-set area.
- Changing format anywhere updates all previews and individual, modal, and ZIP downloads.
- Put download buttons below the controls.
- Implement shared behavior in `site/src/components/PrintablesPage.astro` and verify both pages.

## Files and verification

- Generate under `content/printables/<collection>/`, then copy the complete result to `site/public/printables/<collection>/` after every regeneration.
- Update collection data, Astro route, printables index, and sitemap.
- Build separate B&W and color ZIPs for every difficulty and verify their contents.
- Inspect Easy/Hard and color/B&W PDFs, plus a color SVG directly in Chrome.
- Verify silhouette, endpoint, image scale, obstacle count/type, copy wrapping, source/public inventory, and unexpectedly large files.
- Run Python compilation, Astro check, production build, and `git diff --check`.
- Do not push or deploy without explicit approval.
