# Apartment runtime validation

Validation date: 2026-07-30  
Engine: Godot 4.4.1, Compatibility renderer  
GPU: NVIDIA GeForce RTX 4060 Ti

## Automated runtime pass

Command-line foundation and complete-project suites both passed:

- `DENIS_FOUNDATION_TESTS_OK`
- `DENIS_COMPLETE_PROJECT_TESTS_OK`

The pass exercises the complete coffee route, physical faucet-to-kettle overlap,
delivery pickup, laptop and TV interactions, private-room and wardrobe doors,
all kitchen doors/drawers/fridge parts, carried liquids, Rita access, and
startup stability.

Environment-specific regression checks additionally verify:

- a 1.35 m corridor runner/clean strip;
- physical player-volume clearance at eight points through the corridor;
- the curated imported-prop set and its critical instances;
- the refrigerator approach and L-counter continuity;
- no decoration in the faucet overlap or coffee placement zones.

## Performance

The graphical benchmark sampled 300 frames after a 90-frame warm-up:

- average: **170.10 FPS**;
- longest sampled frame: **8.51 ms**;
- imported scene instances: **15** from 12 selected source models;
- environment detail roots: **6**.

No comparable pre-pass benchmark was captured, so a before/after delta is not
invented. The post-pass result is comfortably above the 60 FPS gameplay target.

## Visual review

The evidence captures were rendered by the real game executable. They confirm
the widened continuous corridor, usable L-kitchen, side-wall refrigerator,
logical lived-in detail in every existing zone, and a clear coffee route.
Thin background props have no collision; large existing furniture retains its
simple collision.

