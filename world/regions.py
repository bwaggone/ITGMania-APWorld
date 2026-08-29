from __future__ import annotations
from typing import TYPE_CHECKING
from BaseClasses import Region

if TYPE_CHECKING:
    from .world import ITGMania

def create_and_connect_regions(world: ITGMania) -> None:
    songwheel = Region("Songwheel", world.player, world.multiworld)
    world.multiworld.regions.append(songwheel)
