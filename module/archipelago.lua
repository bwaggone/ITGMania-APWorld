-- Module configuration / shared state
local AP = {}
_G.AP = AP

-- Constants
AP.HOST = "ws://localhost:38281"
AP.SLOT = "ITGManiaPlayer"
AP.PASSWORD = ""
AP.MODULE_TAG = "[AP-Module]"
AP.ENABLE_PENDING_SCORES = true
AP.MAX_PENDING_SCORES = 50
AP.GAME_NAME = "ITGMania"

-- State
AP.apHandler = nil
AP.apHandlerInstance = nil
AP.apHandlerShuttingDown = false
AP.itemNames = {}
AP.locationIds = {}
AP.folderToChartName = {}
AP.seedName = "Unknown"
AP.hasDefaultedToSortOrderPreferred = false
AP.AP_AllReceivedItems = {}
AP.bonusUsage = {}
AP.initialSyncComplete = false
AP.lastConnectedState = nil
AP.slotOptions = {
	score_type = 1,
	passing_score = 0,
	fail_allowed = false,
	deathlink_enabled = false,
	trap_items = {},
	game_mode = 0,
	goal_song = "",
	bosskey_name = "Boss Key",
	bosskeys_required = 0,
}

AP.configState = {
	player_name = "Player",
	game_mode = 0, -- 0 = clear_count, 1 = boss_key
	win_count = 15,
	goal_song = "",
	boss_key_name = 0, -- 0 = Boss Key, 1 = Boss Song Fragment, 2 = McGuffin, etc.
	boss_key_count = 10,
	boss_keys_required = 8,
	fail_allowed = false,
	passing_score = 0,
	score_type = 1, -- 0 = money, 1 = ex, 2 = high_ex
	number_of_charts = 20,
	number_of_starting_charts = 3,
	include_85_score_checks = false,
	include_90_score_checks = false,
	include_96_score_checks = false,
	include_98_score_checks = false,
	include_99_score_checks = false,
	include_quad_score_checks = false,
	include_quint_score_checks = false,
	enable_mod_items = false,
	death_link = false,
	trap_chance = 0,
	trap_items = { "Trap - Reverse Scroll", "Trap - Dark", "Trap - Half Speed", "Trap - Mini" },
	custom_song_pool = {}
}

-- Trap & DeathLink States
AP.armedTrapQueue = {}
AP.deathlinkArmed = false
AP.ignoreNextDeathReport = false
AP.cachedHalfSpeedTarget = {}
AP.currentSongTrap = nil
AP.trapWasAppliedThisSong = false

-- UI state
AP.notificationQueue = {}
AP.isNotificationActive = false
-- Define local logging wrappers that prepend MODULE_TAG to all screen and log outputs
local original_SM = SM
AP.AP_SM = function(msg)
	AP.Trace(msg)
end

local original_Trace = Trace
AP.Trace = function(msg)
	if original_Trace then
		original_Trace(AP.MODULE_TAG .. " " .. tostring(msg))
	else
		print(AP.MODULE_TAG .. " " .. tostring(msg))
	end
end

AP.Trace("Loaded Archipelago client module.")

-- Guarded stub declarations (only for tooling; real objects provided by engine at runtime)
if not PROFILEMAN then PROFILEMAN = { GetProfileDir = function(...) return "" end } end
if not NETWORK then NETWORK = {
	HttpRequest = function(...)
		return {}
	end }
end
if not FILEMAN then FILEMAN = {
	DoesFileExist = function(...)
		return false
	end,
	GetDirListing = function(...)
		return {}
	end,
	Remove = function(...)
		return true
	end }
end
if not RageFileUtil then RageFileUtil = {
	CreateRageFile = function(...)
		return {
			Open = function(...)
				return false
			end,
			Read = function(...)
				return nil
			end,
			Write = function(...)
				return 0
			end,
			Close = function(...)
			end,
			destroy = function(...)
			end
		}
	end
  }
end
if not THEME then THEME = {
	GetCurrentThemeDirectory = function(...)
		return ""
	end
}
end

local function LoadIniConfig()
	local path = THEME:GetCurrentThemeDirectory() .. "Modules/archipelago.ini"
	local file = RageFileUtil.CreateRageFile()
	local content = nil
	if file:Open(path, 1) then -- Mode 1 = Read
		content = file:Read()
		file:Close()
	end
	
	if not content then
		-- File doesn't exist, write default ini settings
		if file:Open(path, 2) then -- Mode 2 = Write
			local defaultContent = [[
[Archipelago]
# The hostname and port of the Archipelago server (e.g. ws://localhost:38281 or ws://archipelago.gg:38281)
Host = ws://localhost:38281

# The slot/player name configured in the multiworld
Slot = ITGManiaPlayer

# The password to connect to the server (if required)
Password = 
]]
			file:Write(defaultContent)
			file:Close()
			AP.Trace("Created default archipelago.ini configuration file.")
		end
		file:destroy()
		return
	end
	
	file:destroy()
	
	local currentSection = ""
	for line in content:gmatch("[^\r\n]+") do
		-- Strip leading and trailing whitespace
		line = line:gsub("^%s+", ""):gsub("%s+$", "")
		
		-- Skip comments and empty lines
		if line ~= "" and not line:match("^#") and not line:match("^;") then
			local section = line:match("^%[(.-)%]$")
			if section then
				currentSection = section:lower()
			else
				local key, val = line:match("^([^=]+)=(.*)$")
				if key and val then
					key = key:gsub("^%s+", ""):gsub("%s+$", ""):lower()
					val = val:gsub("^%s+", ""):gsub("%s+$", "")
					
					-- Remove surrounding quotes if they exist
					if (val:sub(1, 1) == '"' and val:sub(-1) == '"') or (val:sub(1, 1) == "'" and val:sub(-1) == "'") then
						val = val:sub(2, -2)
					end
					
					if currentSection == "archipelago" or currentSection == "" then
						if key == "host" then
							AP.HOST = val
						elseif key == "slot" then
							AP.SLOT = val
						elseif key == "password" then
							AP.PASSWORD = val
						end
					end
				end
			end
		end
	end
	AP.Trace("Loaded connection settings from archipelago.ini (Host: " .. tostring(AP.HOST) .. ", Slot: " .. tostring(AP.SLOT) .. ")")
end

-- Load the connection configuration from INI if present
LoadIniConfig()

-- Getter for apHandlerInstance
AP.GetAPHandlerInstance = function()
	return AP.apHandlerInstance
end

-- Helper to load sub-files
local function loadSubFile(filename)
	local path = THEME:GetCurrentThemeDirectory() .. "Modules/Archipelago/" .. filename
	local chunk, err = loadfile(path)
	if not chunk then
		AP.Trace("Archipelago error loading " .. filename .. ": " .. tostring(err))
		error("Archipelago failed to load sub-file: " .. filename)
	end
	
	-- Run the chunk and pass the shared AP context
	local success, result = pcall(chunk, AP)
	if not success then
		AP.Trace("Archipelago error running " .. filename .. ": " .. tostring(result))
		error("Archipelago failed to execute sub-file: " .. filename)
	end
	return result
end

-- Load Archipelago components in dependency order
loadSubFile("helpers.lua")
loadSubFile("cache.lua")

-- Bootstrap cache offline if last connected seed exists
local lastSeed = AP.LoadLastSeed()
if lastSeed then
	AP.seedName = lastSeed
	AP.LoadCacheFromDisk()
end

loadSubFile("modifiers.lua")
loadSubFile("boosters.lua")
loadSubFile("playlist.lua")
loadSubFile("traps.lua")
loadSubFile("deathlink.lua")
loadSubFile("evaluator.lua")
loadSubFile("network.lua")
loadSubFile("ui.lua")
loadSubFile("config_ui.lua")
loadSubFile("actor_handler.lua")

-- Start the connection handler
AP.CreateAPHandler()
AP.apHandler:InitCommand()
-- Build modules table for Simply Love screen registration
local screens = {
	"ScreenTitleMenu",
	"ScreenSelectMusic",
	"ScreenEvaluationNormal",
	"ScreenEvaluationStage",
	"ScreenEvaluationNonstop",
	"ScreenGameplay",
	"ScreenPlayerOptions",
	"ScreenPlayerOptions2",
	"ScreenPlayerOptions3"
}
local modules = {}
for _, screen in ipairs(screens) do
	modules[screen] = AP.MakeScreenActor(screen)
end

-- Hook CustomOptionRow globally to clamp modifiers immediately when they are saved or loaded
if _G.CustomOptionRow then
	local original_CustomOptionRow = _G.CustomOptionRow
	_G.CustomOptionRow = function(name)
		local row = original_CustomOptionRow(name)
		if row and (name == "BackgroundFilter" or name == "Mini" or name == "SpeedMod") then
			local original_SaveSelections = row.SaveSelections
			row.SaveSelections = function(subself, list, pn)
				original_SaveSelections(subself, list, pn)
				if name == "BackgroundFilter" then
					AP.ClampBackgroundFilter(pn)
				elseif name == "Mini" then
					AP.ClampMini(pn)
				elseif name == "SpeedMod" then
					AP.ClampSpeedMod(pn)
				end
			end
		end
		return row
	end
end

return modules
