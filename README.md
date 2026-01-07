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
| Fireball (`fireball`) | Unlock | Always in pool | Grants the Fireball ability controller (launches a fireball at a random enemy). |
| Fireball Level (`fireball_level`) | Level | Added after unlocking Fireball | +3 damage per level, +3 splash radius per level, and +0.15 scale per level. |
| Sword Level (`sword_level`) | Level | Always in pool | Adds +1 sword per attack per level. |
| Whip (`whip`) | Unlock | Always in pool | Grants the Whip ability controller (aimed whip strike). |
| Whip Level (`whip_level`) | Level | Added after unlocking Whip | Longer whip per level. |

### Damage, rate, and speed upgrades

| Upgrade | Availability | Effect |
| --- | --- | --- |
| Axe Damage (`axe_damage`) | Added after unlocking Axe | +50% axe damage per level. |
| Sword Damage (`sword_damage`) | Always in pool | +35% sword damage per level. |
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
| Rat | Added at arena difficulty 12 | 37.5 HP, 105 max speed, 1.5 acceleration, 2 contact damage | Fast bruiser with higher contact damage. |
| Spider | Added via level keyframes | 20 HP, 55 max speed, 2.0 acceleration, 1 contact damage | Mid-speed melee chaser. |
| Ghost | Added via level keyframes | 15 HP, 60 max speed, 3.0 acceleration, 1 contact damage | Only one ghost can exist at a time. |

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
| 8 | Dragon | 5 |
| 12 | Rat | 4 |
| 14 | Ghost | 1 |

**WFC test level (`level_id = wfc_test`)**

| Arena difficulty | Enemy added | Weight added |
| --- | --- | --- |
| 1 | Rat | 15 |
| 3 | Spider | 5 |
| 5 | Ghost | 2 |
