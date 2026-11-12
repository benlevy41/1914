# ADR 0003: Initial 3D board vertical slice

## Status

Accepted

## Goal

Transition the 2D prototype toward a restrained 3D tabletop presentation through a small, testable sequence of presentation-layer changes. Each step ends with user acceptance testing, and work pauses for feedback before the next step begins.

## Plan

### Step 1: Establish the 3D board presentation seam

**Goal:** Add a 3D board scene within the existing game screen while preserving the presentation-to-application boundary and current game-start flow.

**Success criteria:** The board scene can be opened in the running game and displays a flat placeholder board from a fixed angle. It receives display data through the existing game-view snapshot, and user intent continues to be handled through the existing application workflow. No application, domain, or infrastructure changes are needed. The project owner accepts the scene scale and initial framing before proceeding.

### Step 2: Render the map and tabletop pieces

**Goal:** Display the full map using geographic positions, placeholder roads and cities, and visible unit representations derived from the snapshot.

**Success criteria:** All cities and connections appear in the expected geographic arrangement, with road endpoints aligned to city anchors. City ownership and garrison size are distinguishable, and occupied cities display the corresponding number of unit placeholders without overlapping so badly that counts are unclear. Placeholder geometry is sufficient; final art and terrain are out of scope. The project owner accepts the map layout and visual scale before proceeding.

### Step 3: Add board navigation and selection

**Goal:** Make the 3D board practical to inspect and interact with using the documented fixed-angle, mouse-first controls.

**Success criteria:** Scroll input zooms within reasonable limits, WASD pans without losing the board, and camera rotation remains fixed. Clicking a city selects it and provides immediate, clear visual feedback; the selected city ID is communicated to the existing screen controller. The project owner accepts camera behavior and city selection before proceeding.

### Step 4: Add the minimal gameplay HUD

**Goal:** Keep the board primary while exposing only the information and controls needed for the current decision.

**Success criteria:** The active player and phase are apparent, selected-city details are contextual, and only the relevant phase action is prominent. The HUD supports placing a reinforcement through the existing application operation and displays updated state from a newly fetched snapshot. Existing game rules and action validation remain unchanged. The project owner accepts information hierarchy and interaction flow before proceeding.

### Step 5: Validate the vertical slice and review direction

**Goal:** Verify one complete interaction path and use it to decide what to refine next.

**Success criteria:** From quick start, a player can select a legal reinforcement city, place a reinforcement, and see the updated garrison on the 3D board. Focused presentation tests cover the board’s snapshot rendering, selection feedback, and this action path; the existing consolidated tests pass. User acceptance testing reviews readability, camera feel, ownership and unit cues, and the balance between persistent and contextual UI. Record resulting decisions and any follow-up scope before further 3D work.

## Consequences

The sequence limits investment in models, terrain, and broader UI restructuring until the core board presentation and interaction have been reviewed. The existing 2D board and game logic provide a working reference for behavior, while the 3D board remains a replaceable presentation component.
