# Rita cat final integration verification

Date: 2026-08-04. Engine: Godot 4.4.1, Compatibility renderer.

Three separate graphical, accelerated, end-to-end integration runs completed the real coffee route without `force_story`, `trigger_cat_*` or `debug_start_story`. They are automated graphical runs, not human play sessions. Raw reports are in `docs/evidence/rita_cat/balance_run_a.json`, `balance_run_b.json`, and `balance_run_c.json`.

- A / normal: 390.05 game seconds (32.47 wall seconds). Deck: PHONE_STORY, VACUUM_STORY. Both ran naturally and completed (`phone_found`, `startled`). Calm windows: 103.25 s and 101.96 s. Coffee route finished, Rita stayed asleep, no softlock.
- B / friendly: 390.02 game seconds (32.46 wall seconds). Deck: MUG_STORY, VACUUM_STORY. The first telegraph was safely cancelled by the real save/load check; MUG_STORY was prevented by interaction. Trust reached 76, the cat used closer calm behaviour and soft friendly vocal responses. Coffee route finished, no softlock.
- C / high chaos: 390.03 game seconds (32.48 wall seconds). Deck: LAPTOP_STORY, PAYMENT_ALTAR_STORY. No story started before chaos was cleared; 26 starts were refused by the chaos budget. Afterwards both stories completed naturally. The laptop unlocked, Payment restored its altar state, and the coffee route finished.

SaveManager checks passed through an actual `user://denis_quicksave.json` write/read:

- before a story: deck and safe position restored;
- during telegraph: story cancelled through cleanup and consumed once;
- after a story: completed cards persisted;
- after PAYMENT_ALTAR_STORY: it remained completed and did not repeat.

Confirmed fixes made during the pass:

- parked loose props and the hidden milk carton no longer explode/fall during scene startup;
- cat turns interpolate instead of snapping;
- trusted-cat calm following and soft vocal feedback make relationship changes observable;
- urgent events pause cat-story development instead of stacking consequences or restarting the same card;
- spoon clue, fallback reveal and 48-second recovery are reachable and one-shot;
- high-chaos recovery completes Rita's required demand before resuming the coffee route.

Performance (whole-run averages): no-active-cat baseline 189.58 FPS / 167 ms maximum sampled frame; A 191.70 / 148 ms; B 180.77 / 145 ms; C 179.21 / 157 ms. Because these are separate launches under variable desktop load, the differences are observational, not proof of cat CPU cost. No error or cat-specific frame-time spike was logged. Renderer was `gl_compatibility` in every run.

Final automated suite markers:

- `RITA_CAT_STORY_SYSTEM_TESTS_OK`
- `DENIS_FOUNDATION_TESTS_OK`
- `DENIS_COMPLETE_PROJECT_TESTS_OK`

Still requires human judgement: telegraph readability from ordinary player camera angles, perceived tail/eye nuance, subjective sound repetition, every spoon hide anchor from all approaches, and animation contact quality on every furniture edge.
