# Agent Instructions

## 1. Purpose

This document establishes the general instructions and constraints for AI coding agents working on this project.

Agents are expected to help develop and maintain the game while respecting its documented architecture, design decisions, and development standards.

The human project owner retains final authority over architectural decisions, game design, and implementation direction.

## 2. Required Reading

Before making changes, agents MUST review the documentation relevant to their task.

At a minimum, agents MUST read:

- `docs/architecture.md` — system architecture, component responsibilities, communication boundaries, and development conventions.
- `docs/game_rules.md` — game mechanics and rules.

Agents MUST also review relevant Architecture Decision Records (ADRs) under `docs/decisions/` when their task involves an area covered by an existing decision.

Additional project documentation should be consulted as appropriate.

If documentation is missing, contradictory, or insufficient to make a sound implementation decision, agents SHOULD identify the ambiguity and request clarification rather than silently inventing requirements.

## 3. Architectural Compliance

All implementations MUST conform to the documented architecture.

In particular:

- Maintain the separation of presentation, application, domain, and infrastructure responsibilities.
- Preserve a single authoritative representation of game state.
- Do not place game rules or authoritative game-state management in presentation components.
- Do not introduce dependencies that violate documented layer boundaries.
- Keep domain logic independent of the Godot scene tree and presentation layer.
- Use explicitly defined interfaces and dependencies rather than relying on unrelated components' internal implementation details.
- Ensure state-changing operations preserve game rules and state consistency.

Agents MUST NOT introduce significant architectural changes without prior approval from the project owner.

When an architectural improvement appears necessary, agents SHOULD explain the problem, propose alternatives, and describe the implications before proceeding.

## 4. Implementation Practices

- Prefer straightforward, maintainable solutions over unnecessary abstractions or frameworks.
- Implement functionality incrementally in small, understandable changes.
- Follow existing naming, formatting, and organizational conventions.
- Use static typing in GDScript where practical.
- Avoid duplicating existing functionality.
- Do not introduce plugins, libraries, frameworks, or other external dependencies without approval.
- Do not make unrelated changes while implementing a requested feature.
- Do not silently change game rules or behavior to accommodate an implementation.

Agents SHOULD favor clear and explicit code over clever or unnecessarily compact solutions.

## 5. Testing and Quality

Agents MUST:

- Add or update appropriate tests when implementing or modifying functionality.
- Run relevant tests after making changes.
- Investigate test failures rather than bypassing or suppressing them.
- Avoid introducing unexplained errors or warnings.
- Report which tests were executed and their results.

Domain logic SHOULD be tested independently of the Godot scene tree wherever practical.

Tests should verify expected behavior, including relevant boundary and invalid-input cases, rather than simply reproducing implementation details.

## 6. Scope and Approval

Agents MUST distinguish between implementing an approved task and making decisions that change project direction.

The following require explicit project-owner approval:

- Changes to the documented architecture or layer responsibilities.
- Changes to game rules or intended gameplay behavior.
- New external dependencies or frameworks.
- Significant changes to project structure or development tooling.
- Changes that introduce new architectural patterns or abstractions with broad implications.

Agents MAY make ordinary implementation decisions within the boundaries of approved requirements and documented architecture.

When a task exposes an unresolved design decision, agents SHOULD explain the options and recommend an approach rather than making an irreversible assumption.

## 7. Communication and Reporting

Agents SHOULD communicate clearly and concisely.

Before making significant changes, agents SHOULD summarize:

- Their understanding of the requested functionality.
- The components likely to be affected.
- Their proposed implementation approach.
- Any assumptions or unresolved questions.

After completing a task, agents MUST summarize:

- What was changed.
- Important implementation decisions.
- Tests executed and their results.
- Any known limitations, outstanding issues, or follow-up work.

Agents MUST NOT claim that functionality or tests are complete unless they have verified the result.