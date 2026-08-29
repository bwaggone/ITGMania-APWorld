# ITGMania Archipelago Module (v 0.5.0)

A Lua module for **ITGMania** that functions as a client integration for the **Archipelago Multiworld Randomizer**.
It automatically synchronizes song unlocks, sends checks upon song clears/score thresholds, manages progression
modifiers, and provides interactive UI overlays directly inside the **Simply Love** theme.

For details about the world setup and options, see the [Archipelago ITGMania World Setup Docs](https://github.com/bwaggone/Archipelago-Kiseki/blob/itgmania/worlds/itgmania/docs/setup_en.md).

---

## 🌟 Key Features
*   **Two Supported Game Modes**: Either hunt for boss keys and clear a goal song, or go for a simple clear count.
*   **YAML Config Tool Built-in**:
    *   Open the overlay from Simply Love's sort menu to configure slot options and select custom song pools.
    *   Generates player YAML configurations containing selected `custom_song_pool` paths.
    *   Writes YAML files to `.../Themes/[THEME_NAME]/Modules/Archipelago/YAMLS/[Player_Name].yaml`.
*   **Persistent WebSocket Connection**: A background client connection that runs continuously in ITGMania. It handles handshakes, syncs item unlocks, and automatically submits completed location checks.
*   **Dynamic Playlist & Live Song Wheel Updates**:
    *   Unlocked song charts are written to a local playlist file: `.../Themes/[THEME_NAME]/Other/Playlists/Archipelago - <SeedName>.txt`.
    *   The module forces the StepMania C++ engine to reload the playlist from disk when new songs arrive. If you are on the song selection screen (`ScreenSelectMusic`) and sorting by **Preferred**, the music wheel refreshes automatically so new unlocks appear instantly.
*   **In-Game Status Overlay (`F10`)**:
    *   Pressing **`F10`** on the music wheel opens a full-screen, scrollable dashboard.
    *   Displays: Room and Seed metadata, Win Goal progress, current modifier limits (if enabled), and a list of unlocked song charts.
    *   Selecting any song displays a detailed pane showing the current **Clear Condition** (active score type target, minimum percentage, fail allowance) and the individual status (`[x]` or `[ ]`) of all its checks.
*   **Interactive Score Evaluation Overlay**:
    *   Earn "Score Booster" items from the multiworld, which grant a `+0.25%` score increase.
    *   If you have unused boosters, a custom interactive panel auto-pops on the song evaluation screen.
    *   Allows you to distribute boosters to your **Money**, **EX**, or **High EX** performance.
    *   Displays a live preview of what check thresholds will unlock (e.g. *Clear Check 1*, *85% Score Check*) before you commit and send checks.
*   **Offline Seed Caching**:
    *   Caches DataPackage definitions (player names, item IDs, location definitions) to `.../Themes/[THEME_NAME]/Modules/Archipelago/SAVE_AP_<SeedName>/`.
    *   Does this for all connected players to show what players are unlocking songs for you, and what items you're unlocking for them.
*   **Real-Time Notifications**:
    *   Dynamic status messages slide into view in the screen footer when:
        *   Connecting or disconnecting from the server.
        *   Receiving items/charts from another player (e.g., `RECEIVED: Song Name (from PlayerName)`).
        *   Sending checks to another player (e.g., `CHECK SENT: Song Name (to PlayerName)`).
*   **Trap and Death Link Support**:
    *   Traps such as forced mini, forced half scroll, and reverse scroll speed.
    *   If Death Link is enabled, failing a song will cause all other players to die. Conversely, if another player dies in their game, it auto-fails your current song.

---

## ⚙️ Installation & Setup

### 1. Client Installation
1. Copy `archipelago.lua`, `archipelago.ini`, and the `Archipelago` folder into your ITGMania theme directory under:
   `.../Themes/[THEME_NAME]/Modules/`
2. Open `archipelago.ini` in a text editor and configure your connection credentials:
   ```ini
   [Archipelago]
   Host = ws://localhost:38281
   Slot = ITGManiaPlayer
   Password =
   ```
   *Note: While optimized for standard **Simply Love**, UI elements might require styling adjustments on theme forks (like Zmod, ArrowCloud, or DigitalDance).*
   *Extra Note: This is incompatible with DeadSync until it can support themes and Modules.*

### 2. Multiworld Generation & Seed Setup
1. In ITGMania, enter the song selection wheel (`ScreenSelectMusic`).
2. Open the Sort Menu (press **`Left` and `Right`** together) and select **`AP Config Tool`**.
3. Configure your desired player settings and select **`Configure Song Pool...`** to choose which song packs or individual songs you want in your pool.
4. Select **`--- GENERATE YAML ---`** to write your config YAML to the theme's `Modules/Archipelago/YAMLS/` directory.
5. Place this YAML in the Archipelago `Players/` folder. The generator automatically uses the `custom_song_pool` list defined inside your YAML. If no custom songs are chosen, it defaults to the **Club Fantastic Seasons 1 & 2** pools that come by default with ITGMania.
6. Generate your multiworld seed.

---

## 🕹️ Controls Reference

### Status Overlay (`F10`)
*Accessible from the Song Selection wheel (`ScreenSelectMusic`).*
*   **`F10` or `ESC`**: Open/Close the overlay.
*   **`MenuUp` / `MenuDown`** (or Arrow Up/Down): Scroll through the list of unlocked songs to inspect details.
*   **`R`**: Regenerate the local playlist and request a sync from the Archipelago server.
*   **`Start` / `Select`**: Close the overlay.

### Screen Evaluation Overlay
*Triggers automatically on `ScreenEvaluation` when unused Score Boosters are available.*
*   **`MenuUp` / `MenuDown`** (or Arrow Up/Down): Select which score system row to boost (Money, EX, High EX).
*   **`MenuLeft` / `MenuRight`** (or Arrow Left/Right): Decrease/increase the count of boosters to allocate.
*   **`Start`**: Confirm allocations and submit checks.
*   **`Back` / `Escape` / `Select`**: Exit without applying new boosters and send baseline checks.

---

## TODOs

* Support more complex items besides a score booster (combo shield? worst judgement upgrader?)
* Allow the user to specify their AP credentials in-game
* Decide if items should just be granted to the player as unlockable items, or if it should be shop-based (e.g. players will send coins, and those coins unlock items or charts SRPG-style)
* Make overlays look a little closer to the ones that appear in SRPG / ITL
* Add graphics for AP
* Improve item balance, so that we can drop speed + mini + bg modifiers sooner than songs
* Test Death Link logic
* Add attacks as traps