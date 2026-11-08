# 1914: The Western Front — UI and Visual Design Philosophy

## 1. Purpose

This document establishes the visual direction and interaction philosophy for *1914: The Western Front*.

It is intended to guide future presentation-layer development and provide a consistent design reference for developers and AI coding agents.

The goal is to create a visually engaging strategy game that balances the clarity and tactile character of a tabletop wargame with the visual depth and atmosphere of a historical 3D environment.

This document describes the intended experience and visual constraints. It does not prescribe exact Godot scenes, node hierarchies, scripts, or implementation details.

## 2. Overall Visual Direction

The game should feel like a carefully constructed tabletop representation of the Western Front during World War I.

The visual style should balance:

- **Historical character:** The environment, cities, roads, and military pieces should evoke the period and geography.
- **Tabletop readability:** The board and its pieces should remain visually understandable as a strategy game.
- **Subtle realism:** Models and materials should have enough detail to create a convincing miniature environment without pursuing photorealism.
- **Visual restraint:** Decorative detail should not compete with the information needed to make strategic decisions.

The desired result is not a conventional flat 2D board, but neither is it a fully simulated 3D battlefield. It is a 3D tabletop strategy environment.

## 3. Board and Camera

### 3.1 Board Representation

The game board should initially be represented as a flat 3D surface.

The underlying map remains a logical network of cities and connections. Its visual representation should not dictate or own the logical game structure.

The initial board should prioritize:
- Clear city locations.
- Readable connections between cities.
- Sufficient space for unit formations.
- Clear ownership indicators.
- A coherent overall geographic layout.

Terrain elevation, surface variation, and other environmental details may be introduced later if they improve the visual experience without reducing readability.

### 3.2 Camera Behavior

The camera should present a consistent, fixed-angle view of the board.

The camera is not intended to be freely navigable. Excessive camera freedom would make it harder to maintain a consistent understanding of the board and could distract from strategic decisions.

Expected controls:
- Scroll wheel: zoom in and out.
- WASD: pan across the board.
- Fixed camera rotation and viewing angle.
- Reasonable zoom limits.
- Pan boundaries that prevent the player from losing the board entirely.

Camera movement should be smooth and predictable, but should not introduce unnecessary animation or visual effects.

The camera should use a projection and angle that preserve board readability and make city positions, connections, and unit formations easy to interpret.

## 4. Cities and Military Units

### 4.1 Cities

Each city should have an individual 3D model on the board.

City models should be recognizable and visually distinct enough to provide a sense of place, but should remain relatively small.

A city model should be only slightly larger than an individual military unit model. Cities should not dominate the board or consume so much space that unit formations become crowded.

City ownership should be communicated clearly through visual indicators such as flags, colors, or other restrained markings.

### 4.2 Military Units

Each individual military unit should be represented by its own model on the board.

Unit models should be arranged in formations around or near their associated city.

The number of visible unit models should communicate the size of the garrison intuitively. A city with a larger force should visibly have more units than a lightly defended city.

Unit models are visual representations of domain state. They do not independently own or determine unit counts, ownership, or game rules.

The presentation layer is responsible for arranging and displaying these models in a readable way.

Unit models should be visually consistent, appropriately scaled, and distinguishable from city models.

### 4.3 Visual Clarity

The board must remain readable at normal gameplay zoom levels.

The presentation should avoid:
- Overlapping models that make unit counts difficult to interpret.
- City models that obscure roads or neighboring territories.
- Excessive decorative objects.
- Visual effects that obscure selection or ownership.
- Unnecessary differences in model scale.

When a city contains many units, the presentation should arrange them in a way that preserves visual clarity without changing their logical count.

## 5. Terrain and Environment

Terrain is desirable as a later visual enhancement, but is not required for the initial 3D board.

The first implementation should use a flat surface and establish the scale, layout, camera, city models, and unit formations.

Future terrain may include:
- Subtle elevation and relief.
- Rivers and other geographic features.
- Forests and other landscape elements.
- Roads and railway features.
- Period-appropriate environmental details.

Terrain should reinforce the geography and atmosphere of the Western Front without making the board difficult to read.

Terrain must not change the logical connectivity of the game map or independently determine whether movement or attacks are legal.

## 6. User Interaction Philosophy

### 6.1 Mouse-First Interaction

The interface should prioritize mouse-controlled interaction.

Players should be able to select cities, inspect their state, choose actions, and interact with game controls primarily through the mouse.

Keyboard shortcuts may be provided where useful, but should supplement rather than replace mouse interaction.

The interface should make available actions and relevant information discoverable without requiring players to memorize a large collection of keyboard commands.

### 6.2 Selection and Feedback

Selecting a city or unit should produce clear visual feedback.

The presentation should make it apparent:
- Which object is selected.
- Which actions are available.
- Which cities or units are valid targets for the current action.
- What happened after an action is completed.

Visual feedback should be immediate and consistent.

### 6.3 Information Hierarchy

The board is the primary focus of the game interface.

Supporting UI elements should provide relevant information and controls without unnecessarily covering the board.

The interface should prioritize information needed for current decisions, including:
- Active player.
- Current phase.
- Selected city information.
- Ownership and unit counts.
- Available actions and action results.

Detailed information should be accessible when needed without overwhelming the normal board view.

### 6.4 Game Flow

The interface should guide the player through the current game phase and available actions.

It should make it clear what the player can do, what is required to complete a phase, and when control passes to another player.

The presentation layer should communicate the state and available options; the application and domain layers remain responsible for deciding which actions are legal.

## 7. Multiplayer and Player Interaction

The current hot-seat format is an appropriate development and testing mechanism.

The presentation should initially support local interaction with the active player.

The visual and interaction design should avoid unnecessary assumptions that the active player is always the person currently sitting at the computer.

Future versions may support AI-controlled and remote human opponents. The visual interface should be able to present the active player's game information and interaction options without requiring a fundamentally different board representation.

Online multiplayer is not part of the initial presentation scope.

## 8. Implementation Scope and Priorities

Presentation development should proceed incrementally.

### Initial 3D Presentation

The first 3D implementation should include:
- A flat 3D board.
- A fixed-angle camera.
- Scroll-wheel zoom.
- WASD panning.
- Individual city models.
- Individual military unit models.
- Readable unit formations.
- City ownership indicators.
- Mouse-based city selection.
- Basic visual feedback.
- UI elements for current player, phase, and relevant actions.

Use simple placeholder models where necessary. The initial objective is to validate scale, readability, camera behavior, and interaction—not to produce finished artwork.

### Later Visual Development

After the basic 3D board is functional and evaluated, presentation development may add:
- Improved city and unit models.
- More detailed materials and textures.
- Terrain and elevation.
- Rivers, forests, and other geographic features.
- Improved visual effects and animations.
- More polished menus and supporting UI.

Visual complexity should be introduced only when it improves the experience.

## 9. Architectural Constraints

Presentation development must remain consistent with `docs/architecture.md`.

In particular:
- The logical game map and game state remain independent of their visual representation.
- Presentation components display domain state; they do not own authoritative game data.
- Individual unit models represent domain unit counts but do not independently determine them.
- City models represent domain cities but do not implement city ownership or game rules.
- Mouse and keyboard input communicate player intent to the application layer.
- The presentation layer must not bypass application or domain operations to modify game state.
- The board should be replaceable or substantially redesigned without requiring changes to core game rules.

The implementation should use Godot's 3D capabilities where appropriate while preserving the architectural separation between presentation, application, domain, and infrastructure.

## 10. Development Guidance

The initial hot-seat prototype should be completed before substantial work begins on the 3D presentation redesign.

Once the prototype is functional, a dedicated presentation/front-end implementation agent may use this document and `docs/architecture.md` as its primary design constraints.

That agent should:
- Review the existing project and understand its current architecture.
- Propose an incremental transition to the 3D board.
- Preserve existing game behavior and domain logic.
- Explain proposed presentation structures and interactions before making significant changes.
- Use placeholder assets initially.
- Avoid introducing new plugins, frameworks, or external dependencies without approval.
- Test presentation changes and verify that they do not alter game rules or authoritative game state.

The presentation agent may recommend visual or interaction improvements, but significant departures from this document should be discussed and approved before implementation.