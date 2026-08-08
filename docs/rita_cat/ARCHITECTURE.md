# Rita cat architecture

`RitaCat` is a replaceable character scene. Its imported Kenney model is only a
visual child; gameplay is split into BODY STATE, INTENTION and story direction.

- `CatBodyController`: physical pose and locomotion only.
- `CatIntentionController`: reason for the current behaviour only.
- `CatStoryDirector`: context gates, calm windows, helpful behaviour and one active story.
- `CatStoryDeck`: 2–4 cards, at most one card from each category, no replay in a run.
- `CatChaosObserver`: event-driven updates plus a low-rate 0.5 s safety sample.
- `CatRelationshipMemory`: trust, interest, wariness and interaction history.
- `CatStuckRecovery`: route rebuild after three seconds without progress.
- `CatDebugPanel`: developer-only `--cat-debug` overlay; absent in normal play.

All eight stories inherit `CatStory` and implement eligibility, telegraph,
development, resolution and cleanup independently. Critical object changes are
temporary: laptop metadata and vacuum processing are restored in `cleanup`, and
the spoon has checked recovery anchors plus a visible safety return.

The cat exposes `get_save_data()` and `load_save_data()` for the deck and hidden
relationship memory. The current project has no general mid-run save-game
orchestrator, so these hooks are ready for that system rather than writing a
second private save file.
