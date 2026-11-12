# ADR 0002: CSV-backed map definition

## Status

Accepted

## Context

The Western Front city locations and road connections are maintained as board setup data and should be the authoritative source for the game map. Presentation needs geographic data, while game rules should remain independent of files and screen coordinates.

## Decision

- `cities.csv` and `roads.csv` define the current map. Infrastructure reads and validates city coordinates, road endpoints, unique connections, and positive road sizes before game setup.
- The domain stores latitude/longitude and road size. City values and road sizes are preserved as data but do not change gameplay in this iteration.
- City IDs are derived from city names by lowercasing and replacing spaces and hyphens with underscores. Road endpoints must match those IDs exactly; manually prepared CSV uploads should be scrubbed for spelling and identifier consistency before use. The loader does not apply spelling aliases.
- Presentation projects geographic coordinates north-up while preserving geographic aspect ratio. Any marker offset used to keep labels readable remains visual-only; roads and city anchors stay tied to their geographic positions.

## Consequences

Updating the CSV changes the map used by new games without editing domain topology. Map setup failures are returned to the application as game-start errors. A future board renderer can choose a different projection without changing authoritative map data or game rules.

When export presets are added, their non-resource file filter must include the two CSV files.
