-- config_ui.lua provides the in-game UI overlay for configuring
-- Archipelago settings and exporting the player's YAML configuration.

local AP = ...

local overlay_visible = false
local viewState = "main" -- "main", "traps", "songs", "goal_song"

local selectedIndex = 1
local scrollOffset = 1

local paneWidth = 720
local paneHeight = 440
local RowHeight = 26

-- Cached song library scanned from the engine
local localLibrary = nil
local selectedSongs = {}
local packExpanded = {}
local visibleSongRows = {}

-- Goal song selection filter
local goalSongFilter = ""
local cachedGoalSongs = nil

-- Shift key tracking
local shift_pressed = false

-- Keyboard mappings for inline text entry
local charMap = {
	DeviceButton_space = " ",
	DeviceButton_period = ".",
	DeviceButton_comma = ",",
	DeviceButton_hyphen = "-",
	DeviceButton_underscore = "_",
	["DeviceButton_left bracket"] = "[",
	["DeviceButton_right bracket"] = "]",
	["DeviceButton_backslash"] = "\\",
	["DeviceButton_slash"] = "/",
	["DeviceButton_equal"] = "=",
}

-- Traps state (hardcoded)
local hardcodedTraps = {
	"Trap - Reverse Scroll",
	"Trap - Dark",
	"Trap - Half Speed",
	"Trap - Mini"
}
local selectedTraps = {}

-- Initialize traps selection
for _, trap in ipairs(hardcodedTraps) do
	selectedTraps[trap] = true
end

local settings = {
	{ name = "Player Name", key = "player_name", type = "text" },
	{ name = "Configure Song Pool...", type = "submenu", target = "songs" },
	{ name = "Game Mode", key = "game_mode", type = "choice", choices = { "Clear Count", "Boss Key" } },
	{ name = "Win Count", key = "win_count", type = "range", min = 1, max = 200, visible = function(s) return s.game_mode == 0 end },
	{ name = "Goal Song", key = "goal_song", type = "goal_song", visible = function(s) return s.game_mode == 1 end },
	{ name = "Boss Key Name", key = "boss_key_name", type = "choice", choices = { "Boss Key", "Boss Song Fragment", "McGuffin", "Dice Fragment", "Golden Disc", "Ancient Relic", "Puzzle Piece" }, visible = function(s) return s.game_mode == 1 end },
	{ name = "Boss Key Count", key = "boss_key_count", type = "range", min = 1, max = 99, visible = function(s) return s.game_mode == 1 end },
	{ name = "Boss Keys Required", key = "boss_keys_required", type = "range", min = 1, max = 99, visible = function(s) return s.game_mode == 1 end },
	{ name = "Score Type", key = "score_type", type = "choice", choices = { "Money", "EX", "High EX" } },
	{ name = "Passing Score", key = "passing_score", type = "range", min = 0, max = 100 },
	{ name = "Fail Allowed", key = "fail_allowed", type = "toggle" },
	{ name = "Number of Charts", key = "number_of_charts", type = "range", min = 1, max = 500 },
	{ name = "Number of Starting Charts", key = "number_of_starting_charts", type = "range", min = 0, max = 20 },
	{ name = "Include 85% Checks", key = "include_85_score_checks", type = "toggle" },
	{ name = "Include 90% Checks", key = "include_90_score_checks", type = "toggle" },
	{ name = "Include 96% Checks", key = "include_96_score_checks", type = "toggle" },
	{ name = "Include 98% Checks", key = "include_98_score_checks", type = "toggle" },
	{ name = "Include 99% Checks", key = "include_99_score_checks", type = "toggle" },
	{ name = "Include Quad Checks", key = "include_quad_score_checks", type = "toggle" },
	{ name = "Include Quint Checks", key = "include_quint_score_checks", type = "toggle" },
	{ name = "Enable Mod Items", key = "enable_mod_items", type = "toggle" },
	{ name = "Enable DeathLink", key = "death_link", type = "toggle" },
	{ name = "Trap Chance", key = "trap_chance", type = "range", min = 0, max = 100 },
	{ name = "Configure Traps...", type = "submenu", target = "traps" },
	{ name = "--- GENERATE YAML ---", type = "action", action = "generate" }
}

local function getVisibleSettings()
	local vis = {}
	for _, s in ipairs(settings) do
		if s.visible == nil or s.visible(AP.configState) then
			table.insert(vis, s)
		end
	end
	return vis
end

-- Rebuild the flat navigation list of visible items when in songs view (expandable tree)
local function rebuildSongRows()
	visibleSongRows = {}
	if not localLibrary then return end
	
	for gIdx, group in ipairs(localLibrary) do
		-- Count selected songs
		local selectedCount = 0
		for _, song in ipairs(group.songs) do
			if selectedSongs[song.relativePath] then
				selectedCount = selectedCount + 1
			end
		end
		
		table.insert(visibleSongRows, {
			type = "pack",
			groupIndex = gIdx,
			name = group.groupName,
			count = selectedCount,
			total = #group.songs,
			expanded = packExpanded[gIdx] == true
		})
		
		if packExpanded[gIdx] then
			for sIdx, song in ipairs(group.songs) do
				table.insert(visibleSongRows, {
					type = "song",
					groupIndex = gIdx,
					songIndex = sIdx,
					name = song.name,
					relativePath = song.relativePath,
					selected = selectedSongs[song.relativePath] == true
				})
			end
		end
	end
end

-- Get filtered list of candidate goal songs (selected in the custom song pool)
local function getGoalSongsList()
	if cachedGoalSongs then return cachedGoalSongs end

	local list = {}
	local source = AP.configState.custom_song_pool
	if not source or #source == 0 then
		if localLibrary then
			source = {}
			for _, group in ipairs(localLibrary) do
				for _, song in ipairs(group.songs) do
					table.insert(source, song.relativePath)
				end
			end
		end
	end

	for _, path in ipairs(source or {}) do
		local display = AP.FormatNotificationName(path)
		if goalSongFilter == "" or display:lower():find(goalSongFilter:lower(), 1, true) then
			table.insert(list, path)
		end
	end
	table.sort(list)
	cachedGoalSongs = list
	return list
end

AP.MakeConfigOverlayActor = function()
	local main_actor = nil
	
	local function updateUI(self)
		local container = self:GetChild("Container")
		local backdrop = self:GetChild("Backdrop")
		
		backdrop:visible(overlay_visible)
		container:visible(overlay_visible)
		
		if not overlay_visible then return end
		
		-- Clamp selectedIndex and scrollOffset to valid range if list size changed dynamically
		local itemsCount = 0
		if viewState == "main" then
			itemsCount = #getVisibleSettings()
		elseif viewState == "traps" then
			itemsCount = #hardcodedTraps
		elseif viewState == "songs" then
			itemsCount = #visibleSongRows
		elseif viewState == "goal_song" then
			itemsCount = #getGoalSongsList() + 2
		end

		if selectedIndex > itemsCount then
			selectedIndex = itemsCount
			if selectedIndex < 1 then selectedIndex = 1 end
		end
		if scrollOffset > itemsCount - 11 then
			scrollOffset = itemsCount - 11
			if scrollOffset < 1 then scrollOffset = 1 end
		end
		
		local title = container:GetChild("Title")
		local list_af = container:GetChild("List")
		local footer = container:GetChild("Footer")
		
		-- Render Title and Footer based on View State
		if viewState == "main" then
			title:settext("ARCHIPELAGO CONFIGURATION")
			footer:settext("Use &MENUUP;/&MENUDOWN; to navigate. &MENULEFT;/&MENURIGHT; or &START; to edit. &SELECT; to exit.")
			
			local visSettings = getVisibleSettings()
			for i = 1, 12 do
				local row = list_af:GetChild("Row" .. i)
				local idx = scrollOffset + i - 1
				if idx <= #visSettings then
					local setting = visSettings[idx]
					local val = AP.configState[setting.key]
					
					row:GetChild("Name"):settext(setting.name)
					
					local valText = ""
					if setting.type == "toggle" then
						valText = val and "ENABLED" or "disabled"
					elseif setting.type == "choice" then
						valText = setting.choices[val + 1] or tostring(val)
					elseif setting.type == "range" or setting.type == "text" then
						local cursor = ""
						if idx == selectedIndex then
							cursor = (GetTimeSinceStart() % 0.8 < 0.4) and "|" or " "
						end
						valText = tostring(val ~= nil and val or "") .. cursor
					elseif setting.type == "goal_song" then
						valText = (val and val ~= "") and AP.FormatNotificationName(val) or "(Random / Blank)"
					elseif setting.type == "submenu" or setting.type == "action" then
						valText = ""
					end
					row:GetChild("Value"):settext(valText)
					
					-- Highlight
					if idx == selectedIndex then
						row:GetChild("Highlight"):visible(true)
						row:GetChild("Name"):diffuse(0.3, 0.9, 0.9, 1)
						row:GetChild("Value"):diffuse(0.3, 0.9, 0.9, 1)
					else
						row:GetChild("Highlight"):visible(false)
						row:GetChild("Name"):diffuse(1, 1, 1, 1)
						row:GetChild("Value"):diffuse(0.7, 0.7, 0.7, 1)
					end
					
					row:visible(true)
				else
					row:visible(false)
				end
			end
			
		elseif viewState == "traps" then
			title:settext("SELECT TRAP ITEMS")
			footer:settext("Use &MENUUP;/&MENUDOWN; to scroll. &START; to toggle. &SELECT; to return.")
			
			for i = 1, 12 do
				local row = list_af:GetChild("Row" .. i)
				if i <= #hardcodedTraps then
					local trap = hardcodedTraps[i]
					local checked = selectedTraps[trap] == true
					
					row:GetChild("Name"):settext((checked and "[x] " or "[ ] ") .. trap)
					row:GetChild("Value"):settext("")
					
					if i == selectedIndex then
						row:GetChild("Highlight"):visible(true)
						row:GetChild("Name"):diffuse(0.3, 0.9, 0.9, 1)
					else
						row:GetChild("Highlight"):visible(false)
						row:GetChild("Name"):diffuse(1, 1, 1, 1)
					end
					row:visible(true)
				else
					row:visible(false)
				end
			end
			
		elseif viewState == "songs" then
			title:settext("SELECT SONG POOL")
			footer:settext("Use &MENUUP;/&MENUDOWN; to scroll. Start to toggle. &MENULEFT;/&MENURIGHT; to collapse/expand. &SELECT; to return.")
			
			for i = 1, 12 do
				local row = list_af:GetChild("Row" .. i)
				local idx = scrollOffset + i - 1
				if idx <= #visibleSongRows then
					local item = visibleSongRows[idx]
					
					local prefix = ""
					local valText = ""
					
					if item.type == "pack" then
						prefix = (item.expanded and "[-] " or "[+] ") .. item.name
						valText = string.format("(%d/%d songs)", item.count, item.total)
						row:GetChild("Name"):diffuse(1, 1, 1, 1)
						row:GetChild("Value"):diffuse(0.6, 0.6, 0.6, 1)
					else
						prefix = "   " .. (item.selected and "[x] " or "[ ] ") .. item.name
						valText = ""
						row:GetChild("Name"):diffuse(0.8, 0.8, 0.8, 1)
					end
					
					row:GetChild("Name"):settext(prefix)
					row:GetChild("Value"):settext(valText)
					
					if idx == selectedIndex then
						row:GetChild("Highlight"):visible(true)
						row:GetChild("Name"):diffuse(0.3, 0.9, 0.9, 1)
						row:GetChild("Value"):diffuse(0.3, 0.9, 0.9, 1)
					else
						row:GetChild("Highlight"):visible(false)
					end
					row:visible(true)
				else
					row:visible(false)
				end
			end
			
		elseif viewState == "goal_song" then
			title:settext("SELECT GOAL SONG")
			footer:settext("Use &MENUUP;/&MENUDOWN; to scroll. &START; to select. &SELECT; to return.")
			
			local goalSongs = getGoalSongsList()
			local num_items = #goalSongs + 2
			
			for i = 1, 12 do
				local row = list_af:GetChild("Row" .. i)
				local idx = scrollOffset + i - 1
				
				if idx <= num_items then
					local displayName = ""
					if idx == 1 then
						local cursor = ""
						if idx == selectedIndex then
							cursor = (GetTimeSinceStart() % 0.8 < 0.4) and "|" or " "
						end
						displayName = "[ Search/Filter: " .. (goalSongFilter ~= "" and goalSongFilter or "") .. cursor .. " ]"
					elseif idx == 2 then
						displayName = "[ Random / Blank ]"
					else
						local path = goalSongs[idx - 2]
						local displayNameStr = path
						if path:find("/") then
							local parts = {}
							for part in path:gmatch("[^/]+") do
								table.insert(parts, part)
							end
							if #parts >= 2 then
								displayNameStr = parts[1] .. " / " .. parts[2]
							end
						end
						displayName = displayNameStr
					end
					
					row:GetChild("Name"):settext(displayName)
					row:GetChild("Value"):settext("")
					
					if idx == selectedIndex then
						row:GetChild("Highlight"):visible(true)
						row:GetChild("Name"):diffuse(0.3, 0.9, 0.9, 1)
					else
						row:GetChild("Highlight"):visible(false)
						row:GetChild("Name"):diffuse(1, 1, 1, 1)
					end
					row:visible(true)
				else
					row:visible(false)
				end
			end
		end
	end
	
	local function promptTextEntry(question, initial, callback)
		local settings = {
			Question = question,
			InitialAnswer = tostring(initial),
			MaxInputLength = 64,
			OnOK = function(answer)
				if answer then
					callback(answer)
				end
			end
		}
		SCREENMAN:AddNewScreenToTop("ScreenTextEntry")
		SCREENMAN:GetTopScreen():Load(settings)
	end
	
	local function clampRangeSetting(setting)
		if setting then
			if setting.type == "range" then
				local val = AP.configState[setting.key] or 0
				if setting.min and val < setting.min then
					AP.configState[setting.key] = setting.min
				elseif setting.max and val > setting.max then
					AP.configState[setting.key] = setting.max
				end
			elseif setting.key == "player_name" then
				local name = AP.configState.player_name or ""
				if #name > 16 then
					AP.configState.player_name = name:sub(1, 16)
				end
			end
		end
	end

	local function adjustRange(setting, delta)
		local val = AP.configState[setting.key] or 0
		val = val + delta
		if setting.min and val < setting.min then val = setting.min end
		if setting.max and val > setting.max then val = setting.max end
		AP.configState[setting.key] = val
	end
	
	local function generateYAML()
		for _, s in ipairs(settings) do
			clampRangeSetting(s)
		end

		local traps = {}
		for _, trap in ipairs(hardcodedTraps) do
			if selectedTraps[trap] then
				table.insert(traps, trap)
			end
		end
		AP.configState.trap_items = traps
		
		local pool = {}
		for path, checked in pairs(selectedSongs) do
			if checked then
				table.insert(pool, path)
			end
		end
		table.sort(pool)
		AP.configState.custom_song_pool = pool
		
		local content = AP.FormatYAML(AP.configState)
		local sanitized_name = AP.configState.player_name:gsub("[%s%c\\/:%*%?\"<>|]", "_")
		local filename = sanitized_name .. ".yaml"
		
		local yaml_dir = THEME:GetCurrentThemeDirectory() .. "Modules/Archipelago/YAMLS/"
		local yaml_path = yaml_dir .. filename
		
		local file = RageFileUtil.CreateRageFile()
		if file:Open(yaml_path, 2) then
			file:Write(content)
			file:Close()
			
			SCREENMAN:SystemMessage("YAML generated under Themes/Simply Love/Modules/Archipelago/YAMLS/!")
			SOUND:PlayOnce(THEME:GetPathS("", "_unlock.ogg"))
			
			overlay_visible = false
			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, false)
			end
		else
			SCREENMAN:SystemMessage("Failed to write YAML configuration file.")
		end
		file:destroy()
	end
	
	local function input(event)
		if not overlay_visible then return false end
		if not event then return false end
		
		local key = event.DeviceInput and event.DeviceInput.button
		local game_btn = event.GameButton

		-- Handle Shift key releases/presses
		local isShift = (key == "DeviceButton_left shift" or key == "DeviceButton_right shift")
		if isShift then
			if event.type == "InputEventType_FirstPress" then
				shift_pressed = true
			elseif event.type == "InputEventType_Release" then
				shift_pressed = false
			end
			return true
		end

		-- Ignore key release events for all other keys (but consume them)
		if event.type == "InputEventType_Release" then
			return true
		end

		-- Detect if we are hovering an editable text or numeric range field
		local active_field = nil
		local active_setting = nil
		if viewState == "main" then
			local visSettings = getVisibleSettings()
			local setting = visSettings[selectedIndex]
			if setting then
				if setting.key == "player_name" then
					active_field = "player_name"
					active_setting = setting
				elseif setting.type == "range" then
					active_field = "range"
					active_setting = setting
				end
			end
		elseif viewState == "goal_song" and selectedIndex == 1 then
			active_field = "goal_song_filter"
		end

		-- If an editable field is hovered, intercept typing and backspace
		if active_field then
			if key == "DeviceButton_backspace" then
				if event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat" then
					if active_field == "player_name" then
						local name = AP.configState.player_name or ""
						if #name > 0 then
							AP.configState.player_name = name:sub(1, -2)
						end
					elseif active_field == "range" then
						local str = tostring(AP.configState[active_setting.key] or 0)
						if #str > 1 then
							AP.configState[active_setting.key] = tonumber(str:sub(1, -2)) or 0
						else
							AP.configState[active_setting.key] = 0
						end
					elseif active_field == "goal_song_filter" then
						if #goalSongFilter > 0 then
							goalSongFilter = goalSongFilter:sub(1, -2)
							cachedGoalSongs = nil
						end
					end
					SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
				end
				return true
			end

			local char = nil
			if key and key:find("^DeviceButton_([a-z])$") then
				char = key:match("^DeviceButton_([a-z])$")
				if shift_pressed then
					char = char:upper()
				end
			elseif key and key:find("^DeviceButton_(%d)$") then
				char = key:match("^DeviceButton_(%d)$")
				if shift_pressed then
					local shift_nums = { ["1"]="!", ["2"]="@", ["3"]="#", ["4"]="$", ["5"]="%", ["6"]="^", ["7"]="&", ["8"]='*', ["9"]="(", ["0"]=")" }
					char = shift_nums[char] or char
				end
			elseif key and key:find("^DeviceButton_KP (%d)$") then
				char = key:match("^DeviceButton_KP (%d)$")
			elseif charMap[key] then
				char = charMap[key]
				if shift_pressed and key == "DeviceButton_hyphen" then
					char = "_"
				end
			end

			if char then
				if event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat" then
					if active_field == "player_name" then
						local name = AP.configState.player_name or ""
						if #name < 16 then
							AP.configState.player_name = name .. char
						end
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					elseif active_field == "range" then
						if char:match("^%d$") then
							local current = tostring(AP.configState[active_setting.key] or 0)
							local new_str
							if current == "0" then
								new_str = char
							else
								new_str = current .. char
							end
							local num = tonumber(new_str) or 0
							if active_setting.max and num > active_setting.max then
								num = active_setting.max
							end
							AP.configState[active_setting.key] = num
							SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
						end
					elseif active_field == "goal_song_filter" then
						if #goalSongFilter < 32 then
							goalSongFilter = goalSongFilter .. char
							cachedGoalSongs = nil
						end
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					end
				end
				return true
			end
		end

		-- Standard menu escape / back actions
		if key == "DeviceButton_escape" or game_btn == "Back" then
			if viewState == "main" then
				overlay_visible = false
				SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
				for player in ivalues(PlayerNumber) do
					SCREENMAN:set_input_redirected(player, false)
				end
			else
				viewState = "main"
				selectedIndex = 1
				scrollOffset = 1
				SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			end
			return true
		end
		
		if not (event.PlayerNumber and event.button) then
			return false
		end
		
		local itemsCount = 0
		if viewState == "main" then
			itemsCount = #getVisibleSettings()
		elseif viewState == "traps" then
			itemsCount = #hardcodedTraps
		elseif viewState == "songs" then
			itemsCount = #visibleSongRows
		elseif viewState == "goal_song" then
			itemsCount = #getGoalSongsList() + 2
		end
		
		if game_btn == "MenuDown" or key == "DeviceButton_down" then
			if selectedIndex < itemsCount then
				if viewState == "main" then
					local visSettings = getVisibleSettings()
					clampRangeSetting(visSettings[selectedIndex])
				end
				selectedIndex = selectedIndex + 1
				if selectedIndex > scrollOffset + 11 then
					scrollOffset = selectedIndex - 11
				end
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
			end
			return true
		elseif game_btn == "MenuUp" or key == "DeviceButton_up" then
			if selectedIndex > 1 then
				if viewState == "main" then
					local visSettings = getVisibleSettings()
					clampRangeSetting(visSettings[selectedIndex])
				end
				selectedIndex = selectedIndex - 1
				if selectedIndex < scrollOffset then
					scrollOffset = selectedIndex
				end
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
			end
			return true
		end
		
		if viewState == "main" then
			local visSettings = getVisibleSettings()
			local setting = visSettings[selectedIndex]
			
			if setting then
				if game_btn == "MenuLeft" or key == "DeviceButton_left" then
					if setting.type == "choice" then
						local val = AP.configState[setting.key] or 0
						val = (val - 1) % #setting.choices
						AP.configState[setting.key] = val
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					elseif setting.type == "range" then
						adjustRange(setting, -1)
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					elseif setting.type == "toggle" then
						AP.configState[setting.key] = not AP.configState[setting.key]
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					end
					return true
					
				elseif game_btn == "MenuRight" or key == "DeviceButton_right" then
					if setting.type == "choice" then
						local val = AP.configState[setting.key] or 0
						val = (val + 1) % #setting.choices
						AP.configState[setting.key] = val
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					elseif setting.type == "range" then
						adjustRange(setting, 1)
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					elseif setting.type == "toggle" then
						AP.configState[setting.key] = not AP.configState[setting.key]
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					end
					return true
					
				elseif game_btn == "Start" or game_btn == "Select" then
					if setting.type == "toggle" then
						AP.configState[setting.key] = not AP.configState[setting.key]
						SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
					elseif setting.type == "choice" then
						local val = AP.configState[setting.key] or 0
						val = (val + 1) % #setting.choices
						AP.configState[setting.key] = val
						SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
					elseif setting.type == "text" or setting.type == "range" then
						-- Text / range is entered in-line when hovered; Start behaves as a confirm/feedback sound
						clampRangeSetting(setting)
						SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
					elseif setting.type == "submenu" then
						viewState = setting.target
						selectedIndex = 1
						scrollOffset = 1
						if viewState == "songs" then
							if not localLibrary then
								SCREENMAN:SystemMessage("Scanning local ITGMania songs...")
								localLibrary = AP.ScanLocalLibrary()
								for _, path in ipairs(AP.configState.custom_song_pool or {}) do
									selectedSongs[path] = true
								end
							end
							rebuildSongRows()
						end
						SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
					elseif setting.type == "goal_song" then
						viewState = "goal_song"
						selectedIndex = 1
						scrollOffset = 1
						goalSongFilter = ""
						if not localLibrary then
							SCREENMAN:SystemMessage("Scanning local ITGMania songs...")
							localLibrary = AP.ScanLocalLibrary()
							for _, path in ipairs(AP.configState.custom_song_pool or {}) do
								selectedSongs[path] = true
							end
						end
						-- Sync custom song pool from active checkbox state
						local pool = {}
						for path, checked in pairs(selectedSongs) do
							if checked then
								table.insert(pool, path)
							end
						end
						table.sort(pool)
						AP.configState.custom_song_pool = pool
						cachedGoalSongs = nil
						SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
					elseif setting.type == "action" and setting.action == "generate" then
						generateYAML()
					end
					return true
				end
			end
			
		elseif viewState == "traps" then
			if game_btn == "Start" or game_btn == "Select" then
				local trap = hardcodedTraps[selectedIndex]
				if trap then
					selectedTraps[trap] = not selectedTraps[trap]
					SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
				end
				return true
			end
			
		elseif viewState == "songs" then
			local item = visibleSongRows[selectedIndex]
			if item then
				if game_btn == "Start" then
					if item.type == "pack" then
						local group = localLibrary[item.groupIndex]
						local all_checked = true
						for _, song in ipairs(group.songs) do
							if not selectedSongs[song.relativePath] then
								all_checked = false
								break
							end
						end
						
						local target = not all_checked
						for _, song in ipairs(group.songs) do
							selectedSongs[song.relativePath] = target
						end
					else
						selectedSongs[item.relativePath] = not selectedSongs[item.relativePath]
					end
					rebuildSongRows()
					SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
					return true
				end
				
				if game_btn == "MenuRight" or key == "DeviceButton_right" or game_btn == "Select" then
					if item.type == "pack" and not packExpanded[item.groupIndex] then
						packExpanded[item.groupIndex] = true
						rebuildSongRows()
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					end
					return true
				elseif game_btn == "MenuLeft" or key == "DeviceButton_left" then
					if item.type == "pack" and packExpanded[item.groupIndex] then
						packExpanded[item.groupIndex] = false
						rebuildSongRows()
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					elseif item.type == "song" then
						packExpanded[item.groupIndex] = false
						rebuildSongRows()
						for idx, r in ipairs(visibleSongRows) do
							if r.type == "pack" and r.groupIndex == item.groupIndex then
								selectedIndex = idx
								if selectedIndex < scrollOffset then scrollOffset = selectedIndex end
								break
							end
						end
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					end
					return true
				end
			end
			
		elseif viewState == "goal_song" then
			if game_btn == "Start" or game_btn == "Select" then
				local goalSongs = getGoalSongsList()
				if selectedIndex == 1 then
					-- Filter is typed in-line when hovered; Start can clear the filter
					goalSongFilter = ""
					cachedGoalSongs = nil
					SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
				elseif selectedIndex == 2 then
					AP.configState.goal_song = ""
					viewState = "main"
					selectedIndex = 1
					scrollOffset = 1
					SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
				else
					local songPath = goalSongs[selectedIndex - 2]
					if songPath then
						AP.configState.goal_song = songPath
						viewState = "main"
						selectedIndex = 1
						scrollOffset = 1
						SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
					end
				end
				return true
			end
		end
		
		return true
	end
	
	local function toggleOverlay(self)
		overlay_visible = not overlay_visible
		selectedIndex = 1
		scrollOffset = 1
		viewState = "main"
		
		local screen = SCREENMAN:GetTopScreen()
		if overlay_visible then
			SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, true)
			end
		else
			SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, false)
			end
		end
	end
	
	local list_children = {}
	for i = 1, 12 do
		list_children[#list_children+1] = Def.ActorFrame {
			Name = "Row" .. i,
			InitCommand = function(self)
				self:y(-150 + (i - 1) * RowHeight)
			end,
			
			Def.Quad {
				Name = "Highlight",
				InitCommand = function(self)
					self:zoomto(paneWidth - 20, RowHeight):diffuse(0.18, 0.18, 0.18, 0.75):visible(false)
				end
			},
			
			LoadFont("Common Normal") .. {
				Name = "Name",
				Text = "",
				InitCommand = function(self)
					self:x(-paneWidth/2 + 20):halign(0):zoom(0.6):maxwidth(420)
				end
			},
			
			LoadFont("Common Normal") .. {
				Name = "Value",
				Text = "",
				InitCommand = function(self)
					self:x(paneWidth/2 - 20):halign(1):zoom(0.6):maxwidth(250)
				end
			}
		}
	end
	
	local af = Def.ActorFrame {
		Name = "APConfigOverlayMain",
		InitCommand = function(self)
			main_actor = self
			overlay_visible = false
			selectedIndex = 1
			scrollOffset = 1
			viewState = "main"
			self:SetUpdateFunction(function(self)
				updateUI(self)
			end)
		end,
		ModuleCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:RemoveInputCallback(input)
				screen:AddInputCallback(input)
			end
		end,
		OffCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:RemoveInputCallback(input)
			end
			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, false)
			end
			overlay_visible = false
		end,
		
		ToggleOverlayCommand = function(self)
			toggleOverlay(self)
		end,
		
		APToggleConfigOverlayMessageCommand = function(self)
			self:sleep(0.05):queuecommand("ToggleOverlay")
		end,
		
		Def.Quad {
			Name = "Backdrop",
			InitCommand = function(self)
				self:FullScreen():diffuse(0, 0, 0, 0.85):visible(false)
			end
		},
		
		Def.ActorFrame {
			Name = "Container",
			InitCommand = function(self)
				self:xy(_screen.cx, _screen.cy):visible(false)
			end,
			
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(paneWidth + 4, paneHeight + 4):diffuse(Color.White)
				end
			},
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(paneWidth, paneHeight):diffuse(Color.Black)
				end
			},
			
			Def.Quad {
				InitCommand = function(self)
					self:y(-paneHeight/2 + 25):zoomto(paneWidth, 50):diffuse(0.12, 0.12, 0.12, 1)
				end
			},
			LoadFont("Common Bold") .. {
				Name = "Title",
				Text = "ARCHIPELAGO CONFIGURATION",
				InitCommand = function(self)
					self:y(-paneHeight/2 + 22):zoom(0.72):diffuse(0.3, 0.9, 0.9, 1)
				end
			},
			
			Def.ActorFrame {
				Name = "List",
				children = list_children
			},
			
			Def.Quad {
				InitCommand = function(self)
					self:y(paneHeight/2 - 20):zoomto(paneWidth, 40):diffuse(0.10, 0.10, 0.10, 1)
				end
			},
			LoadFont("Common Normal") .. {
				Name = "Footer",
				Text = "",
				InitCommand = function(self)
					self:y(paneHeight/2 - 20):zoom(0.52):diffuse(0.75, 0.75, 0.75, 1)
				end
			}
		}
	}
	
	return af
end
