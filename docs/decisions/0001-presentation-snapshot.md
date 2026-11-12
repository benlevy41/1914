# ADR 0001: Presentation snapshots

## Status

Accepted

## Context

The presentation layer needs game and map information for rendering, but should not depend on mutable domain objects. A future 3D board should be replaceable without requiring changes to game rules or knowledge of domain internals.

## Decision

- `GameApplication.get_view_snapshot()` returns a detached `GameViewSnapshot` for the current game, or `null` when no game is active.
- The snapshot contains display-ready player, city, connection, phase, turn, winner, and developer-mode information. City geography is provided as latitude and longitude, and connections reference city IDs. It is a read model, not authoritative state.
- Presentation sends state-changing requests through `GameApplication`. After a successful request, it fetches a fresh snapshot and updates the screen and board.
- No push notification mechanism is introduced for the current synchronous game. Future asynchronous changes may signal that a snapshot is stale; presentation should then fetch a new snapshot.

## Consequences

Presentation can render the board without receiving `GameState` or map-definition objects. The application remains responsible for translating authoritative state into display data. New UI needs should extend the snapshot only with information that presentation must display; action legality remains with application/domain validation.
