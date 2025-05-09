# Ascension

*A 2D narrative-driven roguelike based on the novel Tian Guan Ci Fu.*  
Developed using the Love2D framework (Lua).

<div align="center">
  <img src="resources/images/ascension1.png" width="70%">
  <img src="resources/images/ascension2.png" width="70%">
  <img src="resources/images/ascension3.png" width="70%">
</div>

---

## 🕹️ Gameplay Overview

**Ascension** follows Huacheng as he storms the Heavenly Court, challenging Martial and Literature Gods in a sequence of battles and debates. The gameplay blends **action-combat** with **dialogue-driven narrative interludes**.

### Current Playable Sections

- Huacheng enters Heaven and challenges the Martial Gods
- Huacheng defeats multiple Heavenly Officials in combat

### In-Progress Sections

- Debates with Literature Gods (WIP)
- Temple-burning sequences (WIP)
- Huacheng's origin story in Mt. Tonglu (WIP)

---

## Controls

| Action              | Key / Mouse |
|---------------------|-------------|
| Move                | WASD        |
| Melee attack (slash)| Left Mouse  |
| Ranged attack       | Right Mouse |
| Teleport            | Spacebar    |
| Advance dialogue    | Spacebar    |
| Open settings       | Escape      |

---

## Player Stats

| Attribute       | Value             |
|----------------|-------------------|
| Health          | 100              |
| Move Speed      | 200 px/s         |
| Melee Damage     | 5               |
| Melee Range      | 120             |
| Melee Cooldown   | 1s              |
| Ranged Damage    | 2 per projectile |
| Ranged Projectiles | 5 (spread)     |
| Ranged Cooldown | 2s               |
| Teleport Cooldown | 12s             |

---

## Player Abilities

### E-ming Slash (Melee)
- Wide area slash aimed at cursor.
- Cooldown: 1 second.

### Silver Butterflies (Ranged)
- Fires 5 projectiles in a spread.
- Cooldown: 2 seconds.

### Teleport
- Blink to mouse location within 370px radius.
- Cooldown: 12 seconds.
- Useful for dodging and repositioning.

---

## 👹 Enemy Types

### 🟡 Base Melee Unit
- Basic attacker with slashing behavior.
- Moderate health and movement speed.
- Color: Yellow.

### 🔴 Charge Unit
- Aggressive melee unit with a **charge dash** that deals high damage.
- Starts waves on cooldown to prevent early burst.
- Fastest movement.
- Color: Red.

### 🔵 Ranged Unit
- Casts a **beam attack** that damages anything in its path.
- Has a visible charge-up time.
- Fragile but dangerous.
- Color: Blue.

---

## Enemy Stats Scaling

Enemy stats scale per wave based on the following base stats:

| Base Stat        | Value     |
|------------------|-----------|
| Health per wave  | +4        |
| Speed per wave   | +15 px/s  |
| Max speed per wave | +15 px/s |
| Base attack damage | 1       |
| Base attack cooldown | 1.5s  |

Each enemy type applies multipliers to these values. For example:

- Charge units have **0.6× health**, **1.25× speed**, and **1.2× charge damage**
- Ranged units have **0.4× health**, **longer range**, and **beam attacks**

---

## Wave System

Enemies spawn in structured waves:

```lua
Enemy.spawnRates.waves = {2, 4, 6, 8, 10, 11}
