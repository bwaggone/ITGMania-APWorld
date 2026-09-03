from __future__ import annotations
from typing import TYPE_CHECKING, NamedTuple, Optional, Dict
from BaseClasses import Item, ItemClassification

import sys
import os
from math import floor
import settings
import Utils

if TYPE_CHECKING:
    from .world import ITGMania

"""
Items in ITGManaia are either charts, or visual mods (appearance options, speed mods, etc).
"""

class ITGManiaItem(Item):
    game = "ITGMania"

class ITGManiaChart():
    def __init__(self, name: str, style: str = "Dance_Single", difficulty: str = "Challenge", hash: str = ""):
        self.name = name
        self.style = style
        self.difficulty = difficulty
        self.hash = hash

CLUB_FANTASTIC_POOLS = [
    # Club Fantastic Season 1
    "Club Fantastic Season 1/BACK UP",
    "Club Fantastic Season 1/BOSSY",
    "Club Fantastic Season 1/Can't You Bounce!?",
    "Club Fantastic Season 1/COOL_EXCEPTION",
    "Club Fantastic Season 1/Dysangel",
    "Club Fantastic Season 1/Fantastic World",
    "Club Fantastic Season 1/Horsepower",
    "Club Fantastic Season 1/Melody Mountain",
    "Club Fantastic Season 1/Oceania 909",
    "Club Fantastic Season 1/Roadman",
    "Club Fantastic Season 1/Shoes (Club Fantastic Edit)",
    "Club Fantastic Season 1/Six Million",
    "Club Fantastic Season 1/Wandering (VIP)",
    "Club Fantastic Season 1/Y.E.A.H.",
    # Club Fantastic Season 2
    "Club Fantastic Season 2/Adore",
    "Club Fantastic Season 2/Artifacts",
    "Club Fantastic Season 2/Beachside Photoshoot",
    "Club Fantastic Season 2/BOSSY (Jorts Speedy Mix)",
    "Club Fantastic Season 2/demonstration protocol",
    "Club Fantastic Season 2/DNA",
    "Club Fantastic Season 2/Oceania 909 (T2KAZUYA Remix)",
    "Club Fantastic Season 2/POT",
    "Club Fantastic Season 2/Save New Jersey",
    "Club Fantastic Season 2/Singularity",
    "Club Fantastic Season 2/SSS",
    "Club Fantastic Season 2/Step It",
    "Club Fantastic Season 2/Succulynt",
    "Club Fantastic Season 2/SWEETHEART",
    "Club Fantastic Season 2/TerpZone",
    "Club Fantastic Season 2/We Can Bounce!!",
    "Club Fantastic Season 2/Wipeout",
    "Club Fantastic Season 2/WRVTH",
]

def extract_custom_songs_from_yamls() -> set[str]:
    custom_songs = set()
    if "--player_files_path" in sys.argv:
        folder_path = sys.argv[sys.argv.index("--player_files_path") + 1]
    else:
        try:
            folder_path = Utils.user_path(settings.get_settings().generator.player_files_path)
        except Exception:
            return custom_songs
            
    if not os.path.isdir(folder_path):
        return custom_songs

    try:
        for entry in os.scandir(folder_path):
            if not entry.is_file() or not (entry.name.endswith(".yaml") or entry.name.endswith(".yml")):
                continue
            try:
                with open(entry.path, 'r', encoding='utf-8') as f:
                    file_content = f.read()
                    if "custom_song_pool" not in file_content:
                        continue
                    for parsed_yaml in Utils.parse_yamls(file_content):
                        itg_options = parsed_yaml.get("ITGMania", {})
                        pool = itg_options.get("custom_song_pool", None)
                        if isinstance(pool, list):
                            for song in pool:
                                if isinstance(song, str) and song.strip():
                                    custom_songs.add(song.strip())
            except Exception:
                pass
    except Exception:
        pass
            
    return custom_songs

ALL_CHARTS = None

def get_song_data() -> list[ITGManiaChart]:
    global ALL_CHARTS
    if ALL_CHARTS is not None:
        return ALL_CHARTS

    custom_pool_union = extract_custom_songs_from_yamls()
    combined_names = sorted(list(set(CLUB_FANTASTIC_POOLS) | custom_pool_union))
    ALL_CHARTS = [ITGManiaChart(name) for name in combined_names]
    return ALL_CHARTS

ALL_CHARTS = get_song_data()

def create_item(world: ITGMania, name: str) -> ITGManiaItem:
    mod_item = world.itgm_collection.mod_items.get(name)
    if mod_item:
        classification = ItemClassification.filler if "Mirror" in name else ItemClassification.useful
        return ITGManiaItem(name, classification, mod_item, world.player)

    trap_item = world.itgm_collection.trap_items.get(name)
    if trap_item:
        return ITGManiaItem(name, ItemClassification.trap, trap_item, world.player)

    bosskey = world.itgm_collection.bosskey_items.get(name)
    if bosskey:
        return ITGManiaItem(name, ItemClassification.progression, bosskey, world.player)

    filler = world.itgm_collection.filler_items.get(name)
    if filler:
        return ITGManiaItem(name, ItemClassification.filler, filler, world.player)
    
    chart = world.itgm_collection.item_names_to_id.get(name)
    if chart:
        return ITGManiaItem(name, ItemClassification.progression, chart, world.player)

def create_all_items(world: ITGMania) -> None:
    # Total locations is determined by the number of active locations per selected song
    # e.g., if you've got the 85 and 90 score checks enabled, each song will have 4 locations: -0, -1, -85, -90
    active_suffixes = ["-0", "-1"]
    if world.options.include_85_score_checks:
        active_suffixes.append("-85")
    if world.options.include_90_score_checks:
        active_suffixes.append("-90")
    if world.options.include_96_score_checks:
        active_suffixes.append("-96")
    if world.options.include_98_score_checks:
        active_suffixes.append("-98")
    if world.options.include_99_score_checks:
        active_suffixes.append("-99")
    if world.options.include_quad_score_checks:
        active_suffixes.append("-quad")
    if world.options.include_quint_score_checks:
        active_suffixes.append("-quint")

    num_charts = len(world.starting_songs) + len(world.included_songs)
    location_count = num_charts * len(active_suffixes)

    # 1. Add 1 copy of every song in included_songs (these are the unlockable songs)
    for song_name in world.included_songs:
        world.multiworld.itempool.append(create_item(world, song_name))

    # 2. Add Boss Keys if in Boss Key mode
    if world.options.game_mode == 1:
        from .options import BOSS_KEY_NAME_BY_KEY
        bosskey_name = BOSS_KEY_NAME_BY_KEY[world.options.boss_key_name.current_key]
        for _ in range(world.options.boss_key_count.value):
            world.multiworld.itempool.append(create_item(world, bosskey_name))

    # 3. Add speed/appearance mod items if enabled
    if world.options.enable_mod_items:
        for mod_name in world.itgm_collection.mod_items.keys():
            world.multiworld.itempool.append(create_item(world, mod_name))

    # 4. Fill the remaining spots with filler items or traps
    item_count = len(world.included_songs)
    if world.options.game_mode == 1:
        item_count += world.options.boss_key_count.value
    if world.options.enable_mod_items:
        item_count += len(world.itgm_collection.mod_items)
        
    items_left = location_count - item_count

    trap_item_names = [name.strip() for name in world.options.trap_items.value if name.strip()]
    trap_chance = world.options.trap_chance.value if trap_item_names else 0

    for _ in range(max(0, items_left)):
        if trap_item_names and world.random.randint(1, 100) <= trap_chance:
            item_name = world.random.choice(trap_item_names)
        else:
            item_name = world.get_filler_item_name()
        world.multiworld.itempool.append(create_item(world, item_name))