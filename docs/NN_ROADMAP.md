# Nosy Neighbors — Roadmap

A separate franchise from Selfie Social Society. This Godot client is the
*live game-show party* game: it exists for moments where timing fairness
matters, which nothing else can adjudicate. Netfox rollback is the entire
reason this franchise exists — every feature below should earn its place
by needing it.

Build order is deliberate: each phase reuses the previous phase's machinery.

## Phase 1 — Scaffold (done)

- [x] Coin-head neighbor avatar from primitives, runtime animation library
- [x] Floating "Neighbor <id>" labels + `set_display_name()` hook
- [x] Mobile touch controls (joystick, jump/run, drag-look)
- [x] Studio lot welcome sign, franchise branding, buzzer icon

## Phase 2 — Nosy Neighbors: Live Edition (shipped 2026-09-29)

The Family Feud-style one-on-one, live. Why Godot: **buzz-in timing**.
Netfox's rewound tick is the referee for "who buzzed first" — no arguments.

- [x] Host-authoritative state machine (`scripts/gameshow/nosy_neighbors.gd`):
      IDLE → ROUND_INTRO → FACEOFF → FACEOFF_RESULT → FACEOFF_ANSWER →
      FACEOFF_ANSWER2 → CONTROL → STEAL → ROUND_END → SHOW_END, 3 rounds/show.
- [x] Rollback-fair buzzer: `PlayerInput.buzzer_input` (B key / BUZZ button) is a
      rollback-synced input; the host records the true tick of each press inside
      `Player._rollback_tick` and resolves after a 45-tick grace window so late
      inputs still land. Anti-mash: presses must start during the buzz window.
- [x] 6 neighborhood survey questions in `data/survey_questions.json`; fuzzy
      answer matching (exact + Levenshtein ≤ 2) in `SurveyData`.
- [x] Contestants teleported to stage podiums and movement-locked; host is MC.
- [x] "Nosy Bot" fills the second podium when only one human shows up (buzzes on
      a random tick, answers with 65% accuracy) — the show is testable solo.
- [x] Fast Money endgame (shipped 2026-09-29): after 3 rounds the leader plays
      5 rapid questions on a 20-second clock, then the trailer plays the same 5
      with 25 seconds and duplicate answers buzz out. FM points add to round
      totals; highest total wins the show.
- [x] Game-show HUD (`scenes/gameshow/nosy_neighbors_ui.tscn`): question board,
      scores, strikes, status line, BUZZ button, answer entry, host Start button.
- [x] 3D stage in the plaza: two podiums + big "NOSY NEIGHBORS!" board.

## Phase 3 — Party board mode

The Mario Party night with real friends.

- Board as a synced node path; dice rolls from the host's RNG (seed broadcast once).
- Rollback resolves trap/steal timing disputes; host authority prevents
  coin-count editing.
- Port the twitchy minigames first (the slow/turn-based ones don't need this client).

## Phase 4 — Tag on the studio lot

- One player is "it" (host-assigned, timed rounds).
- Rollback settles every "I tagged you!" dispute — the purest demo of why
  this franchise exists.
- Hide-and-seek variant: seekers are NPCs with simple wander AI, hiders use
  the 2D-sprite trees for cover.

## Phase 5 — Whirl of Resources: Live Edition

- The wheel, live: spin timing and wedge resolution by rewind.
- "GIVE THE WHIRL A TWIRL!" with real stakes.

## Phase 6 — Fishing derby

- Timed tournament; biggest-catch and first-catch resolved by rewind.
- Needs the pond: new world zone or a separate derby scene.

## Deliberately not here

- **Low-latency music jamming** — audio doesn't rewind; rollback can't fix
  ears. Loop-trading over the host clock only.
- **House building / decorating** — low timing pressure, belongs in a cozy client.
- **Chat** — a realtime DB already does this well; this client stays lean.

## Export targets

- Desktop (Linux/macOS/Windows) for development and big-screen events.
- **Android** for the family phones — add the Android export preset once the
  first real game (Phase 2) is playable; needs export templates + keystore.
- The `NN Linux Server` preset builds the dedicated server for large events.
