# ITGMania Archipelago Setup Guide

ITGMania is a rhythm game engine. This guide explains how to set up ITGMania to play in an Archipelago multiworld.

## Overview

There are **two** possible game modes.

1. Boss Key Hunt

In this mode, boss keys are randomly placed throughout your song pool. Collect them to unlock a boss song. Complete the
boss song, and you win your run. You unlock songs from your pool throughout the run in addition to the keys.

2. Clear Count

In this mode, simply clear the desired number of songs from your song pool, and you win. You can configure the number of
starting songs and unlockable songs.

## Song Pool

If unspecified, the world will generate using the Club Fantastic Seasons 1 and 2 packs as your song pool. However, by using the
[ITGMania Archipelago Client Module](https://github.com/bwaggone/ITGMania-Archipelago-Module), you can create a custom song pool.
The module will generate and export a player yaml to provide to the host.

---

## 1. Client Installation

1. Clone or download the [ITGMania Archipelago Client Module](https://github.com/bwaggone/ITGMania-Archipelago-Module).
2. Copy `archipelago.lua`, `archipelago.ini`, and the `Archipelago` folder into your ITGMania theme directory under:
   `ITGMania/Themes/[THEME_NAME]/Modules/`
   *(Optimized for standard **Simply Love**. UI elements may require styling adjustments on theme forks like Zmod, ArrowCloud, or DigitalDance).*
3. Open `archipelago.ini` in a text editor and configure your connection credentials:
   ```ini
   [Archipelago]
   Host = ws://archipelago.gg:38281   # The multiworld server host and port
   Slot = ITGManiaPlayer              # Your slot name (must match your YAML player name)
   Password =                         # Password if required
   ```

*Note*, the world does not need to be generated yet, and you will need to start ITGMania with the module loaded to generate your yaml.

---

## 2. Multiworld Generation & Seed Setup

### Step A: Install the Module
1. Install the module as described above.

### Step B: Configure and Generate Your YAML in ITGMania
1. Start ITGMania and go to the song selection screen (`ScreenSelectMusic`).
2. Open the Sort Menu (typically by pressing **`Left` and `Right`** together).
3. Select **`AP Config Tool`** from the options.
4. Adjust your game settings:
   * **Player Name**: Set this to match your slot name in the multiworld.
   * **Game Mode & Goals**: Choose between clearing a specific number of songs (**Clear Count**) or hunting down keys to unlock and pass a target song (**Boss Key**).
   * **Scoring Rules**: Choose your score system evaluation type and the minimum passing percentage.
   * **Score Checks**: Toggle additional checks (e.g. 85%, 90%, 96%, 98%, 99%, Quad, Quint) to add more locations per song.
   * **Traps & Mod Items**: Enable speed/appearance mods in the item pool and customize which traps other players can send you.
5. Select **`Configure Song Pool...`** to customize your song library:
   * Press **`MenuUp`/`MenuDown`** to navigate.
   * Press **`Start`** to expand or collapse packs.
   * Press **`MenuLeft`/`MenuRight`** to check/uncheck songs or entire packs.
6. Select **`--- GENERATE YAML ---`**. This creates your configuration file under:
   `ITGMania/Themes/[THEME_NAME]/Modules/Archipelago/YAMLS/[PlayerName].yaml`

### Step C: Generate the Multiworld Seed
1. Place the generated `[PlayerName].yaml` file into your Archipelago generator `Players/` folder.
2. If playing with custom song pools, the Archipelago generator will scan all player YAMLs at generation time and build the master song database union automatically. If a player does not select a custom song pool, the generator defaults to the **Club Fantastic Seasons 1 & 2** pools.
3. Run the Archipelago generator to produce your multiworld seed.

### Step D: Running the World
1. If your generated PlayerName matches the value in the ini, when the host starts the world it should connect automatically!

---

## 3. Options Reference

* **Game Mode**:
  * `clear_count`: Clear a specified number of songs to win the game.
  * `boss_key`: Unlocks and clear a specific Goal Song after collecting a target number of Boss Keys.
* **Win Count** (Clear Count Mode only): The number of song charts passed/cleared required to win the game.
* **Goal Song** (Boss Key Mode only): The exact song title (from your song pool) that is your Goal Song. Leave empty to select one randomly from your pool.
* **Boss Key Name / Count / Required** (Boss Key Mode only): Customize the flavor name of the boss key items, the total number placed in the multiworld, and how many are needed to unlock the Goal Song.
* **Number of Charts**: Total number of charts to include in your pool (the rest of the song library will not appear in the seed).
* **Number of Starting Charts**: The number of charts you start with unlocked.
* **Passing Score**: Desired score percentage threshold (0-100) to clear a chart. Set to `0` to count any clear.
* **Score Type**: Grade type to evaluate:
  * `money`: Money Score (Standard percentage of total dance points).
  * `ex`: EX Score.
  * `high_ex`: High EX Score (FA+ scoring style).
* **Fail Allowed**: If enabled, failing a song counts as a pass (requires Immediate Continue to be enabled in ITGMania options so you don't get kicked out to the game over screen early).
* **Score checks (85%, 90%, 96%, 98%, 99%, Quad, Quint)**: Toggles to create additional location checks per song at these score thresholds.
* **Enable Mod Items**: Adds speed mods, appearance mods (e.g. Mini, Mirror, Left Right Mirror, Up Down Mirror), and screen filters as items in the pool. When unlocked, they clamp the maximum values you can choose in the game options menu.
* **Trap Items**: A list of trap items other players can send you:
  * `Trap - Reverse Scroll`: Forces reverse scroll direction.
  * `Trap - Dark`: Toggles the dark filter (hiding arrows/judgement markers).
  * `Trap - Half Speed`: Halves your scroll speed.
  * `Trap - Mini`: Renders arrows at a very small size.
* **Trap Chance**: Percentage of your junk item pool that should consist of Traps instead of plain filler items.
* **Death Link**: If enabled, failing a song sends a death signal to all other players in the multiworld. If another player dies, the module triggers a song failure on your screen.

---

## 4. In-Game Features & Controls

### Dynamic Playlist & Song Wheel Updates
When a new song chart is unlocked, the client writes the chart to a local playlist file (`.../Themes/[THEME_NAME]/Other/Playlists/Archipelago - <SeedName>.txt`) and automatically triggers the ITGMania C++ engine to reload. If you are sorted by **Preferred** on the music wheel, new unlocks appear instantly.

### In-Game Status Overlay (`F10`)
Press **`F10`** on the music wheel to open the scrollable AP Status overlay:
* View room metadata, seed name, win goal progress, and active modifier limits.
* Inspect the list of unlocked charts and highlight a song to view its active **Clear Condition** (passing score target, fail allowance, and the status of its individual score threshold checks).

### Interactive Score Evaluation Overlay
If you have unused **Score Booster** items sent by other players, a custom interactive panel auto-pops on the song evaluation screen.
* **`MenuUp`/`MenuDown`**: Select the scoring system (Money, EX, or High EX).
* **`MenuLeft`/`MenuRight`**: Add or remove boosters to preview check completions.
* **`Start`**: Commit the boosters and submit your checks.
* **`Back`/`Escape`**: Skip applying boosters and send baseline checks.

---

## FAQ

*I generated the yaml and started the world, but it's not connecting!*

Ensure that your `archipelago.ini` file is correct, especially your SlotName. It should match the name of the Yaml file provided to the host.

*Where are the files generated for players running the game?*

* Playlist: `.../Themes/[THEME_NAME]/Other/Playlists/Archipelago - <SeedName>.txt`
* Cache files: `.../Themes/[THEME_NAME]/Modules/Archipelago/AP_[SEED]/...`
* YAMLs: ``.../Themes/[THEME_NAME]/Modules/Archipelago/YAMLS/...`
