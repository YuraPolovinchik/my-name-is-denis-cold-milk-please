# Interior art pass — 28 September 2026

The authoritative target is the Godot Compatibility renderer used by the static GitHub Pages WebGL build. The optional desktop Forward+ launcher is supplementary.

## Result

- 26 original Blender GLB types are generated deterministically by `tools/build_interior_artpass.py`. The final pass adds a console, shoe bench, sneaker, washer cabinet and sleeping Rita portrait.
- The room pass places 34 detail model instances and rounds 279 visible rigid details while keeping the underlying physics bodies and interactions. The restart check retains 283 collision shapes across two scene loads.
- The bathroom and hall mirrors now use framed light silver surfaces that remain legible in Compatibility. They are static surfaces; the Web build does not provide planar reflections.
- The entry receives a ceiling practical so its furniture and exit remain legible. The secret payment room was inspected in Chromium and retains its deliberately saturated theatrical treatment.
- The generated `dist/web` is the deployable artifact. GitHub Pages uploads this directory; it does not rebuild Godot sources. `index.pck` is 93,933,184 bytes, below GitHub's 100,000,000 byte per-file limit. The build script and workflow enforce this decimal limit.

## Verification

- Godot 4.4.1 complete foundation tests: `DENIS_FOUNDATION_TESTS_OK`, `DENIS_COMPLETE_PROJECT_TESTS_OK`.
- Two-load interior test: `INTERIOR_RESTART_TEST_OK`; 34 room models, 279 rounded objects, 283 collision shapes on each load.
- Real Chromium/WebGL 2.0 Compatibility captures: bedroom, bathroom, entry, payment altar. Each reached `WEB_ROOM_CAPTURE_READY` without browser console warnings or errors.
- `git diff --check` clean.

The headless foundation test still emits the project's existing ObjectDB leak warning on exit. The static mirrors and stylized characters are deliberate Web performance compromises; this pass should not be represented as photorealistic AAA art.
