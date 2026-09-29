# Nosy Neighbors — Live Game-Show Party (Godot)

A separate franchise from Selfie Social Society: the **live game-show party**
game. Same coin-head neighbors, but this one exists for one reason — moments
where timing fairness matters and there's no arguing with the replay.

Built on [BatteryAcid's Godot 3D multiplayer template](https://github.com/BatteryAcid/godot-3d-multiplayer-template)
(MIT), which gives us:

- **Netfox rollback netcode** — rewinds time to fairly resolve "who did it first"
  (buzzers, tags, catches). This is the entire reason the franchise exists.
- **P2P hosting via Noray** — friends host rooms with no server bill.
- **Dedicated-server export** — for big events.

## The flagship: Nosy Neighbors — Live Edition

The Family Feud-style one-on-one, live on the studio lot stage:

- **Rollback-fair buzzer** — every contestant's buzz press is a rollback-synced
  input stamped with the shared tick clock. The host rewinds and crowns the true
  first presser, with a 45-tick grace window so late inputs still land. Presses
  must start during the buzz window (no pre-mashing); B key, on-screen BUZZ
  button, or touch button.
- **Host-authoritative show** — the room host is the MC: question/answer state
  machine (face-off → control → steal), 3 rounds per show, 6 neighborhood survey
  questions with fuzzy answer matching (typos forgiven).
- **Nosy Bot** — fills the second podium when only one human shows up, so the
  show is testable solo.
- **Fast Money endgame** — after 3 rounds, the leader plays 5 rapid questions
  against a 20-second clock, then the trailer plays the same 5 with 25 seconds
  and can't repeat answers. FM points add to the totals; highest total wins.
- **Studio lot stage** — two podiums and a big NOSY NEIGHBORS! board in the plaza;
  contestants are teleported in and movement-locked for the show.

## Also in the build

- **Neighbor avatars** (`scenes/player/sss_avatar.tscn`) — flat coin-disc head,
  flat-bottomed body, sphere hands with thumbs, wedge feet, built from primitives.
  Runtime-generated hover-bob, foot-plop walk, and squash-and-stretch jump.
- **Name labels** — every player gets a floating "Neighbor \<id\>" tag, with
  `Player.set_display_name()` ready for real names.
- **Mobile controls** — virtual joystick + JUMP/RUN buttons appear automatically
  on touch devices; drag the right side of the screen to look around.

## Run it

1. Open the project in **Godot 4.3+**.
2. Press **F5** (or run `scenes/game.tscn`).
3. Host a room, have a friend join, and the host hits **Start Show** (top right).

Buzzer key: **B**. Everything else is the on-screen UI.

## Roadmap

See `docs/NN_ROADMAP.md` — the party-game lineup this franchise grows into.
