# Vampire

## Upgrades

### Ability unlocks and level upgrades

| Upgrade | Type | Availability | Effect |
| --- | --- | --- | --- |
| Axe (`axe`) | Unlock | Always in pool | Grants the Axe ability controller (periodic spinning axe). |
| Axe Level (`axe_level`) | Level | Added after unlocking Axe | Adds +1 axe per attack per level. |
| Boomerang (`boomerang`) | Unlock | Always in pool | Grants the Boomerang ability controller (throws a returning boomerang). |
| Boomerang Level (`boomerang_level`) | Level | Added after unlocking Boomerang | +2 damage per level, +25 range per level, +3 penetration per level, +0.3 size scale per level. |
| Fireball (`fireball`) | Unlock | Always in pool | Grants the Fireball ability controller (launches a fireball at a random enemy). |
| Fireball Level (`fireball_level`) | Level | Added after unlocking Fireball | +3 damage per level, +3 splash radius per level, and +0.15 scale per level. |
| Sword Level (`sword_level`) | Level | Always in pool | Adds +1 sword per attack per level. |

### Damage, rate, and speed upgrades

| Upgrade | Availability | Effect |
| --- | --- | --- |
| Axe Damage (`axe_damage`) | Added after unlocking Axe | +50% axe damage per level. |
| Sword Damage (`sword_damage`) | Always in pool | +35% sword damage per level. |
| Sword Rate (`sword_rate`) | Always in pool | +20% sword attack rate per level. |
| Move Speed (`player_speed`) | Always in pool | +20% player movement speed per level. |

## Enemies

### Basic enemy types

| Enemy | Spawn behavior | Stats | Notes |
| --- | --- | --- | --- |
| Mouse | Always in pool | 10 HP, 30 max speed, 5.0 acceleration, 1 contact damage | Small melee chaser. |
| Wizard | Added at arena difficulty 8 | 10 HP, 45 max speed, 2.0 acceleration, 1 contact damage | Ranged caster that fires fireballs. |
| Rat | Added at arena difficulty 12 | 37.5 HP, 105 max speed, 1.5 acceleration, 2 contact damage | Fast bruiser with higher contact damage. |

### Worm enemy

| Enemy | Spawn behavior | Stats | Notes |
| --- | --- | --- | --- |
| Worm | Added at arena difficulty 6 | 20 HP, 15 segments, moves every 0.8s | Grid-based mover that avoids overlapping bodies, digs through blocked tiles, and explodes segments on death. |
