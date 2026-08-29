import unittest
from . import ITGManiaTestBase

class TestITGManiaLogic(ITGManiaTestBase):
    options = {
        "number_of_charts": 20,
        "number_of_starting_charts": 3,
        "group_size": 5,
        "win_count": 10,
    }

    def test_progressive_and_group_logic(self) -> None:
        world = self.get_world()

        # Check starting locations are reachable without any items
        for song in world.starting_songs:
            self.assertTrue(self.can_reach_location(song + "-0"))
            self.assertTrue(self.can_reach_location(song + "-1"))

        # Check included songs are not reachable without their items
        for song in world.included_songs:
            self.assertFalse(self.can_reach_location(song + "-0"))
            self.assertFalse(self.can_reach_location(song + "-1"))

            # Collect the song item and verify it becomes reachable
            self.collect_by_name(song)
            self.assertTrue(self.can_reach_location(song + "-0"))
            self.assertTrue(self.can_reach_location(song + "-1"))

    def test_group_size_logic(self) -> None:
        world = self.get_world()
        all_selected_songs = world.starting_songs + world.included_songs
        group_size = world.options.group_size.value # 5

        # Initially, the player has only the starting songs (3 starting songs).
        # We need 2 more songs in Group 0 (indices 3 and 4) to complete Group 0.
        # Let's verify that a song in Group 1 (index 5) is unreachable even if we unlock it,
        # because Group 0 is not fully unlocked.

        group0_songs = all_selected_songs[0:5]
        group1_song = all_selected_songs[5]

        # Collect the song item for the Group 1 song.
        self.collect_by_name(group1_song)
        # Even with the song item collected, it should be unreachable because Group 0 is not complete.
        self.assertFalse(self.can_reach_location(group1_song + "-0"))

        # Now collect the remaining song items in Group 0 to complete Group 0.
        for song in group0_songs:
            if song not in world.starting_songs:
                self.collect_by_name(song)

        # Now that Group 0 is fully collected, the Group 1 song should be reachable!
        self.assertTrue(self.can_reach_location(group1_song + "-0"))

    def test_victory_condition(self) -> None:
        world = self.get_world()
        all_selected_songs = world.starting_songs + world.included_songs

        # Initially we can reach 6 locations (3 starting songs * 2).
        # win_count is 10, so the game should not be beatable yet.
        self.assertBeatable(False)

        # Collect one of the non-starting songs in Group 0 (index 3)
        self.collect_by_name(all_selected_songs[3])
        # Now we can reach 8 locations. Still not beatable.
        self.assertBeatable(False)

        # Collect the other non-starting song in Group 0 (index 4)
        self.collect_by_name(all_selected_songs[4])
        # Now we can reach 10 locations (index 0, 1, 2, 3, 4).
        # This meets the win_count = 10 requirement, so the game should be beatable!
        self.assertBeatable(True)

    def test_deduplication(self) -> None:
        from ..items import get_song_data
        charts = get_song_data()
        seen = set()
        for chart in charts:
            self.assertNotIn(chart.name, seen, f"Duplicate chart name found in get_song_data: {chart.name}")
            seen.add(chart.name)


class TestITGManiaScoreChecks(ITGManiaTestBase):
    options = {
        "number_of_charts": 10,
        "number_of_starting_charts": 2,
        "group_size": 1,
        "win_count": 5,
        "include_85_score_checks": True,
        "include_98_score_checks": True,
        "include_quad_score_checks": True,
    }

    def test_score_checks_generation(self) -> None:
        world = self.get_world()
        all_songs = world.starting_songs + world.included_songs

        # Verify that for each song, -0, -1, -85, -98, and -quad locations are generated and accessible (once unlocked)
        for song in all_songs:
            if song not in world.starting_songs:
                self.collect_by_name(song)
            self.assertTrue(self.can_reach_location(song + "-0"))
            self.assertTrue(self.can_reach_location(song + "-1"))
            self.assertTrue(self.can_reach_location(song + "-85"))
            self.assertTrue(self.can_reach_location(song + "-98"))
            self.assertTrue(self.can_reach_location(song + "-quad"))

            # Suffixes that were NOT enabled should NOT be generated/reachable
            with self.assertRaises(KeyError):
                self.can_reach_location(song + "-90")

    def test_exclusion_logic(self) -> None:
        world = self.get_world()
        all_songs = world.starting_songs + world.included_songs

        # Verify that -98 and -quad locations are in the exclude_locations set
        for song in all_songs:
            self.assertIn(song + "-98", world.options.exclude_locations.value)
            self.assertIn(song + "-quad", world.options.exclude_locations.value)

            # -85 and standard clear locations should NOT be excluded
            self.assertNotIn(song + "-0", world.options.exclude_locations.value)
            self.assertNotIn(song + "-1", world.options.exclude_locations.value)
            self.assertNotIn(song + "-85", world.options.exclude_locations.value)


class TestITGManiaModItems(ITGManiaTestBase):
    options = {
        "number_of_charts": 20,
        "number_of_starting_charts": 3,
        "group_size": 1,
        "win_count": 10,
        "enable_mod_items": True,
    }

    def test_mod_items_in_pool(self) -> None:
        world = self.get_world()
        itempool_names = [item.name for item in world.multiworld.itempool]

        # Verify that all 16 mod items are present in the item pool
        for mod_name in world.itgm_collection.mod_items.keys():
            self.assertIn(mod_name, itempool_names)

    def test_mod_items_classifications(self) -> None:
        from BaseClasses import ItemClassification
        world = self.get_world()
        for item in world.multiworld.itempool:
            if item.name in world.itgm_collection.mod_items:
                if "Mirror" in item.name:
                    self.assertEqual(item.classification, ItemClassification.filler)
                else:
                    self.assertEqual(item.classification, ItemClassification.useful)


class TestITGManiaModItemsInvalid(unittest.TestCase):
    # Since location_count (20) < unlocks_count (5) + mod_count (16) = 21,
    # generate_early should raise an OptionError and the generation should fail.
    def test_invalid_mod_items_options(self) -> None:
        import unittest
        from argparse import Namespace
        from BaseClasses import MultiWorld
        from Options import OptionError
        import worlds.AutoWorld as AutoWorld
        from worlds.itgmania import ITGMania

        multiworld = MultiWorld(1)
        multiworld.game[1] = "ITGMania"
        multiworld.player_name = {1: "Tester"}

        invalid_options = {
            "number_of_charts": 10,
            "number_of_starting_charts": 5,
            "group_size": 1,
            "win_count": 5,
            "enable_mod_items": True,
        }

        args = Namespace()
        world_type = AutoWorld.AutoWorldRegister.world_types["ITGMania"]
        for name, option in world_type.options_dataclass.type_hints.items():
            setattr(args, name, {
                1: option.from_any(invalid_options.get(name, option.default))
            })
        multiworld.set_options(args)

        world = multiworld.worlds[1]

        with self.assertRaises(OptionError):
            world.generate_early()


class TestITGManiaTrapsAndDeathLink(ITGManiaTestBase):
    options = {
        "number_of_charts": 10,
        "number_of_starting_charts": 2,
        "group_size": 1,
        "win_count": 5,
        "trap_items": ["Trap - Reverse Scroll", "Trap - Dark"],
        "trap_chance": 50,
        "death_link": True,
    }

    def test_trap_items_in_pool(self) -> None:
        from BaseClasses import ItemClassification
        world = self.get_world()
        itempool_names = [item.name for item in world.multiworld.itempool]

        # Check classification of trap items in pool
        for item in world.multiworld.itempool:
            if item.name in world.itgm_collection.trap_items:
                self.assertEqual(item.classification, ItemClassification.trap)

    def test_slot_data_exports(self) -> None:
        world = self.get_world()
        slot_data = world.fill_slot_data()
        self.assertTrue(slot_data["deathlink_enabled"])
        self.assertIn("Trap - Reverse Scroll", slot_data["trap_items"])
        self.assertIn("Trap - Dark", slot_data["trap_items"])


class TestITGManiaMultiplePlayers(unittest.TestCase):
    def test_multiple_custom_song_pools(self) -> None:
        from argparse import Namespace
        from BaseClasses import MultiWorld
        import worlds.AutoWorld as AutoWorld
        from worlds.itgmania import ITGMania
        from worlds.itgmania.items import ALL_CHARTS, CLUB_FANTASTIC_POOLS

        multiworld = MultiWorld(2)
        multiworld.game[1] = "ITGMania"
        multiworld.game[2] = "ITGMania"
        multiworld.player_name = {1: "Player1", 2: "Player2"}

        player1_pool = ["Custom Pack/Song A", "Custom Pack/Song B"]
        player2_pool = ["Custom Pack/Song B", "Custom Pack/Song C"]

        # Ensure these test songs are in ALL_CHARTS so that ID mappings are valid
        from worlds.itgmania.items import ITGManiaChart
        import worlds.itgmania.items as itg_items
        orig_charts = itg_items.ALL_CHARTS
        
        # Merge our test songs with the default ones
        test_song_names = list(set(CLUB_FANTASTIC_POOLS) | set(player1_pool) | set(player2_pool))
        itg_items.ALL_CHARTS = [ITGManiaChart(name) for name in test_song_names]
        
        from worlds.itgmania.world import ITGMania
        import worlds.itgmania.ITGManiaCollection as itg_coll
        itg_coll.ALL_CHARTS = itg_items.ALL_CHARTS
        orig_starting_code = itg_coll.ITGManiaCollections.STARTING_CODE
        orig_item_names_to_id = itg_coll.ITGManiaCollections.item_names_to_id
        orig_location_names_to_id = itg_coll.ITGManiaCollections.location_names_to_id
        
        # Reset starting code and clear locations for fresh mapping in test
        itg_coll.ITGManiaCollections.STARTING_CODE = 57300000
        itg_coll.ITGManiaCollections.song_locations.clear()
        
        # Recreate the collection to use the new ALL_CHARTS
        ITGMania.itgm_collection = itg_coll.ITGManiaCollections()
        
        # Explicitly rebuild class ChainMaps with the new dynamic lists
        itg_coll.ITGManiaCollections.item_names_to_id = itg_coll.ChainMap(
            {c.name: 57300001 + i for i, c in enumerate(itg_items.ALL_CHARTS)},
            itg_coll.ITGManiaCollections.filler_items,
            itg_coll.ITGManiaCollections.mod_items,
            itg_coll.ITGManiaCollections.trap_items,
            itg_coll.ITGManiaCollections.bosskey_items
        )
        itg_coll.ITGManiaCollections.location_names_to_id = itg_coll.ChainMap(
            ITGMania.itgm_collection.song_locations
        )
        
        ITGMania.location_name_to_id = itg_coll.ITGManiaCollections.location_names_to_id
        ITGMania.item_name_to_id = itg_coll.ITGManiaCollections.item_names_to_id

        try:
            player_options = {
                1: {
                    "number_of_charts": 2,
                    "number_of_starting_charts": 1,
                    "custom_song_pool": player1_pool,
                },
                2: {
                    "number_of_charts": 2,
                    "number_of_starting_charts": 1,
                    "custom_song_pool": player2_pool,
                }
            }

            args = Namespace()
            world_type = AutoWorld.AutoWorldRegister.world_types["ITGMania"]
            for name, option in world_type.options_dataclass.type_hints.items():
                opt_dict = {}
                for p in [1, 2]:
                    val = player_options[p].get(name, option.default)
                    opt_dict[p] = option.from_any(val)
                setattr(args, name, opt_dict)
                
            multiworld.set_options(args)
            
            from BaseClasses import CollectionState
            multiworld.state = CollectionState(multiworld)
            
            # Generate early
            multiworld.worlds[1].generate_early()
            multiworld.worlds[2].generate_early()
            
            # Check player 1 selected charts
            player1_charts = multiworld.worlds[1].starting_songs + multiworld.worlds[1].included_songs
            for song in player1_charts:
                self.assertIn(song, player1_pool)
                self.assertNotIn(song, ["Custom Pack/Song C"])
                
            # Check player 2 selected charts
            player2_charts = multiworld.worlds[2].starting_songs + multiworld.worlds[2].included_songs
            for song in player2_charts:
                self.assertIn(song, player2_pool)
                self.assertNotIn(song, ["Custom Pack/Song A"])

            # Check that locations map to consistent IDs
            loc_id_1 = ITGMania.location_name_to_id["Custom Pack/Song B-0"]
            loc_id_2 = ITGMania.location_name_to_id["Custom Pack/Song B-0"]
            self.assertEqual(loc_id_1, loc_id_2)

        finally:
            # Restore original charts and collections
            itg_items.ALL_CHARTS = orig_charts
            itg_coll.ALL_CHARTS = orig_charts
            itg_coll.ITGManiaCollections.STARTING_CODE = orig_starting_code
            itg_coll.ITGManiaCollections.item_names_to_id = orig_item_names_to_id
            itg_coll.ITGManiaCollections.location_names_to_id = orig_location_names_to_id
            itg_coll.ITGManiaCollections.song_locations.clear()
            
            ITGMania.itgm_collection = itg_coll.ITGManiaCollections()
            ITGMania.location_name_to_id = ITGMania.itgm_collection.location_names_to_id
            ITGMania.item_name_to_id = ITGMania.itgm_collection.item_names_to_id


