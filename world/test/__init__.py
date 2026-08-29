from test.bases import WorldTestBase
from ..world import ITGMania
from typing import cast

class ITGManiaTestBase(WorldTestBase):
    game = "ITGMania"

    def get_world(self) -> ITGMania:
        return cast(ITGMania, self.multiworld.worlds[self.player])
