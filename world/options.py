from dataclasses import dataclass

from Options import Choice, OptionGroup, PerGameCommonOptions, Range, Toggle, FreeText, OptionList, DeathLink, DeathLinkMixin

# In this file, we define the options the player can pick.
# The most common types of options are Toggle, Range and Choice.

# Options will be in the game's template yaml.
# They will be represented by checkboxes, sliders etc. on the game's options page on the website.
# (Note: Options can also be made invisible from either of these places by overriding Option.visibility.

# For further reading on options, you can also read the Options API Document:
# https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/options%20api.md


# The first type of Option we'll discuss is the Toggle.
# A toggle is an option that can either be on or off. This will be represented by a checkbox on the website.
# The default for a toggle is "off".
# If you want a toggle to be on by default, you can use the "DefaultOnToggle" class instead of the "Toggle" class.

class FailAllowed(Toggle):
    """To allow a fail to still count toward completion. By enabling this, you can "pass" the song in Archipelago if ImmediateContinue is enabled in ITGMania."""
    display_name = "Fail Allowed"

class PassingScore(Range):
    """
    Desired Score to allow for a "passing" grade, acceptable by Archipelago. Set to zero if you want any clear to count.
    """

    display_name = "Passing Score"

    range_start = 0
    range_end = 100
    default = 0


class ScoreType(Choice):
    """Which score would you like to be graded on? Defaults to EX."""
    display_name = "Score Type"
    option_money = 0
    option_ex = 1
    option_high_ex = 2
    default = 1 

class NumberOfCharts(Range):
    """
    Set for the desired number of charts to count toward completion.
    """

    display_name = "Number of Charts"

    range_start = 0
    range_end = 1000
    default = 20

class NumberOfStartingCharts(Range):
    """
    How many charts to start with? The rest will be considered unlockable.
    """

    display_name = "Number of Starting Charts"

    range_start = 0
    range_end = 10
    default = 3

class GroupSize(Range):
    """
    Number of charts in a group. If greater than 1, you must clear all charts in a group
    before any chart in the next group becomes accessible in logic.
    """
    display_name = "Group Size"
    range_start = 1
    range_end = 100
    default = 1


class WinCount(Range):
    """
    The number of song charts passed/cleared required to win the game.
    """
    display_name = "Win Count"
    range_start = 1
    range_end = 1000
    default = 15


class Include85ScoreChecks(Toggle):
    """Include a check for reaching an 85% score on each chart."""
    display_name = "Include 85% Score Checks"

class Include90ScoreChecks(Toggle):
    """Include a check for reaching a 90% score on each chart."""
    display_name = "Include 90% Score Checks"

class Include96ScoreChecks(Toggle):
    """Include a check for reaching a 96% score on each chart."""
    display_name = "Include 96% Score Checks"

class Include98ScoreChecks(Toggle):
    """Include a check for reaching a 98% score on each chart (excluded from progression)."""
    display_name = "Include 98% Score Checks"

class Include99ScoreChecks(Toggle):
    """Include a check for reaching a 99% score on each chart (excluded from progression)."""
    display_name = "Include 99% Score Checks"

class IncludeQuadScoreChecks(Toggle):
    """Include a check for reaching a 100% money score (Quad) on each chart (excluded from progression)."""
    display_name = "Include Quad Score Checks"

class IncludeQuintScoreChecks(Toggle):
    """Include a check for reaching a 100% EX score (Quint) on each chart (excluded from progression)."""
    display_name = "Include Quint Score Checks"

class EnableModItems(Toggle):
    """Enable speed mods and appearance mods as items in the pool."""
    display_name = "Enable Mod Items"

class TrapItems(OptionList):
    """Flavor names for Trap items other players can send you - these have a real effect in-game
    (applied to your NEXT song, not mid-song - see the setup guide for details).
    Must be chosen from this fixed list:
        Trap - Reverse Scroll, Trap - Dark, Trap - Half Speed, Trap - Mini
    Leave empty to disable traps entirely.
    """
    display_name = "Trap Items"
    default = []

class TrapChance(Range):
    """Of your junk item pool, what percent should be Traps instead of plain Filler?
    Has no effect if Trap Items is empty.
    """
    display_name = "Trap Chance"
    range_start = 0
    range_end = 100
    default = 0


class GameMode(Choice):
    """The game mode to play.
    clear_count: Clear a specified number of songs to win the game.
    boss_key: Unlocks and clear a specific Goal Song after collecting a target number of Boss Keys.
    """
    display_name = "Game Mode"
    option_clear_count = 0
    option_boss_key = 1
    default = 0


class GoalSong(FreeText):
    """The exact song title (from your song pool) that is your Goal Song.
    Leave empty to randomly select one from your selected charts.
    """
    display_name = "Goal Song"
    default = ""


class BossKeyCount(Range):
    """Total number of Boss Keys placed in the multiworld item pool."""
    display_name = "Boss Key Count"
    range_start = 1
    range_end = 99
    default = 10


class BossKeysRequired(Range):
    """How many Boss Keys you must collect before the Goal Song unlocks."""
    display_name = "Boss Keys Required"
    range_start = 1
    range_end = 99
    default = 8


class BossKeyName(Choice):
    """Flavor name for the Boss Key item - shown in Archipelago tracker and chat."""
    display_name = "Boss Key Name"
    option_boss_key = 0
    option_boss_song_fragment = 1
    option_mcguffin = 2
    option_dice_fragment = 3
    option_golden_disc = 4
    option_ancient_relic = 5
    option_puzzle_piece = 6
    default = 0


# Maps a BossKeyName Choice's current_key to the real display/item name used everywhere else.
BOSS_KEY_NAME_BY_KEY = {
    "boss_key": "Boss Key",
    "boss_song_fragment": "Boss Song Fragment",
    "mcguffin": "McGuffin",
    "dice_fragment": "Dice Fragment",
    "golden_disc": "Golden Disc",
    "ancient_relic": "Ancient Relic",
    "puzzle_piece": "Puzzle Piece",
}


class CustomSongPool(OptionList):
    """
    A list of custom song names (folder names or relative paths) to include in the randomizer pool.
    If empty, the world will fall back to Club Fantastic 1 & 2.
    """
    display_name = "Custom Song Pool"
    default = []


@dataclass
class ITGManiaOptions(PerGameCommonOptions, DeathLinkMixin):
    game_mode: GameMode
    goal_song: GoalSong
    boss_key_count: BossKeyCount
    boss_keys_required: BossKeysRequired
    boss_key_name: BossKeyName
    fail_allowed: FailAllowed
    passing_score: PassingScore
    score_type: ScoreType
    number_of_charts: NumberOfCharts
    number_of_starting_charts: NumberOfStartingCharts
    group_size: GroupSize
    win_count: WinCount
    include_85_score_checks: Include85ScoreChecks
    include_90_score_checks: Include90ScoreChecks
    include_96_score_checks: Include96ScoreChecks
    include_98_score_checks: Include98ScoreChecks
    include_99_score_checks: Include99ScoreChecks
    include_quad_score_checks: IncludeQuadScoreChecks
    include_quint_score_checks: IncludeQuintScoreChecks
    enable_mod_items: EnableModItems
    trap_items: TrapItems
    trap_chance: TrapChance
    death_link: DeathLink
    custom_song_pool: CustomSongPool


# If we want to group our options by similar type, we can do so as well. This looks nice on the website.
option_groups = [
    OptionGroup(
        "General Settings & Game Mode",
        [GameMode, NumberOfStartingCharts, NumberOfCharts, PassingScore, GroupSize, CustomSongPool],
    ),
    OptionGroup(
        "Clear Count Mode Options",
        [WinCount],
    ),
    OptionGroup(
        "Boss Key Mode Options",
        [GoalSong, BossKeyCount, BossKeysRequired, BossKeyName],
    ),
    OptionGroup(
        "Modifiers",
        [ScoreType, FailAllowed, EnableModItems],
    ),
    OptionGroup(
        "Score/Grade Checks",
        [
            Include85ScoreChecks, Include90ScoreChecks, Include96ScoreChecks,
            Include98ScoreChecks, Include99ScoreChecks, IncludeQuadScoreChecks, IncludeQuintScoreChecks
        ],
    ),
    OptionGroup(
        "Traps & DeathLink",
        [TrapItems, TrapChance, DeathLink],
    ),
]

# Finally, we can define some option presets if we want the player to be able to quickly choose a specific "mode".
option_presets = {
    "default": {
        "fail_allowed": False,
    },
}

