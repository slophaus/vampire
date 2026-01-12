# Vampire

## Upgrades

### Ability unlocks and level upgrades

| Upgrade | Type | Availability | Effect |
| --- | --- | --- | --- |
| Axe (`axe`) | Unlock | Always in pool | Grants the Axe ability controller (periodic spinning axe). |
| Axe Level (`axe_level`) | Level | Added after unlocking Axe | Adds +1 axe per attack per level. |
| Boomerang (`boomerang`) | Unlock | Always in pool | Grants the Boomerang ability controller (throws a returning boomerang). |
| Boomerang Level (`boomerang_level`) | Level | Added after unlocking Boomerang | +2 damage per level, +25 range per level, +3 penetration per level, +0.2 size scale per level. |
| Dig (`dig`) | Unlock | Always in pool | Grants the Dig ability controller (burrow through dirt). |
| Dig Level (`dig_level`) | Level | Added after unlocking Dig | Shortens dig cooldowns and allows digging walls at level 2. |
| Fireball Level 1 (`fireball`) | Unlock | Always in pool | Grants the Fireball ability controller (launches a fireball at a random enemy). |
| Fireball Level (`fireball_level`) | Level | Added after unlocking Fireball | +3 damage per level, +3 splash radius per level, and +0.15 scale per level. |
| Poison Spit Level 1 (`poison_spit`) | Unlock | Always in pool | Grants the Poison Spit ability controller (spits poison at a random enemy). |
| Poison Spit Level (`poison_spit_level`) | Level | Added after unlocking Poison Spit | +5 poison damage per level, +20% attack rate per level, and +0.1 scale per level. |
| Sword Level (`sword_level`) | Level | Always in pool | Adds +1 sword per attack per level. |
| Whip (`whip`) | Unlock | Always in pool | Grants the Whip ability controller (aimed whip strike). |
| Whip Level (`whip_level`) | Level | Added after unlocking Whip | Longer whip per level. |

### Damage, rate, and speed upgrades

| Upgrade | Availability | Effect |
| --- | --- | --- |
| Axe Damage (`axe_damage`) | Added after unlocking Axe | +5 axe damage per level. |
| Sword Damage (`sword_damage`) | Always in pool | +5 sword damage per level. |
| Sword Rate (`sword_rate`) | Always in pool | +20% sword attack rate per level. |
| Move Speed (`player_speed`) | Always in pool | +20% player movement speed per level. |
| Health (`player_health`) | Always in pool | +8 max health per level and heals 8 on pickup. |

## Whip settings

* The whip uses 14 segments.
* Level 1: segment length 8 with a 0.67 segment scale.
* Level 2: segment length 12 with a 1.0 segment scale.
* Level 3: segment length 16 with a 1.33 segment scale.

## Enemies

Enemies spawn on a timer that accelerates with arena difficulty, and they appear on walkable
tiles just outside the camera view. Spawns are also capped at 500 active enemies to prevent
runaway counts. Arena difficulty starts at 1 and increases every 15 seconds.

### Enemy spawn flow

* Spawn rate uses difficulty keyframes from each level's `spawn_rate_keyframes`. The keyframes map
  arena difficulty to a spawn rate (spawns per second). When difficulty lands between keyframes,
  the spawn rate is linearly interpolated; outside the range it clamps to the nearest keyframe.
* `EnemyManager` builds a weighted table of enemy types from each level's
  `enemy_spawn_keyframes`. Each keyframe `(difficulty, enemy_id, weight)` is applied once when the
  arena difficulty reaches the keyframe difficulty, adding `weight` to the enemy's entries in the
  weighted table. Ghosts can only exist once at a time; if the ghost slot is chosen while a ghost
  is alive, another enemy is picked.
* For each spawn, it looks for walkable tilemap cells (no collision polygons) that are outside the
  camera view rectangle (`OFFSCREEN_MARGIN` pixels beyond the view), but still within
  `MAX_SPAWN_RADIUS_MULTIPLIER` (75%) of the view size. A random eligible cell is chosen and
  converted from tilemap local coordinates into a global spawn position.
* If there is no camera, no player, or no eligible spawn cell, the spawn attempt is skipped.

### Basic enemy types

| Enemy | Spawn behavior | Stats | Notes |
| --- | --- | --- | --- |
| Mouse | Always in pool | 10 HP, 30 max speed, 5.0 acceleration, 1 contact damage | Small melee chaser. |
| Dragon | Added at arena difficulty 8 | 10 HP, 45 max speed, 2.0 acceleration, 1 contact damage | Ranged caster that fires fireballs. |
| Rat | Added at arena difficulty 12 | 30 HP, 105 max speed, 1.5 acceleration, 2 contact damage | Fast bruiser with higher contact damage. |
| Spider | Added via level keyframes | 5 HP, 200 max speed, 100 acceleration, 0 contact damage + 5 poison damage | Fast jumper that can apply poison on contact. |
| Ghost | Added via level keyframes | 25 HP, 28 max speed, 3.0 acceleration, 0 contact damage | Only one ghost can exist at a time. |
| Scorpion | Added via level keyframes | 12 HP, 70 max speed, 50 acceleration, 2 contact damage | Poison spitter that fires ranged shots. |
| Wasp | Added via level keyframes | 6 HP, 160 max speed, 90 acceleration, 3 contact damage | Air enemy that wanders and lunges with a sting attack. |

### Worm enemy

| Enemy | Spawn behavior | Stats | Notes |
| --- | --- | --- | --- |
| Worm | Added at arena difficulty 2 | 20 HP, 15 segments, moves every 0.8s | Grid-based mover that avoids overlapping bodies, digs through blocked tiles, and explodes segments on death. |

### Enemy IDs

Enemy spawn keyframes reference these IDs:

| Enemy ID | Enemy |
| --- | --- |
| 0 | Mouse |
| 1 | Dragon |
| 2 | Rat |
| 3 | Worm |
| 4 | Spider |
| 5 | Ghost |
| 6 | Scorpion |
| 7 | Wasp |

### Level spawn rates

| Level | Spawn rate keyframes (difficulty → spawns/sec) |
| --- | --- |
| Main level (`level_id = main`) | 1 → 0.5, 3 → 1, 16 → 2 |
| WFC test level (`level_id = wfc_test`) | 1 → 0.1, 8 → 0.3, 16 → 1 |

### Level enemy progressions

Keyframes below describe the cumulative additions to the weighted spawn table as arena difficulty
increases.

**Main level (`level_id = main`)**

| Arena difficulty | Enemy added | Weight added |
| --- | --- | --- |
| 1 | Mouse | 15 |
| 2 | Worm | 1 |
| 4 | Spider | 2 |
| 6 | Scorpion | 3 |
| 8 | Dragon | 5 |
| 10 | Wasp | 2 |
| 12 | Rat | 4 |
| 14 | Ghost | 1 |

**WFC test level (`level_id = wfc_test`)**

| Arena difficulty | Enemy added | Weight added |
| --- | --- | --- |
| 1 | Rat | 15 |
| 3 | Spider | 5 |
| 4 | Scorpion | 2 |
| 5 | Ghost | 2 |
| 6 | Wasp | 2 |

## Level generator (WFC test level)

The WFC test level uses `WFCLevelGenerator` (`scripts/level/wfc_level_generator.gd`) to build a
procedural layout from a sample tilemap. The generator reads patterns from the sample tilemap,
collapses them into a target grid, then writes the resulting tiles into the target tilemap. If the
generator cannot solve within the time budget or attempt limit, it can partially fill the map and
use a fallback tile to complete the remaining cells.

### Scene wiring

The generator is attached to the WFC test level scene and expects:

* `target_tilemap_path`: tilemap that will be cleared and populated with generated tiles.
* `sample_tilemap_path`: tilemap that provides the source patterns; it is hidden at runtime.

### Generation flow

1. Extracts overlapping tile patterns of size `overlap_size` from the sample tilemap. Pattern
   adjacency is computed by matching overlapping edges in four directions.
2. Runs the WFC solver to collapse the target grid, optionally with backtracking and a time
   budget (`time_budget_seconds`).
3. Writes tiles into the target tilemap, then:
   * forces the outer border to the first `wall` tile type found,
   * positions the two doors in `LayerProps/DoorGroup` by picking a start cell near the bottom-left
     corner and a far (90th percentile) walkable cell, and
   * rebuilds the dirt border and moves players/enemies/props to the nearest floor cell.

### Chunked WFC

When `use_chunked_wfc` is enabled, the generator splits the target bounds into overlapping
chunks (size `chunk_size`, clamped to at least `overlap_size`) and solves each chunk in a
neighbor-biased order. By default it constrains each chunk to already-solved tiles so borders
line up; you can bypass those constraints by setting `ignore_chunk_borders` to `true`.

Chunked solving uses `max_attempts_per_solve` per chunk. If a chunk cannot be solved with the
current borders or its constraints are invalid, it is queued for a second pass where borders
are ignored. The chunked pass can still time out; in that case the generator writes whatever
tiles are solved and fills the rest of the chunk using the `time_budget_timeout_tile` mode.
Tiles from solved chunks are merged into the final output, and border conflicts are logged
when border constraints are active.

### Runtime controls

* `generate_on_ready` triggers generation when the scene loads.
* Pressing the `ui_accept` action (Enter/Space by default) regenerates with a new random seed.

### Timeout fallback tiles

When the solver times out, the generator fills the remaining empty cells using the
`time_budget_timeout_tile` mode:

* `dirt`: choose the first tile with `custom_data` type `dirt`.
* `most_common` / `least_common`: pick the most/least common tile in the sample.
* `random_tile`: choose a random tile from the sample for each missing cell.
* `random_same`: choose one random tile and reuse it for all missing cells.
* `random_top_three`: choose randomly from the three most common tiles.
