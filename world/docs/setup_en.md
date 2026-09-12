# ITGMania Archipelago Setup Guide

ITGMania is a rhythm game engine. This guide explains how to set up ITGMania to play in an Archipelago multiworld.

## Overview

There are **two** possible game modes:

1. **Boss Key Hunt**: Boss keys are randomly placed throughout your song pool in the multiworld. Collect the required number of keys to unlock a designated Goal Song. Clear the Goal Song to win your run.
2. **Clear Count**: Clear a configured number of unlocked songs from your pool to achieve victory.

## Song Pool

If unspecified, the world will generate using the **Club Fantastic Seasons 1 & 2** packs as your default song pool. You can also create a custom song pool directly inside ITGMania using the built-in Client Module AP Config Tool. The module generates and exports a player YAML containing your custom pool to provide to the multiworld host.

---

## 1. Client Installation

### Prerequisites
* [ITGMania](https://www.itgmania.com/) (1.3.0+)
* [Simply Love](https://github.com/itgmania/simply-love-itgmania) theme, or derivative

### Steps
1. Copy `archipelago.lua` and the `Archipelago` folder from the `module/` directory into your Simply Love theme modules directory:
   `ITGMania/Themes/Simply Love/Modules/`
   *(Optimized for standard **Simply Love**. UI elements may require styling adjustments on theme forks like Zmod, ArrowCloud, or DigitalDance).*
2. Whitelist your Archipelago server host in your ITGMania preferences. Open `preferences.ini` in your user save directory (e.g. `%APPDATA%\ITGmania\Save\preferences.ini` on Windows) and append your server host to the `HttpAllowHosts` entry:
   ```ini
   HttpAllowHosts=localhost,archipelago.gg
   ```
3. Copy `module/archipelago.ini.example` to `Save/Archipelago/archipelago.ini` in your user save directory (e.g. `%APPDATA%\ITGmania\Save\Archipelago\archipelago.ini` on Windows), or start ITGMania once with the module installed to generate it automatically, then configure your connection credentials:
   ```ini
   [Archipelago]
   Host = ws://localhost:38281        # Multiworld server host and port (use wss:// for public servers like archipelago.gg)
   Slot = ITGManiaPlayer              # Your slot name (must match your YAML player name)
   Password =                         # Room password (if required)
   ```

---

## 2. Multiworld Generation & Seed Setup

### Step A: Configure and Generate Your YAML in ITGMania
1. Start ITGMania and go to the song selection screen (`ScreenSelectMusic`).
2. Open the Sort Menu (press **`Left` + `Right`** simultaneously).
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
   `Save/Archipelago/YAMLS/[PlayerName].yaml`

### Step B: Generate the Multiworld Seed
1. Place the generated `[PlayerName].yaml` file into your Archipelago generator `Players/` folder.
2. If playing with custom song pools, the Archipelago generator will scan all player YAMLs at generation time and build the master song database union automatically. If a player does not select a custom song pool, the generator defaults to the **Club Fantastic Seasons 1 & 2** pools.
3. Run the Archipelago generator to produce your multiworld seed.

### Step C: Running the World
1. When the host starts the room and ITGMania is running with matching credentials in `Save/Archipelago/archipelago.ini`, the module will connect automatically.

---

## 3. Options Reference

* **Game Mode**:
  * `clear_count`: Clear a specified number of songs to win the game.
  * `boss_key`: Unlock and clear a specific Goal Song after collecting a target number of Boss Keys.
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

### Dynamic Playlist & Song Unlocks
When a new song chart is unlocked, the client writes the chart to a local playlist file (`.../Themes/[THEME_NAME]/Other/Playlists/Archipelago - <SeedName>.txt`) and automatically triggers the ITGMania C++ engine to reload the playlist so newly unlocked songs appear live.

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

*I generated the YAML and started the game, but it's not connecting!*

Ensure that your `Save/Archipelago/archipelago.ini` file is configured with the correct `Host` and `Slot` name (matching the `PlayerName` in your generated YAML), and that the server host is listed in `HttpAllowHosts` in your `preferences.ini`.

*Where are the files generated for players running the game?*

* Playlist: `.../Themes/[THEME_NAME]/Other/Playlists/Archipelago - <SeedName>.txt`
* Cache files: `Save/Archipelago/SAVE_AP_[SEED]/...`
* YAMLs: `Save/Archipelago/YAMLS/...`
