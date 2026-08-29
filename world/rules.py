from __future__ import annotations
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .world import ITGMania

# TODO: Set checks not just for passing a song, but also for getting a certain score on a song.

def set_all_rules(world: ITGMania) -> None:
    player = world.player
    group_size = world.options.group_size.value
    win_count = world.options.win_count.value

    # Combine starting and included songs to get the order
    all_selected_songs = world.starting_songs + world.included_songs

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

    for i, song_name in enumerate(all_selected_songs):
        loc_names = [f"{song_name}{suffix}" for suffix in active_suffixes]
        
        g = i // group_size
        if group_size > 1 and g > 0:
            previous_group_songs = all_selected_songs[(g - 1) * group_size : g * group_size]
            def make_group_rule(s_name: str, prev_songs: list[str]):
                return lambda state: state.has(s_name, player) and all(state.has(prev_s, player) for prev_s in prev_songs)
            rule = make_group_rule(song_name, previous_group_songs)
        else:
            def make_basic_rule(s_name: str):
                return lambda state: state.has(s_name, player)
            rule = make_basic_rule(song_name)

        for loc_name in loc_names:
            world.get_location(loc_name).access_rule = rule

    if world.options.game_mode == 1:
        from .options import BOSS_KEY_NAME_BY_KEY
        bosskey_name = BOSS_KEY_NAME_BY_KEY[world.options.boss_key_name.current_key]
        bosskeys_required = min(world.options.boss_keys_required.value, world.options.boss_key_count.value)
        goal_rule = lambda state: state.has(bosskey_name, player, bosskeys_required)
        
        goal_loc_names = [f"{world.goal_song}{suffix}" for suffix in active_suffixes]
        for loc_name in goal_loc_names:
            world.get_location(loc_name).access_rule = goal_rule

        world.multiworld.completion_condition[player] = lambda state: state.can_reach(f"{world.goal_song}-0", "Location", player)
    else:
        # Completion condition: must be able to reach at least `win_count` locations (charts) in total.
        def make_victory_rule(p: int, w: int, songs: list[str], suffixes: list[str]):
            return lambda state: sum(
                sum(1 if state.can_reach(f"{song}{suffix}", "Location", p) else 0 for suffix in suffixes)
                for song in songs
            ) >= w

        world.multiworld.completion_condition[player] = make_victory_rule(player, win_count, all_selected_songs, active_suffixes)
