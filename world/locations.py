from __future__ import annotations
from typing import TYPE_CHECKING, NamedTuple, Optional, Dict
from BaseClasses import Location

from .items import ALL_CHARTS

if TYPE_CHECKING:
    from .world import ITGMania

"""
    ITGMania Locations are song clear conditions. By default, each song has a "0" and "1" location,
    which represent clearing no matter what. The player can also choose to enable additional score
    conditions, which add a location for each song representing that score threshold.
"""
class ITGManiaLocation(Location):
    game = "ITGMania"

def create_all_locations(world: ITGMania) -> None:
    region = world.get_region("Songwheel")

    # We want to add locations for each selected song based on enabled options
    all_selected_songs = world.starting_songs + world.included_songs

    locations_to_add = {}
    for song_name in all_selected_songs:
        # Default clear locations
        loc0 = f"{song_name}-0"
        loc1 = f"{song_name}-1"
        locations_to_add[loc0] = world.itgm_collection.song_locations[loc0]
        locations_to_add[loc1] = world.itgm_collection.song_locations[loc1]

        # Configurable score locations
        if world.options.include_85_score_checks:
            loc = f"{song_name}-85"
            locations_to_add[loc] = world.itgm_collection.song_locations[loc]
        if world.options.include_90_score_checks:
            loc = f"{song_name}-90"
            locations_to_add[loc] = world.itgm_collection.song_locations[loc]
        if world.options.include_96_score_checks:
            loc = f"{song_name}-96"
            locations_to_add[loc] = world.itgm_collection.song_locations[loc]
        if world.options.include_98_score_checks:
            loc = f"{song_name}-98"
            locations_to_add[loc] = world.itgm_collection.song_locations[loc]
        if world.options.include_99_score_checks:
            loc = f"{song_name}-99"
            locations_to_add[loc] = world.itgm_collection.song_locations[loc]
        if world.options.include_quad_score_checks:
            loc = f"{song_name}-quad"
            locations_to_add[loc] = world.itgm_collection.song_locations[loc]
        if world.options.include_quint_score_checks:
            loc = f"{song_name}-quint"
            locations_to_add[loc] = world.itgm_collection.song_locations[loc]

    region.add_locations(locations_to_add, ITGManiaLocation)
    