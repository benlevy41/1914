# User Interface Design Principles

## Purpose

The following document defines the UI/UX principles for the turn-based strategy game *1914: The Western Front*, developed using Godot 4 and GDScript.  

## General Guidance

The following is an article posted on strayspark.studio and outlines some of the guiding principles of modern user interface design. *1914: The Western Front* is at its core a tabletop strategy game, not an action game.  User experience should be immersive but "Juice" as described in the article should not distract from the pace and feel of the gameplay.  We want a clean, focused interface that primarily uses mouse control interacting with game objects in a way that preserves the feel of physical interactions with a tabletop game.

### Game UI/UX Design Principles: HUD, Menus, and Feedback Systems That Work

### Design game UI that players understand instantly. Covers HUD design philosophy, menu navigation patterns, feedback systems, diegetic vs non-diegetic UI, accessibility requirements, and common UX mistakes that frustrate players.

### BY STRAYSPARK Apr 2, 2026 6 MIN READ

The Invisible Interface
Great game UI disappears. Players should focus on the game world, not the interface overlaid on it. Every HUD element, menu screen, and notification competes for the player's attention — add only what earns its screen space.

HUD Design Philosophy
The Minimum Viable HUD
Start with nothing on screen. Add elements only when you can justify their constant presence:

Always visible (if applicable):

Health (only if damage is frequent and health doesn't auto-regenerate quickly)
Ammo (only in shooter games where counting matters)
Minimap (only if navigation is core gameplay)
Contextual (appear when relevant):

Interaction prompts (appear near interactable objects)
Status effects (appear when affected, fade when expired)
Objectives (flash briefly when updated, then hide)
Damage indicators (appear on hit, fade quickly)
On-demand (player opens explicitly):

Full map
Inventory
Character stats
Quest log
HUD Layout Zones
┌──────────────────────────────────────────┐
│ [Top-Left]           [Top-Center]  [Top-R]│
│  Minimap             Objective text Quest │
│  Compass             Boss health   markers│
│                                           │
│                                           │
│ [Center]                                  │
│  Crosshair                                │
│  Interaction prompts                      │
│  Damage numbers                           │
│                                           │
│ [Bottom-Left]        [Bot-Center] [Bot-R] │
│  Health bar          Dialogue     Ammo    │
│  Status effects      Subtitles    Weapon  │
│  Quick items         Notifications Ability │
└──────────────────────────────────────────┘
Corners: Persistent information (health, ammo, minimap) Center: Momentary gameplay information (crosshair, prompts) Bottom center: Narrative UI (dialogue, subtitles) Edges: Secondary information

Information Hierarchy
Use visual weight to communicate priority:

Critical (large, high contrast, animated): Low health warning, incoming damage
Important (medium, clear): Current objective, ability cooldowns
Informational (small, subtle): Experience gained, minor pickups
Ambient (very subtle, blends with world): Compass, time of day
Diegetic vs Non-Diegetic UI
Non-Diegetic (Traditional HUD)
UI exists outside the game world. Health bars, minimaps, and ammo counters overlaid on the screen.

Use when: Clarity is more important than immersion. Competitive games, action games where split-second information access matters.

Diegetic (In-World UI)
UI exists within the game world. Dead Space's spine health bar, Metro's watch for time, Fallout's Pip-Boy.

Use when: Immersion is a core design goal. Horror games, simulation games, narrative experiences.

Spatial UI
UI attached to world-space objects. Floating health bars above enemies, interaction labels on objects, waypoint markers in 3D space.

Use when: Connecting UI information to specific world locations. MMOs, open-world games with many points of interest.

Meta UI
UI that the character is aware of but that doesn't exist physically. Assassin's Creed's Eagle Vision, Batman's Detective Mode.

Use when: You want a hybrid of immersion and information density. The character has a justified reason for seeing extra information.

Menu Design
Navigation Patterns
Tab-based (horizontal tabs at top):

Best for: 3-7 equally important sections
Example: Inventory | Equipment | Map | Quests | Settings
Sidebar (vertical list on left):

Best for: Many sections with sub-navigation
Example: RPG character sheets with stats, skills, relationships
Radial (wheel around center):

Best for: Quick selection during gameplay (weapon wheel)
Example: Item quickbar, emote wheel
Full-screen overlay (replaces game view):

Best for: Complex menus that need full attention
Example: Crafting systems, skill trees, world map
Controller Navigation
All menus must support controller navigation:

D-pad/stick: Navigate between elements
Face buttons: Confirm, cancel, contextual actions
Bumpers/triggers: Tab switching, page scrolling
Clear focus indicator: Always show which element is selected
Test every menu screen with controller only. If any element is unreachable or confusing without a mouse, fix it.

Menu Response Time
Input to visual response: Under 16ms (one frame at 60fps)
Screen transition: Under 200ms (avoid loading screens for menus)
Animation duration: 100-300ms for transitions (faster feels snappy, slower feels polished)
Never block input during animations: Let players skip through transitions
Feedback Systems
The Feedback Loop
Every player action should produce feedback:

Player Action → Visual Feedback + Audio Feedback + Haptic Feedback (if applicable)
Missing feedback makes actions feel unresponsive. Excessive feedback creates noise.

Feedback by Importance
Action	Visual	Audio	Screen Effect
Normal attack hit	Hit flash, damage number	Impact sound	Slight hitstop (50ms)
Critical hit	Larger flash, emphasized number	Distinct crit sound	Camera shake, hitstop
Take damage	Screen edge red flash	Pain grunt	Controller rumble
Near death	Persistent vignette, desaturation	Heartbeat	Persistent mild rumble
Level up	Full-screen flash, particle burst	Triumphant chord	Strong rumble pulse
Pickup item	Item icon flies to inventory	Pickup chime	Brief rumble
Juice and Game Feel
"Juice" is the sum of small feedback effects that make interactions feel satisfying:

Hitstop: Freeze both attacker and target for 1-3 frames on hit. Makes impacts feel heavy.
Screen shake: Small (1-3px) for minor events, large (5-10px) for major. Always dampened, never sustained.
Scaling animations: Buttons scale up on hover (1.05x), press (0.95x), release (1.0x). Microsecond animations that feel alive.
Particle bursts: Small particles on interaction (coin pickup sparkle, button press ripple).
Color flash: Affected objects briefly flash white or the damage type color.
Sound Design for UI
UI sounds are as important as visual design:

Consistent vocabulary: Same sound family for the same type of action
Pitch variation: Slightly randomize pitch (±5%) to avoid repetition fatigue
Priority system: Important sounds override ambient sounds
Silence is design: Quiet moments between sounds are intentional
Accessibility in UI
Minimum Requirements (2026)
Subtitle options: Size (small/medium/large), background opacity, speaker names, color coding
Color blind modes: Deuteranopia, protanopia, tritanopia filter options
Font scaling: All text scalable (0.75x to 2.0x minimum)
High contrast mode: Option for stronger contrast between UI and background
Button remapping: All UI actions remappable
Screen reader support: Menu narration for visually impaired players
Reduce motion: Disable screen shake, minimize animations, reduce particle effects
Testing Accessibility
Play with no audio — is all critical information conveyed visually?
Play with no visual effects — is all critical information conveyed through audio?
Apply a color blindness simulation — can you distinguish all UI elements?
Scale text to minimum size — is it still readable on target display sizes?
Navigate all menus with controller only — is everything reachable?
Common UI/UX Mistakes
Too much HUD: Every element you add to the HUD steals attention from the game world. If a health bar is on screen for 95% of gameplay but only relevant 5% of the time, make it contextual.

Inconsistent interaction patterns: If "A" confirms in some menus and "B" confirms in others, players will make errors constantly. Pick a pattern and never deviate.

No loading feedback: When a screen takes more than 200ms to load, show a loading indicator. Players perceive 500ms of no feedback as "broken."

Tiny touch targets: On mobile and Steam Deck, interactive elements must be at least 44x44 pixels. Smaller targets cause frustration and misclicks.

Ignoring controller users: Designing for mouse first and adding controller support later always produces inferior controller navigation. Design for both simultaneously.

Information overload during tutorials: Teaching 10 mechanics in the first 5 minutes overwhelms new players. Introduce one concept at a time, give time to practice, then add the next.

No visual hierarchy in menus: When everything is the same size and color, nothing is important. Use size, color, position, and animation to guide attention to the most important elements.

Good game UI is a conversation between the game and the player. Keep it clear, keep it honest, and keep it out of the way when it's not needed.