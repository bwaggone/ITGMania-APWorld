# ITGMania Archipelago World (v0.5.1)

An [Archipelago](https://archipelago.gg/) Multiworld Randomizer integration for [ITGMania](https://www.itgmania.com/). 

This repository contains both the **Archipelago World (`.apworld`)** generator code and the **ITGMania Client Module**.

---

## 📁 Repository Structure

```
ITGMania-APWorld/
├── module/                  # ITGMania Client Module (Lua)
│   ├── Archipelago/         # Sub-modules (network, UI, evaluator, playlist, traps, etc.)
│   ├── archipelago.lua      # Theme module entry point
│   ├── archipelago.ini      # Client connection configuration
│   └── README.md            # Module-specific documentation
└── world/                   # Archipelago World Package (Python / .apworld)
    ├── docs/                # Setup & options documentation
    ├── helpers/             # Song dumping and utility scripts
    ├── test/                # Logic and generation unit tests
    ├── ITGManiaCollection.py# Main song catalog code & custom pool parser
    ├── __init__.py          # APWorld entry point
    ├── archipelago.json     # APWorld metadata
    ├── items.py             # Item definitions (songs, keys, mods, boosters, traps)
    ├── locations.py         # Location definitions (clear checks, score thresholds)
    ├── options.py           # Multiworld YAML player options
    ├── regions.py           # Region graph & world access rules
    ├── rules.py             # Clear count, boss key, and mod requirement logic
    ├── web_world.py         # Web interface integration
    └── world.py             # ITGManiaWorld class lifecycle
```

---

## 🌟 Key Features

* **Two Game Modes**:
  * **Boss Key Hunt**: Collect a target number of boss keys hidden in the multiworld to unlock and pass a designated **Goal Song**.
  * **Clear Count**: Clear a configured number of unlocked songs to achieve victory.
* **In-Game YAML Config Tool**:
  * Direct in-game configuration tool accessible from Simply Love's music wheel sort menu.
  * Interactive library scanner: select custom packs or songs to build a `custom_song_pool`.
  * Exports formatted Archipelago player YAML directly to disk (`.../Modules/Archipelago/YAMLS/`).
* **Live Music Wheel & Playlist Sync**:
  * Unlocked charts are automatically appended to a local playlist (`Archipelago - <SeedName>.txt`).
  * Triggers the ITGMania C++ engine to reload the playlist live. When sorted by **Preferred** on `ScreenSelectMusic`, newly received charts appear instantly.
* **In-Game Status Dashboard (`F10`)**:
  * Press **`F10`** on the music wheel to view seed status, goal progression, active modifier limits, and unlocked songs.
  * Inspect individual songs to check clear targets (Money/EX/High EX threshold, fail allowance) and check statuses (`[x]` / `[ ]`).
* **Interactive Score Booster Evaluation**:
  * Receive consumable **Score Booster** items (`+0.25%` each) from other players.
  * If unused boosters are available, an interactive distribution panel appears on `ScreenEvaluation` allowing you to apply boosters to Money, EX, or High EX scores before submitting checks.
* **Traps, Modifiers & DeathLink**:
  * Unlockable modifier limits (Speed Mods, Mini, Mirror, Filters) clamp in-game menu options until unlocked.
  * Trap items (Forced Mini, Reverse Scroll, Half Speed, Dark).
  * Full **DeathLink** support: failing a song sends a death signal, and receiving a death signal instantly fails your current song.
* **Offline Seed & DataPackage Caching**:
  * Caches remote player names and item definitions locally so unlock notifications remain descriptive even during network hiccups.

---

## 🚀 Quick Start Guide

### 1. Client Installation (ITGMania)

1. Copy the contents of the `module/` directory (`archipelago.lua`, `archipelago.ini`, and the `Archipelago/` folder) into your Simply Love theme modules folder:
   ```
   ITGMania/Themes/Simply Love/Modules/
   ```
   *(Note: Designed for **Simply Love**. UI layout may require adjustments on theme forks like Zmod, ArrowCloud, or DigitalDance).*
2. Open `archipelago.ini` in a text editor to configure connection settings:
   ```ini
   [Archipelago]
   Host = wss://archipelago.gg:38281   # Multiworld server host and port
   Slot = ITGManiaPlayer              # Player slot name (must match your YAML player name)
   Password =                         # Room password (if required)
   ```

### 2. Archipelago World Installation (Generator / Host)

To install the world package into your Archipelago installation:

* **As an `.apworld` bundle**:
  Place the `.apworld` bundle from the releases page into your `custom_worlds` or `lib/worlds` directory.
* **Direct source**:
  Zip the contents of the `world/` folder (so `__init__.py` and `archipelago.json` are at the root of the archive) and rename the extension to `.apworld` (e.g., `itgmania.apworld`). Place it in your Archipelago `custom_worlds/` or `lib/worlds/` directory.

---

## 🎮 How to Play

### Step 1: Configure & Generate Your Player YAML
1. Launch ITGMania and enter the song select wheel (`ScreenSelectMusic`).
2. Open the Sort Menu (press **`Left` + `Right`** simultaneously).
3. Select **`AP Config Tool`**.
4. Adjust your settings:
   * **Player Name**: Set your slot name.
   * **Game Mode**: Choose **Boss Key** or **Clear Count**.
   * **Scoring Rules**: Set your target score system (Money, EX, High EX) and minimum passing score.
   * **Score Checks**: Enable additional check thresholds per song (85%, 90%, 96%, 98%, 99%, Quad, Quint).
   * **Modifiers & Traps**: Configure speed mod clamps, appearance mods, trap frequencies, or DeathLink.
5. Select **`Configure Song Pool...`** to pick specific song packs or songs from your installed library.
6. Select **`--- GENERATE YAML ---`**. The file will be written to:
   ```
   .../Themes/[THEME_NAME]/Modules/Archipelago/YAMLS/[PlayerName].yaml
   ```

### Step 2: Generate Multiworld Seed
1. Provide your generated `[PlayerName].yaml` to the multiworld host or place it into the Archipelago `Players/` directory.
2. If custom song pools are used, the generator will parse player YAMLs and build the unified song catalog automatically. (If no custom song pool is configured, it falls back to **Club Fantastic Seasons 1 & 2**).
3. Generate the seed.

### Step 3: Connect & Play
1. Ensure your `archipelago.ini` has the correct `Host` and `Slot` name.
2. Launch ITGMania. The client module will connect to the server in the background.
3. On `ScreenSelectMusic`, change your sort to **Preferred** to view your unlocked Archipelago song wheel.
4. Clear songs and achieve score thresholds to send checks and receive progression items!

---

## 🕹️ Controls Reference

### Song Wheel Status Overlay (`F10`)
*Accessible from `ScreenSelectMusic`.*
* **`F10` / `Escape`**: Toggle the status overlay.
* **`MenuUp` / `MenuDown`** (or Up/Down arrows): Scroll through unlocked song charts.
* **`R`**: Force playlist regeneration and request sync with the server.
* **`Start` / `Select`**: Close the overlay.

### Evaluation Score Booster Overlay
*Triggers on `ScreenEvaluation` when you have unspent Score Booster items.*
* **`MenuUp` / `MenuDown`**: Select the scoring system row (Money, EX, High EX).
* **`MenuLeft` / `MenuRight`**: Allocate or deallocate score boosters (`+0.25%` each) to preview check unlocks.
* **`Start`**: Apply boosters and submit checks.
* **`Back` / `Escape`**: Skip booster application and submit baseline score checks.

---

## ⚙️ Key Options Reference

| Option | Values | Description |
|---|---|---|
| `game_mode` | `boss_key`, `clear_count` | Win by collecting keys and passing a goal song, or by clearing a set number of songs. |
| `win_count` | Integer (`1` - `500`) | Number of song charts required to clear in Clear Count mode. |
| `goal_song` | Text | Title of the boss song (Boss Key mode). Leave blank for a random pool selection. |
| `boss_key_count` | Integer | Total boss keys placed in the multiworld. |
| `boss_keys_required` | Integer | Number of boss keys needed to unlock the goal song. |
| `score_type` | `money`, `ex`, `high_ex` | Score grading system used to evaluate song completions. |
| `passing_score` | `0` - `100` | Percentage required to clear a chart (set to `0` for any clear). |
| `fail_allowed` | `true`, `false` | Whether failing a song still evaluates score checks (requires *Immediate Continue* in ITGMania). |
| `score_checks_*` | `true`, `false` | Enable checks at 85%, 90%, 96%, 98%, 99%, Quad (100%), and Quint thresholds. |
| `enable_mod_items` | `true`, `false` | Add speed/appearance/filter limiters as progressive items in the pool. |
| `death_link` | `true`, `false` | Fail songs when other players die; trigger deaths when you fail a song. |
| `trap_chance` | `0` - `100` | Percentage of filler items replaced with traps. |

---

## 🛠️ Development & Testing

* **Running Tests**:
  ```bash
  pytest world/test/test_logic.py
  ```
* **Debug Logging**:
  Monitor `AppData/Roaming/ITGmania/Logs/log.txt` (look for `[AP-Module]` logs).
