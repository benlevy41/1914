# 1914: The Western Front — Software Architecture

## 1. Purpose and scope of this document

This document provides a high-level description of the software architecture for the turn-based strategy game "1914: The Western Front."

The document is aimed at developers and agents that will write code for this project. It is intended to help them understand the context in which their code will run, the expected quality standards for their code, and the boundaries and restrictions on developers and agents.

This document will change. Please refer to it frequently.

This document will not specify the exact classes and functions that must be built. Developers and agents will have flexibility in creating code required to fulfill their assigned tasks, which will generally involve introducing new functionality or fixing errors in existing code. However, developers and agents must adhere to the architectural principles and constraints established here.

Architectural decisions not addressed by this document should be brought to the project owner for consideration. Developers and agents may propose alternative designs and explain their rationale, but must not implement changes to the established architecture without approval.

For a description of the game and its rules, please reference `docs/game_rules.md`.

## 2. Project overview and coding principles

"1914: The Western Front" will run on the Godot game engine and will be written primarily in the GDScript language. We use GitHub for version control, CI/CD, and issue tracking.

The architecture will be designed to facilitate rapid prototyping and test-driven development.

We will adhere to the following coding principles:

1. **Separation of concerns** – Each component should serve one specific purpose. If the scope of that function expands, we should look at creating new components instead of adding more functionality to an existing one.

2. **Encapsulation** – Each component should be a self-contained unit to the greatest extent possible. When necessary, dependencies must be explicit and should be deliberately injected instead of reaching into unrelated components. Communication between components should be achieved through defined interfaces.

3. **Incremental development** – Do not add abstractions or frameworks before they are needed. This reduces unnecessary work and allows for faster, testable development.

4. **Testability** – Components should be testable in isolation without requiring the implementation or simulation of unrelated components. Integration testing involving multiple components will be deliberate and separate from unit testing.

5. **Architectural stability** – Changes to the basic architecture of the software will not be made without authorization from the project owner. Requests for architectural changes should be raised to the project owner.

6. **Maintainability** – Code should be understandable, appropriately documented, and maintainable by developers who did not write it. Avoid unnecessary complexity, overly elaborate abstractions, and implementation shortcuts that make future changes difficult.

These principles establish the overall expectations for the project. More specific implementation requirements are described in the sections below.

## 3. System architecture

The software will be structured in four functional layers: presentation, application, domain, and infrastructure.

### Presentation layer

This layer is how the user interacts with the program. It displays the gameboard and menus and receives mouse and keyboard input.

This is primarily the domain of the Godot engine and will be composed primarily of Godot scenes.

The presentation layer interacts with the application layer to obtain the information needed to render the game and to communicate user input and intent.

The presentation layer will not duplicate authoritative game state and will not contain game control logic such as turn management or game rules, which are the responsibility of other software layers.

### Application layer

The application layer is the game control layer. It acts as a conductor, ensuring smooth turn management, transitions between game phases, and transitions between player turns.

The application layer interprets user input and coordinates interactions between the presentation, domain, and infrastructure layers. It is responsible for managing the lifecycle of the active game and its authoritative GameState, but it does not independently implement game rules or determine how things are rendered.

For example, the application layer receives a request from the presentation layer indicating that the user has selected an enemy city as an attack target. The application layer determines the appropriate action in the current game context, calls the domain layer to determine whether the attack is legal, and, if it is, coordinates the resolution of the attack.

### Domain layer

The domain layer contains the underlying game logic. If the application layer is the conductor, the domain layer might be the sheet music in front of the orchestra.

The domain layer contains the core game concepts and rules, including players, cities, map relationships, game rules, and combat services.

The domain layer primarily responds to requests from the application layer. It is responsible for enforcing game rules and ensuring that operations affecting game state preserve its integrity.

The domain layer should remain independent of the Godot scene tree, presentation components, and direct file-system operations. It may rely on explicitly defined dependencies for lower-level services, such as random number generation.

### Infrastructure layer

This layer provides technical services that interact with the underlying operating system, file system, and external resources. Examples include reading and writing files, saving and loading game data, loading external resources, and generating random numbers.

The infrastructure layer is responsible for implementing these technical capabilities, but it does not determine when or why they are used. Those decisions are made by the application or domain layers, depending on the purpose of the operation.

The application layer generally coordinates operations involving infrastructure services, such as initiating a save or load operation and handling its result. The domain layer may also depend on infrastructure-provided capabilities through explicitly defined interfaces, such as requesting random values during combat.

The infrastructure layer should not contain game rules or make decisions about game behavior. It should provide the technical means to carry out operations requested by other layers.

## 4. Core domain model

The following are some of the components that will form the core of the game domain model. This list is not comprehensive and is expected to change as development progresses.

**GameState** – Represents the authoritative state of an active game, including information such as player identities, turn progression, city ownership, unit distribution, and other dynamic game information. The GameState concept provides a central representation of the information required to describe the current game and support saving, loading, and game logic. The specific organization of this information, including how responsibilities are distributed between GameState, City, and other domain components, is intentionally left open to implementation.

**Player** – Represents an individual player and their identity. Will be used for identifying players in game records and saved games, and may contain other player-specific information as needed.

**City** – Represents an individual capturable territory on the game map. A city has a permanent identity and associated geographic information, as well as dynamic game information such as ownership and unit count. The specific organization and management of this information will be determined during implementation.

**MapDefinition** – Represents the static information describing the game map, such as city identifiers, names, geographic positions, and connections between cities. This information is distinct from the changing state of an active game.

**GameMap** – Represents the relationships and connectivity between cities. The map will be modeled conceptually as a graph, with cities as vertices and connections as edges. The initial implementation will support road connections. The design should allow for future changes such as multiple connection types, directionality, or distance without requiring a fundamental redesign.

**GameRules** – Validates player actions against game rules. For example, if a player attempts to reinforce a city that is not connected to their COG, the rules should determine that the action is invalid.

**CombatService** – Determines the outcome of individual rounds of combat, including dice rolls and resulting unit losses. It should not be responsible for managing player decisions or the overall attack sequence.

The division of responsibilities and the specific organization of these concepts will be refined during implementation. Developers and agents should avoid introducing unnecessary complexity or assuming that each concept must correspond to a single class.

## 5. Key workflows and interactions

The following workflows describe the general sequence of operations involved in major game activities. They are intended to provide context for developers and agents, not to prescribe the exact implementation or require that all steps be handled by a single component or function.

The application layer generally coordinates these workflows, while the domain layer enforces game rules and resolves game operations.

### Initialize a new game

General sequence:

1. Prompt players for names.
2. Generate an initial game configuration, including random city assignments, ensuring equal numbers of cities for each player and assigning each COG to the appropriate player.
3. Load the required map resources and initialize the game state.
4. Apportion reserve units.
5. Prompt players to place reserve units until all units have been placed.
6. Validate the resulting initial game state.
7. Transition the game to active play.

### Process a reinforcement action

General sequence:

1. Determine the number of reinforcements available to the active player.
2. Prompt the player to select a city and the number of units to place.
3. Determine whether the proposed placement is legal under the game rules.
4. If legal, apply the resulting change to game state.
5. Determine whether additional reinforcements remain to be placed.
6. Return control to the player when placement is complete.

### Resolve an attack

An attack consists of one or more individual rounds of combat. Each round is resolved independently, allowing the player to decide whether to continue attacking or take another action after seeing the result.

General sequence:

1. Receive an attack request from the presentation layer.
2. Validate the requested attack against the game rules.
3. Obtain the number of units the attacker and defender will commit.
4. Resolve one round of combat.
5. Apply the resulting changes to game state.
6. Determine whether the attack resulted in capture, elimination of the attacking force, or continued combat.
7. Return the result to the application layer for presentation to the players.

After the result is presented, the application layer returns control to the player to decide whether to continue attacking the same city, initiate another attack, or end the attack phase.

The combat service is responsible for resolving an individual round of combat. It is not responsible for prompting players or managing their subsequent decisions.

### Complete a turn

General sequence:

1. Determine whether the active player has completed the current turn phase.
2. Validate and process any required phase-end operations.
3. Advance the game to the next phase or, if all phases are complete, end the active player's turn.
4. Update the active player.
5. Initialize the next player's turn, including determining their available reinforcements and setting the appropriate game phase.
6. Notify the presentation layer of relevant changes so that the interface can be updated.

The application layer coordinates these transitions, while the domain layer enforces any applicable game rules.

## 6. Interfaces and communication contracts

The following requirements establish how components and layers should communicate. They are intended to promote encapsulation, maintainability, and predictable interactions without prescribing exact method signatures or implementation details.

### 6.1 General communication rules

- Components should communicate through defined interfaces.
- Dependencies should be explicit and passed to components when needed, rather than retrieved through unrelated components or global references.
- The application layer coordinates interactions between the presentation, domain, and infrastructure layers.
- The domain layer must not depend on the presentation layer.
- Components should not access or modify the internal data of unrelated components directly.
- Communication mechanisms should be appropriate to the relationship between components and should not introduce unnecessary complexity.

### 6.2 State ownership and modification

The application layer is responsible for the lifecycle and management of the authoritative GameState. This includes creating the initial game state, maintaining the active game, and coordinating state changes.

The domain layer is responsible for enforcing the rules governing changes to game state. Operations that modify game state must preserve its validity and consistency.

The specific division of state-management responsibilities between GameState and other domain components, including City, is intentionally left open to implementation.

The following requirements apply:

- GameState represents the authoritative information describing the current game.
- Presentation components must not directly modify authoritative game state.
- Components must not maintain redundant copies of authoritative game information.
- Changes to game state must occur through controlled operations that preserve applicable game rules.
- The application layer must coordinate state changes and ensure that the resulting state is communicated to the presentation layer as needed.

### 6.3 Requests, responses, and errors

Requests between components should have clearly defined inputs and expected outcomes.

- Successful operations should return enough information for the requesting component to respond appropriately.
- Invalid requests should return meaningful information explaining why the operation could not be completed.
- Invalid requests must not leave game state partially modified or inconsistent.
- Expected invalid player actions should be handled as normal game conditions rather than software errors. For example, an attempt to attack a city that is not adjacent to the player's territory should be rejected without causing the game to fail.

The specific mechanisms used to represent successful operations, invalid actions, and software errors will be determined during implementation.

### 6.4 Events and notifications

Components should be able to communicate relevant changes or completed operations without creating unnecessary dependencies on the internal implementation of other components.

Examples of events or notifications include:

- A city's ownership has changed.
- A combat round has completed.
- The active player has changed.
- The game phase has changed.
- A game has been initialized or completed.

The presentation layer should receive the information it needs to update the interface without having to understand the internal mechanics that produced the change.

The specific communication mechanism will be determined during implementation. Godot signals may be appropriate for communication within the presentation layer, but domain logic should not depend on Godot signals.

## 7. Godot and GDScript conventions

The project will use Godot 4.x and GDScript. Developers and agents should follow these conventions to maintain consistency and preserve the separation between software layers.

### 7.1 Separation from the Godot scene tree

Godot Nodes and scenes are primarily intended for presentation, interaction, and other engine-specific functionality.

Domain and application logic should generally be implemented using ordinary GDScript classes rather than Node subclasses. This allows game logic to be tested independently of the Godot scene tree.

Domain components must not depend on scene paths, node references, or presentation controls.

### 7.2 Scenes and Nodes

Godot scenes should be used to organize visual elements and user interactions, including the game board, city representations, menus, and interface components.

Scenes may contain scripts that manage their own presentation behavior and communicate user intent to the application layer.

Avoid placing game rules, turn management, or other domain responsibilities directly in presentation scripts.

### 7.3 Composition and inheritance

Prefer simple composition over unnecessarily complicated inheritance hierarchies.

Godot supports scene inheritance and script inheritance, but these mechanisms should be used when they provide a clear benefit rather than as a default approach.

### 7.4 Signals and event communication

Godot signals may be used for appropriate communication between presentation components and for notifying other components of events.

Signals should not be used as a substitute for clearly defined interfaces or as a way to obscure dependencies between components.

### 7.5 Autoloads and global state

Godot supports globally accessible objects through autoloads. These may be appropriate for application-wide services such as configuration or audio management.

Autoloads should be used sparingly. They must not become an alternative source of authoritative game state or a shortcut around the project's dependency and encapsulation requirements.

### 7.6 Static typing and code conventions

Use GDScript's static typing features where practical, particularly for function parameters, return values, and important variables.

Code should follow consistent naming, formatting, and documentation conventions. Developers and agents should follow existing project conventions rather than introducing competing styles.

### 7.7 Godot version and dependencies

Developers and agents must use APIs and features compatible with the Godot version established for the project.

New plugins, frameworks, external libraries, or other dependencies must not be introduced without approval from the project owner.

The specific use of Godot Resources, ordinary GDScript classes, and other data-management mechanisms will be determined as implementation needs become clearer.

## 8. Testing and quality standards

Testing is an integral part of development. New functionality and modifications to existing functionality should include appropriate tests.

Testing will be divided into three general categories.

### 8.1 Unit testing

Unit tests validate individual components in isolation.

- Domain logic must be testable independently of the Godot scene tree.
- Tests should cover normal behavior, boundary conditions, and invalid operations.
- Tests should validate expected behavior rather than simply reproduce the implementation.
- Random or nondeterministic operations must be controllable during testing. For example, combat tests should be able to use predetermined dice rolls.
- Unit tests should not require unrelated components to be implemented or simulated.

### 8.2 Integration testing

Integration tests validate interactions between multiple components.

Examples include:

- Initializing a game and verifying the resulting game state.
- Processing a reinforcement action and verifying that the appropriate city information changes.
- Resolving combat and verifying the resulting unit counts and ownership.
- Completing a turn and verifying that the active player and game phase change correctly.
- Confirming that invalid operations do not leave game state inconsistent.

Integration testing should be deliberate and separate from unit testing.

### 8.3 Presentation testing

Presentation tests validate user-facing behavior and interactions where practical.

Examples include:

- Selecting cities on the game board.
- Displaying the correct ownership and unit information.
- Updating the interface when the active player or game phase changes.
- Displaying appropriate feedback for invalid actions.

Presentation tests should not be a prerequisite for testing domain logic.

### 8.4 Quality requirements

- New functionality must include appropriate tests.
- Existing tests must continue to pass after changes are made.
- Tests should be runnable through documented commands, including headless execution where applicable.
- Agents must report which tests were executed and whether they passed.
- Test failures must be investigated and reported rather than ignored or bypassed.
- Code changes should not introduce new errors or warnings without explanation.

The specific testing framework and supporting tools will be established separately as the development environment evolves.

## 9. Architectural decisions and unresolved questions

This section records significant architectural decisions and identifies areas that remain open or have been deliberately deferred.

Developers and agents should use this section to distinguish established requirements from decisions that still require consideration.

| Topic | Status | Notes |
|---|---|---|
| Four-layer architecture | Decided | Presentation, application, domain, and infrastructure. |
| Authoritative GameState | Decided | The application layer manages the lifecycle of the authoritative game state. |
| Domain independence from Godot presentation | Decided | Domain logic should not depend on Nodes, scenes, or presentation components. |
| Graph-based map model | Decided | Cities are vertices and connections are edges. |
| Static map data separated from dynamic game state | Decided | The exact implementation remains open. |
| Ownership and unit-count representation | Open | The distribution of responsibilities between GameState, City, and other components will be determined during implementation. |
| State modification mechanism | Open | Domain operations must enforce game rules, but the precise division of state modification between domain and application components remains to be determined. |
| Road and railway connection types | Open | The initial implementation will support roads. Additional connection types may be introduced later. |
| Event communication mechanism | Open | Godot signals may be appropriate for presentation-level communication. |
| Save-file format | Deferred | To be determined once the game-state model is sufficiently established. |
| Testing framework | Deferred | To be selected when the testing environment is established. |
| Multiplayer support | Deferred | Not part of the initial architectural requirements. |

Significant architectural changes and decisions should be documented separately in `docs/decisions/` when appropriate. These records should describe the decision, the alternatives considered, and the rationale for the selected approach.

Developers and agents must not treat open or deferred decisions as authorization to introduce permanent architectural changes without approval from the project owner.