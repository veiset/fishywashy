local _, ns = ...

-- Values that are meant to be tweaked.
local Config = {}
ns.Config = Config

-- Known fishing lure item IDs, strongest first; each one in your bags gets a button
Config.BAIT_ITEMS = {
    6533,  -- Aquadynamic Fish Attractor
    34861, -- Sharpened Fish Hook
    46006, -- Glow Worm
    62673, -- Feathered Lure
    68049, -- Heat-Treated Spinning Lure
    7307,  -- Flesh Eating Worm
    6532,  -- Bright Baubles
    6811,  -- Aquadynamic Fish Lens
    6530,  -- Nightcrawlers
    6529,  -- Shiny Bauble
}

-- Seconds after casting before the volume is boosted, to skip the sound of the cast itself
Config.BOOST_DELAY = 0.5

-- Clicking the bobber ends the cast just before the loot opens, so wait this many seconds
-- before counting a cast as unsuccessful
Config.LOOT_GRACE = 1

-- A new cast starting within this many seconds of the last one stopping is a recast, which
-- isn't counted as unsuccessful
Config.RECAST_WINDOW = 0.3

-- Seconds between two right-clicks for them to count as a double-click that casts Fishing
Config.DOUBLE_CLICK_TIME = 0.4

-- Number of rows in the History panel
Config.RECENT_CATCHES = 5

-- Number of items listed in the Global stats panel; the rest are in the Details window
Config.GLOBAL_STATS_ROWS = 5
