# ADR 0004: Turn implementation and playtesting roadmap

## Status

Accepted as a roadmap. Individual gameplay-rule changes require project-owner approval.

## Goal and baseline

Build on the accepted [3D vertical slice](0003-initial-3d-board-vertical-slice.md) to
complete the mouse-centric turn interactions and play complete games. Setup,
reinforcement, combat rounds, occupation, reorganization, turn progression, and victory
already have domain/application implementations; extend and validate them rather than
rebuilding them.

Follow [the architecture](../architecture.md): presentation displays snapshots and sends
intent through the application; the domain determines legality and owns game state.
Developer tools remain separately gated and normal gameplay remains available in dev mode.

## Progress

Complete the stages in order. Add focused tests and run relevant existing tests at each
stage; pause for project-owner acceptance before proceeding. Mark a stage complete only
after its acceptance criteria are met, and record decisions and outstanding issues here so
a future session can resume at the first incomplete stage.

- [x] Step 1: Resolve the combat-rule discrepancy.
- [x] Step 2: Contextual attack selection.
- [x] Step 3: Combat decisions and feedback.
- [x] Step 4: Occupation and reorganization.
- [x] Step 5: Complete-game flow.
- [ ] Step 6: Playtesting and refinement.

## Plan

### Step 1: Resolve the combat-rule discrepancy

The original implementation left defeated cities unoccupied and allowed attacking with
the entire source garrison. The owner initially chose to preserve that behavior, then
approved the revised [risk-style rules](../game_rules.md): attacks must leave a unit
behind, and surviving committed attackers automatically capture a defeated city.

**Progress:** The revised combat behavior is implemented and accepted by the project owner.
The advanced rules remain out of scope.

### Step 2: Contextual attack selection

Right-click an eligible source and choose Attack, highlight legal enemy targets, and select
one on the board. Obtain legality from the application/domain. Preserve cancellation and
existing controls until the replacement is accepted.

**Acceptance:** Legal targets are apparent and invalid selections cannot initiate combat.

**Progress:** Implemented and accepted by the project owner. Existing sidebar combat and
occupation controls and the original attack selection remain available while the new
interactions are developed. Remove the original attack path once its contextual replacement
is complete and accepted, without losing occupation functionality.

### Step 3: Combat decisions and feedback

Prompt attacker and defender for commitments near the target; resolve the round and show
temporary, appropriately colored losses over the cities. Keep rolls and results accessible,
refresh the board and HUD, and safely handle cancellation and stale decisions.

**Acceptance:** Both players can complete successive combat rounds and understand the
outcomes.

**Progress:** Implemented and accepted by the project owner. The contextual prompts use
existing combat rules; the legacy attack and occupation controls remain available.

### Step 4: Occupation and reorganization

Add contextual occupation of empty cities using the agreed rules. Add contextual source and
destination selection and unit transfer for reorganization, including controlled routes and
optional abandonment.

**Acceptance:** Both phases work through the board with clear legal-target feedback and
reliable phase-ending controls.

**Progress:** Implemented and accepted by the project owner. Contextual occupation
preserves the current rule requiring a unit to remain at the source. Reorganization supports
controlled routes and warns before abandoning a source. Legacy controls remain available.

### Step 5: Complete-game flow

Review setup, zero-reinforcement turns, player handoffs, victory display, and starting
another game. Retain the current win criteria unless a playtest exposes a rule decision
requiring owner approval.

**Acceptance:** Two players can complete multiple turns and reach a clearly presented game
result.

**Progress:** Implemented and accepted by the project owner. A game-over action returns
to a fresh start menu. Tests cover turn handoffs, zero reinforcements, both victory orders,
and starting another game. Initial reserve placement also has a contextual action.
Existing rules can leave a stalled position: a player with one
unit and no controlled center cannot reinforce or occupy an empty city, even after the
opponent has no units. Resolving this requires a separate game-rule decision.

### Step 6: Playtesting and refinement

Run the consolidated tests and play complete games. Use developer mode to exercise difficult
scenarios. Record usability and balance observations, rule ambiguities, and possible HUD
improvements; review findings with the owner before changing rules or expanding scope.

**Acceptance:** The owner reviews the playtest findings and decides the next priorities.

## Scope

Advanced rules, final artwork, terrain, and a build pipeline are outside this roadmap.
