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

## Approved Step 3 amendment

The following changes supersede the fixed-rotation criterion above and identify updates to
the original visual design and user interface plans to incorporate after this vertical slice:

- **Visual design change:** Instead of one fixed camera angle at every zoom level
  ([visual design, section 3.2](../visual_design.md)), maximum zoom-out transitions to a
  centered top-down strategic view. When centered, the whole board fits in the viewport,
  including after resizing. Zooming in returns to the original angled view and selected-city/cursor-targeted
  zoom. Normal-view camera bounds remain unchanged; the strategic view may use a greater
  camera height to fit narrow viewports. Players may pan after the view is centered.
- **User interface change:** Left-clicking empty board space clears city selection and
  pending attack or reorganization choices, including an unresolved defender commitment.
  Completed game actions are not undone. This adds an explicit deselection interaction to
  the mouse-first and selection-feedback plans in [visual design, section 6](../visual_design.md)
  and the general interaction guidance in [user interface design](../user_interface.md).

## Approved Step 4 amendment

The following changes identify updates to the original visual design and user interface
plans to incorporate after this vertical slice:

- **Visual design change:** A top banner shows both leaders' names, controlled city counts
  and garrison totals, with the current player's flag and phase in the center. The German
  flag uses black, white and red horizontal stripes; the Allied flag combines the upper-right
  Union Jack and lower-left French tricolor across a diagonal.
- **User interface change:** During reinforcement, right-clicking a city opens a contextual
  one-unit placement action. An unavailable action is disabled and its reason appears in the
  sidebar. The existing controls remain for setup, attacks, reorganization and advancing
  a turn with no reinforcements. Developer actions appear separately in the same menu only
  in developer mode. The menu uses the application's read-only rule validation and the
  placement operation validates again before changing state.

The broader contextual attack workflow and presentation of combat losses remain future
work. This step does not change game rules or the current attack and occupation behavior.

## Step 5 validation and review

The automated presentation checks exercise quick start, city selection, and reinforcement
placement through mouse input, including board and HUD updates and the transition to attack.
The consolidated Godot test suite and GDScript lint checks pass.

The project owner accepted the integrated review, including turn and phase transitions and
the contextual menus. Further HUD ideas remain for later discussion; they do not block
continued implementation. The broader design documents remain to be updated by the owner
after this vertical slice, incorporating the approved amendments above.

## Consequences

The sequence limits investment in models, terrain, and broader UI restructuring until the core board presentation and interaction have been reviewed. The existing 2D board and game logic provide a working reference for behavior, while the 3D board remains a replaceable presentation component.
