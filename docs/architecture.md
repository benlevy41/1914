# 1914: The Western Front — Software Architecture

## 1. Purpose and Scope

This document defines the software architecture and technical principles for *1914: The Western Front*, a turn-based strategy game developed using Godot and GDScript.

Its purpose is to:
- Establish clear responsibilities and boundaries between major parts of the application.
- Provide architectural guidance for implementation decisions.
- Give developers and AI coding agents a consistent understanding of the intended design.
- Support incremental development without prematurely prescribing implementation details.

This document describes the software structure, not the complete game rules. Game mechanics and rules are documented separately in `docs/game_rules.md`.

The architecture should support the current hot-seat prototype while avoiding unnecessary constraints on future capabilities, including AI-controlled players and online multiplayer.

The architecture is intentionally conceptual in areas where implementation decisions are not yet necessary. Specific classes, methods, data structures, and frameworks should be determined as the project develops, provided they remain consistent with the principles and boundaries established here.

## 2. Architectural Principles

### 2.1 Separation of Concerns

The application should be divided into distinct layers with clearly defined responsibilities.

Each component should have a focused purpose and should not take on responsibilities belonging to another component or layer.

### 2.2 Encapsulation

Components should expose defined interfaces rather than allowing unrelated components to access or modify their internal implementation.

Game state and operations that modify it must be controlled so that game rules and data integrity are preserved.

### 2.3 Incremental Development

Development should proceed in small, functional increments.

Avoid introducing abstractions, frameworks, or complexity before there is a demonstrated need. Prefer the simplest implementation that satisfies current requirements without compromising the established architecture.

### 2.4 Testability

Core game logic should be testable independently of the Godot scene tree and presentation layer.

Dependencies should be explicit and controllable where practical, particularly for operations involving randomness.

### 2.5 Architectural Stability

The architecture should remain consistent as the project grows.

Significant architectural changes should be proposed and evaluated before implementation. Developers and AI agents may recommend alternatives, but should not independently make major architectural changes.

### 2.6 Maintainability

Code should favor clarity, consistency, and understandable behavior over unnecessary cleverness or abstraction.

Implementation decisions should make it straightforward for another developer to understand the purpose and responsibilities of a component.

## 3. System Architecture

The system is organized into four functional layers: Presentation, Application, Domain, and Infrastructure.

These layers describe responsibilities and dependency boundaries. They do not necessarily correspond one-to-one with directories, scenes, or individual classes.

### 3.1 Presentation Layer

**Responsibility:** Handle the visual presentation of the game and interaction with the user.

The presentation layer includes:
- Game screens, menus, and user interface.
- Map and board rendering.
- Visual representations of cities, units, and other game elements.
- Mouse and keyboard input.
- Visual feedback, animations, and audio.
- Displaying game information and results.

The presentation layer communicates user intent to the application layer and displays information derived from the current game state.

It must not:
- Implement game rules or independently determine the validity of game actions.
- Maintain a separate authoritative representation of game state.
- Modify game state directly.
- Make assumptions about how application or domain operations are implemented.

Presentation components may maintain temporary interaction state, such as the currently selected city or an active UI mode, provided that this does not become a competing source of authoritative game state.

The presentation layer should be replaceable or substantially modified without requiring changes to the underlying game rules.

### 3.2 Application Layer

**Responsibility:** Coordinate game execution and manage the lifecycle of a game.

The application layer acts as the control layer of the system. It coordinates interactions between presentation, domain, and infrastructure components.

Responsibilities include:
- Initializing and managing the lifecycle of a game.
- Managing turn progression and game phases.
- Receiving and coordinating player actions.
- Invoking domain operations to validate and resolve game actions.
- Coordinating state changes and related operations.
- Invoking infrastructure services when needed.
- Communicating results and relevant events to the presentation layer.

The application layer is responsible for managing the lifecycle of the authoritative `GameState`.

It should coordinate operations rather than independently implement game rules. Rules and game-specific constraints belong in the domain layer.

The application layer must not depend on a particular presentation implementation or assume that all player decisions originate from direct user interaction.

#### Player Decision Sources

The application should distinguish between a player in the game and the mechanism through which that player's decisions are obtained.

A player's decisions may originate from different sources, including:
- A local human interacting through the presentation layer.
- An AI-controlled player.
- A remote human player communicating through a network connection.

The application layer should process resulting player actions through a consistent game-action workflow, regardless of their origin.

The mechanism that generates or transports a decision should not independently execute game rules or modify authoritative game state. Actions must be processed through the application's normal coordination and domain validation paths.

The exact representation of player decision sources, their interfaces, and their lifecycle remain implementation decisions.

#### Development-Only Features

Developer tools must be available only in debug builds. The application layer must enforce this restriction for both starting a developer-mode game and invoking developer-only operations; hiding presentation controls is not sufficient access control.

Production release exports must have Godot's **Debug** export option disabled. Developer mode should reuse the regular game-start and gameplay workflows. Developer-only state changes must use explicit domain operations invoked through the application layer, and remain separate from normal gameplay operations so they can extend the game without replacing or duplicating them.

Cities keep their last assigned owner separately from current ownership. Only current ownership determines control; developer-mode unit additions may restore the remembered owner when reoccupying a city, while unoccupied cities remain uncontrolled.

### 3.3 Domain Layer

**Responsibility:** Represent the game and enforce its rules.

The domain layer contains the core concepts, state, and operations that define the game.

Expected domain concepts include:
- `GameState`
- `Player`
- `City`
- Map and connection relationships.
- Game rules and validation.
- Combat resolution.
- Reinforcement and reorganization operations.

The domain layer is responsible for:
- Representing the authoritative logical state of the game.
- Enforcing game rules and constraints.
- Validating game operations.
- Resolving game operations and determining their outcomes.
- Preserving state integrity when changes occur.

The domain layer must not depend on the Godot scene tree, presentation components, or direct filesystem and network APIs.

It should not need to know whether a player action originated from a human, an AI, or a remote connection. It operates on game concepts and actions, not on the mechanism used to produce them.

### 3.4 Infrastructure Layer

**Responsibility:** Provide technical capabilities that interact with external resources or systems.

Infrastructure responsibilities may include:
- Saving and loading games.
- Loading map definitions and other external resources.
- Reading configuration data.
- Providing random-number generation.
- Future network communication and related technical services.

Infrastructure components implement technical capabilities used by the application or domain.

They should not decide when or why a game operation occurs, and they must not contain game rules.

For example, the application layer decides when a game should be saved and coordinates the operation. An infrastructure service handles serialization and filesystem access.

Similarly, future networking infrastructure may transport player actions and game information, but should not independently determine whether those actions are legal.

The current Western Front map is sourced from `assets/board_setup/cities.csv` and `assets/board_setup/roads.csv`. The infrastructure layer reads and validates these files; the domain stores city latitude/longitude and connection road size without depending on the filesystem. The presentation layer is responsible for projecting geographic coordinates onto the board. Any future export preset must include the CSV files in its non-resource file filter.

## 4. Core Domain Model

This section describes the responsibilities of major game concepts without prescribing exact class structures or method signatures.

### 4.1 GameState

`GameState` represents the authoritative logical state of a game at a particular moment.

It includes the information required to describe the current game, such as:
- Players and their identities.
- City ownership and unit distribution.
- Current player.
- Current turn and game phase.
- Other information required to represent the complete game state.

The state does not need to be contained in one monolithic class or stored directly in a single object.

The application layer manages the lifecycle of `GameState`. The domain layer defines and enforces the rules governing changes to it.

The exact division of information and responsibilities between `GameState`, `City`, and other domain components remains open.

### 4.2 Player

A `Player` represents a participant in the game and the game-related information associated with that participant.

Player identity and game information should be conceptually separate from the mechanism used to obtain that player's decisions.

A player may be controlled locally, remotely, or by an AI implementation without changing the domain representation of that player.

### 4.3 City

A `City` represents an individual capturable territory on the game map.

It has a permanent identity and geographic information, as well as dynamic game information such as ownership and unit count.

The exact organization of city information within the domain model remains open.

Changes to ownership or unit counts must occur through controlled domain operations that preserve game rules and state integrity.

### 4.4 Map Definition and Game Map

The map has both static and dynamic aspects.

A static map definition describes the geography and topology of the game board, including:
- City identifiers and names.
- City latitude and longitude.
- Connections between cities.
- Connection types, such as roads.

Presentation-specific positions and visual adjustments, including geographic projection and label placement, must not alter the authoritative map coordinates or connections.

The logical game map represents cities and their connections as a graph, with cities as vertices and connections as edges.

The map should be modeled in a way that allows future connection properties, such as directionality or distance, if gameplay requires them.

Dynamic information such as city ownership and unit counts belongs to the current game state rather than the static map definition.

The visual representation of the map is a presentation concern and should not dictate the underlying logical map structure.

### 4.5 Game Rules and Domain Operations

Game rules define the legal operations and constraints of the game.

Domain operations should validate their inputs and ensure that state changes preserve the rules.

Invalid operations must not leave the game state partially modified.

The exact organization of rules and operations into classes or services remains open. Concepts such as `GameRules` and `CombatService` are possible organizational approaches, not mandatory class definitions.

## 5. Key Workflows

The application layer coordinates workflows by receiving requests, invoking domain operations, coordinating infrastructure as needed, and communicating results.

The workflows below describe expected behavior rather than prescribing exact method calls or implementation structures.

### 5.1 Initialize New Game

The initialization process includes:
- Establishing player identities.
- Loading the static map definition.
- Assigning cities to players, including their respective centers of gravity.
- Initializing the game state.
- Apportioning reserve units.
- Coordinating initial unit placement.
- Validating that the initial game state satisfies game rules.
- Transitioning the game into its active state.

Random assignments and other random operations should use controllable dependencies so that initialization can be tested reliably.

### 5.2 Reinforcement

The reinforcement process includes:
- Determining a player's reinforcement entitlement.
- Obtaining the player's desired placement decisions.
- Validating those decisions against game rules.
- Applying valid placements to the game state.
- Determining whether additional placements remain.
- Completing the reinforcement phase when appropriate.

The application coordinates the interaction. The domain determines entitlement, validates placement, and enforces relevant rules.

### 5.3 Attack

An attack may consist of multiple combat rounds.

Each combat round is an independently resolved operation. The application returns control to the player after each round so the player can decide whether to continue the attack or take another action.

The workflow includes:
1. Receive an attack request.
2. Validate the requested attack.
3. Obtain attacking and defending unit commitments as required by the rules.
4. Resolve one combat round.
5. Apply the resulting changes to the game state.
6. Determine whether the city has been captured, the attacker has been eliminated, or combat may continue.
7. Return the result to the application and presentation layers.

The combat operation should resolve one round and report its outcome. It should not prompt players or independently manage subsequent decisions.

### 5.4 Complete Turn

The turn-completion process includes:
- Completing phase-end processing.
- Advancing to the next phase or ending the turn.
- Updating the active player.
- Initializing the next player's turn and applicable reinforcements.
- Communicating relevant state changes to the presentation layer.

The application coordinates turn progression while the domain enforces the rules governing it.

## 6. Interfaces and Communication Contracts

Components should interact through defined interfaces and explicit dependencies. The architecture should make the direction and purpose of communication understandable without requiring components to know one another's internal implementation.

### 6.1 General Communication Rules

- Components should communicate through defined interfaces rather than accessing unrelated internal details.
- Dependencies should be explicit and injected where practical.
- The application layer coordinates operations between presentation, domain, and infrastructure.
- The domain layer must not depend on presentation components or the Godot scene tree.
- Presentation communicates user intent to the application and displays resulting information.
- Player decision sources provide actions to the application; they do not bypass normal game-action processing.

### 6.2 State Ownership and Modification

- The application layer manages the lifecycle of the authoritative `GameState`.
- The domain layer owns the rules governing valid state changes.
- The presentation layer must not directly modify authoritative game state.
- Components must not maintain competing authoritative copies of game state.
- State changes must occur through controlled operations that preserve game rules and consistency.
- Invalid operations must not partially modify game state.

The precise mechanism through which domain operations change state—directly modifying state through controlled operations or returning results for the application to apply—remains an open implementation decision.

### 6.3 Requests, Responses, and Errors

Operations should have defined inputs and identifiable outcomes.

Where appropriate, responses should communicate:
- Whether an operation succeeded.
- Relevant results or state changes.
- Why an operation was rejected.
- Any additional information required by the caller.

Invalid player actions are expected gameplay outcomes, not necessarily software errors. For example, an illegal attack should be rejected without crashing the application.

Invalid operations must not leave the game state partially modified.

The application should distinguish expected gameplay rejections from unexpected software failures.

Presentation reads current display data through an application-provided snapshot rather than retaining domain objects. After a successful state-changing request, presentation requests a fresh snapshot and renders from it. The current synchronous implementation does not require push notifications; if future asynchronous updates are introduced, notifications should prompt presentation to fetch a fresh snapshot rather than serve as the source of truth. See [ADR 0001](decisions/0001-presentation-snapshot.md).

### 6.4 Player Actions and Decision Sources

Player actions should be represented independently of the interface or mechanism that produces them.

The application should receive an action request, coordinate its validation and execution, and communicate the outcome.

The same conceptual action should follow the same validation and execution path whether it originated from:
- A local human player.
- An AI player.
- A remote human player.

The representation of actions should contain the information necessary to evaluate and execute them without depending on presentation-specific objects, UI controls, or network-specific message formats.

The exact action representation, decision-source interfaces, and network message contracts remain open.

### 6.5 Events and Notifications

The system should communicate meaningful game events to interested components without requiring them to know the internal implementation of the operation that produced the event.

Examples include:
- Game initialized or completed.
- City ownership changed.
- Combat round completed.
- Active player changed.
- Game phase changed.

The exact event mechanism remains an implementation decision. Godot signals may be appropriate for communication within the presentation layer, but domain logic must not depend on Godot signals.

## 7. Godot and GDScript Conventions

### 7.1 Scene Tree and Nodes

Godot uses a hierarchical scene tree composed of Nodes. Scenes organize reusable node hierarchies.

Godot Nodes and scenes should primarily be used for presentation, interaction, and other functionality that benefits from the scene tree.

Domain and application logic should generally be implemented as ordinary GDScript classes rather than Node subclasses.

Core domain logic must remain usable independently of the scene tree.

### 7.2 Object Responsibilities

Use Nodes when scene-tree functionality, lifecycle callbacks, rendering, input, or other engine features are needed.

Use ordinary GDScript objects for domain and application concepts that do not require scene-tree behavior.

Prefer composition and clear dependencies over elaborate inheritance structures.

The exact choice between ordinary GDScript classes, Resources, and other Godot constructs should be made based on implementation needs while preserving architectural boundaries.

### 7.3 Signals and Communication

Godot signals are appropriate for many presentation-level interactions and notifications.

They should not be used as a substitute for clear domain interfaces or to create implicit dependencies between architectural layers.

Domain logic should not require Godot-specific signaling mechanisms.

### 7.4 Autoloads and Global State

Avoid excessive use of autoload singletons.

Autoloads should not become an alternative source of authoritative game state or a shortcut around explicit dependencies and architectural boundaries.

### 7.5 GDScript Practices

- Use static typing where practical, especially for function parameters, return values, and important variables.
- Follow consistent naming and code organization conventions.
- Prefer clear, maintainable implementations over unnecessary abstractions.
- Use APIs and language features compatible with the project's installed Godot version.
- Do not introduce plugins, frameworks, or external libraries without project owner approval.

## 8. Testing and Quality Standards

Testing should validate expected behavior and architectural boundaries rather than merely reproduce implementation details.

### 8.1 Unit Tests

Domain logic should be testable independently of the Godot scene tree.

Unit tests should cover:
- Normal expected behavior.
- Boundary conditions.
- Invalid operations.
- State integrity after successful and rejected operations.
- Randomized behavior using controllable or predetermined inputs where appropriate.

Tests should isolate the behavior under examination and avoid unnecessary dependencies on unrelated components.

### 8.2 Integration Tests

Integration tests should validate interactions between application and domain components.

Important workflows include:
- Game initialization.
- Reinforcement.
- Combat.
- Turn progression and completion.
- Handling of invalid operations without corrupting state.

### 8.3 Presentation Tests

Presentation behavior should be tested where practical.

However, the ability to test domain and application behavior must not depend on the availability of presentation tests or a running scene tree.

### 8.4 Development Quality

- New functionality should include appropriate tests.
- Existing tests should continue to pass.
- Tests should be runnable through documented commands, including headless execution where practical.
- Test failures should be investigated rather than bypassed.
- New errors or warnings should not be introduced without explanation.
- Developers and agents should report which tests were run and identify any failures or limitations.

### 8.5 Test Runner Registration

The consolidated runner in `tests/run_tests.gd` explicitly registers SceneTree test scripts in `SCENE_TREE_TESTS` and runs the presentation test scene specified by `PRESENTATION_TEST_SCENE`. New tests must be registered in the appropriate place to run as part of the consolidated test suite.

The specific testing framework remains an implementation decision.

## 9. Architectural Decisions and Unresolved Questions

The following decisions are intentionally deferred until implementation needs make them clearer.

### 9.1 Game State Organization

The conceptual responsibilities of `GameState` and `City` are defined, but the exact division of data and behavior between them remains open.

### 9.2 State Mutation Mechanism

It remains undecided whether domain operations will directly modify state through controlled interfaces or return results for the application layer to apply.

Either approach must preserve domain authority over game rules and state integrity.

### 9.3 Domain and Application Interfaces

Exact class structures, method signatures, and interface definitions should emerge as the implementation develops.

They should remain consistent with the layer responsibilities and communication contracts in this document.

### 9.4 Resource and Data Representation

The choice between Godot Resources, ordinary GDScript classes, and other representations for map definitions and game data remains open.

### 9.5 Player Decision Mechanisms

The architecture establishes that player decisions may originate from local human input, AI, or remote human players.

The exact interfaces and implementation of these mechanisms are deferred. The current hot-seat implementation should not require premature networking or AI abstractions.

### 9.6 Persistence and Networking

The architecture should preserve the ability to represent and serialize a complete game state and to communicate player actions through future infrastructure.

The save format, network architecture, server authority model, and synchronization mechanisms are not yet defined.

### 9.7 Testing Framework

The specific testing framework and supporting tooling remain open until the project's testing environment is established.