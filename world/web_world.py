from BaseClasses import Tutorial
from worlds.AutoWorld import WebWorld

from .options import option_groups, option_presets


# For our game to display correctly on the website, we need to define a WebWorld subclass.
class ITGManiaWebWorld(WebWorld):
    game = "ITGMania"
    theme = "partyTime"

    # A WebWorld can have any number of tutorials, but should always have at least an English setup guide.
    # Many WebWorlds just have one setup guide, but some have multiple, e.g. for different languages.
    # We need to create a Tutorial object for every setup guide.
    # In order, we need to provide a title, a description, a language, a filepath, a link, and authors.
    # The filepath is relative to a "/docs/" directory in the root folder of your apworld.
    # The "link" parameter is unused, but we still need to provide it.
    setup_en = Tutorial(
        "Multiworld Setup Guide",
        "A guide to setting up ITGMania for MultiWorld.",
        "English",
        "setup_en.md",
        "setup/en",
        ["bwags", "HeeroJay"],
    )

    tutorials = [setup_en]

    option_groups = option_groups
    options_presets = option_presets
