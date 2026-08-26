## fast-switch.lua

This Lua script is designed for Neverlose (CS:GO cheat API) and implements a Fast Switch mechanic to optimize weapon switching with tickbase control.

- Uses FFI to interact with internal cUserCmd structures and packet handling

- Tracks player states (in‑air, shooting, weapon swap, fake duck)

- Overrides Weapon Actions (e.g., Auto Pistols) when active

- Adjusts tick_count and send_packet to minimize latency during weapon switching

- Ignores non‑combat items (knife, grenades, C4) to prevent unwanted behavior

## Key Functions:
- in_air(player) — checks if the player is airborne

- apply_tickbase(cmd, ticks_to_shift) — shifts tickbase for proper command execution

## Event hooks:
- events.aim_fire — records shot tick
- events.createmove — main fast switch logic
- events.shutdown — resets weapon actions on exit
