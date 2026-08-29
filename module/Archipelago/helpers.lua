-- helpers.lua provides utility functions for the Archipelago module including
-- * player name retrieval
-- * item and location name resolution
-- * JSON parsing for print messages
-- * YAML formatting for configuration
-- * song library scanning

local AP = ...

AP.playerNames = {}
AP.slotInfo = {}
AP.datapackage = {}

AP.GetPlayerName = function(slot)
	if not slot then return "Unknown Player" end
	return AP.playerNames[slot] or ("Player " .. slot)
end

AP.GetGameForSlot = function(slot)
	if not slot then return nil end
	local info = AP.slotInfo[slot]
	return info and info.game
end

AP.GetItemName = function(itemId, slot)
	local game = AP.GetGameForSlot(slot)
	if game and AP.datapackage and AP.datapackage[game] and AP.datapackage[game].itemNames then
		local name = AP.datapackage[game].itemNames[tostring(itemId)]
		if name then return name end
	end
	
	-- Fallback to local itemNames if slot is own slot or game is ITGMania
	if slot == AP.SLOT or (game == AP.GAME_NAME) then
		local name = AP.itemNames[itemId] or AP.itemNames[tostring(itemId)]
		if name then return name end
	end
	
	return "Unknown Item (ID " .. tostring(itemId) .. ")"
end

AP.GetLocationName = function(locationId, slot)
	local game = AP.GetGameForSlot(slot)
	if game and AP.datapackage and AP.datapackage[game] and AP.datapackage[game].locationNames then
		local name = AP.datapackage[game].locationNames[tostring(locationId)]
		if name then return name end
	end
	
	return "Unknown Location (ID " .. tostring(locationId) .. ")"
end

AP.ParsePrintJSON = function(parts)
	if not parts then return "" end
	local message = ""
	for _, part in ipairs(parts) do
		local part_type = part.type
		local part_text = part.text or ""
		
		if part_type == "player_id" then
			local slot = tonumber(part_text) or part_text
			message = message .. AP.GetPlayerName(slot)
		elseif part_type == "item_id" then
			local itemId = tonumber(part_text) or part_text
			local slot = part.player
			message = message .. AP.GetItemName(itemId, slot)
		elseif part_type == "location_id" then
			local locationId = tonumber(part_text) or part_text
			local slot = part.player
			message = message .. AP.GetLocationName(locationId, slot)
		else
			-- Fallback for player_name, item_name, location_name, entrance_name, text, etc.
			message = message .. part_text
		end
	end
	return message
end


AP.FormatNotificationName = function(name)
	if not name then return "Unknown" end
	if name:find("/") then
		local parts = {}
		for part in name:gmatch("[^/]+") do
			table.insert(parts, part)
		end
		if #parts >= 2 then
			return parts[2]
		elseif #parts == 1 then
			return parts[1]
		end
	end
	return name
end

AP.CreateRequest = function(event, data)
	return JsonEncode({
		event=event,
		data=data
	})
end

-- Helper function to get all unlocked songs / charts from received items.
-- Unlocked songs are defined as received items containing a "/" character in their name.
AP.GetUnlockedSongs = function()
	local songs = {}
	local seen = {}
	if AP.AP_AllReceivedItems then
		for _, item in ipairs(AP.AP_AllReceivedItems) do
			local name = AP.itemNames[item.item]
			if name and name:find("/") and not seen[name] then
				seen[name] = true
				table.insert(songs, name)
			end
		end
	end
	-- Sort alphabetically for better navigation
	table.sort(songs)
	return songs
end

AP.GetChecksForSong = function(chart_name)
	local total = 0
	local completed = 0
	if AP.locationIds then
		for name, id in pairs(AP.locationIds) do
			if name:sub(1, #chart_name + 1) == chart_name .. "-" then
				-- If activeLocationIds is populated, only count active locations.
				-- Otherwise, fall back to counting all defined locations.
				if not AP.activeLocationIds or AP.activeLocationIds[id] then
					total = total + 1
					if AP.checkedLocations and AP.checkedLocations[id] then
						completed = completed + 1
					end
				end
			end
		end
	end
	return completed, total
end

AP.GetReceivedItemCount = function(itemName)
	local count = 0
	if AP.AP_AllReceivedItems then
		for _, item in ipairs(AP.AP_AllReceivedItems) do
			local name = AP.itemNames[item.item]
			if name == itemName then
				count = count + 1
			end
		end
	end
	return count
end

AP.IsSongLocked = function(song)
	if not song then return false end
	local songDir = song:GetSongDir()
	local parts = {}
	for part in songDir:gmatch("[^/]+") do
		table.insert(parts, part)
	end
	local folderName = parts[#parts]
	if not folderName then return false end

	local chart_name = AP.folderToChartName[folderName]
	if not chart_name then
		return false -- Not part of the AP seed, not locked
	end

	-- If it's Boss Key mode and this is the Goal Song, check boss key count
	if AP.slotOptions.game_mode == 1 and chart_name == AP.slotOptions.goal_song then
		local collected = AP.GetReceivedItemCount(AP.slotOptions.bosskey_name)
		local required = AP.slotOptions.bosskeys_required or 0
		return collected < required
	end

	-- For normal AP songs, verify if they have been received as an item
	local unlockedSongs = AP.GetUnlockedSongs()
	for _, unlockedChart in ipairs(unlockedSongs) do
		local uParts = {}
		for part in unlockedChart:gmatch("[^/]+") do
			table.insert(uParts, part)
		end
		local uFolder = nil
		if #uParts >= 2 then
			uFolder = uParts[2]
		elseif #uParts == 1 then
			uFolder = uParts[1]
		end
		if uFolder == folderName then
			return false -- Found in received items, so it is unlocked
		end
	end

	return true -- Not found in received items, so it is locked
end

-- Scan all installed song packs and their songs
AP.ScanLocalLibrary = function()
	local library = {}
	local groupNames = SONGMAN:GetSongGroupNames()
	for _, group in ipairs(groupNames) do
		local songs = SONGMAN:GetSongsInGroup(group)
		local songList = {}
		for _, song in ipairs(songs) do
			local songDir = song:GetSongDir()
			local parts = {}
			for part in songDir:gmatch("[^/]+") do
				table.insert(parts, part)
			end
			local folderName = parts[#parts]
			if folderName then
				local relativePath = folderName
				if #parts >= 3 then
					relativePath = parts[#parts-1] .. "/" .. parts[#parts]
				end
				table.insert(songList, {
					name = song:GetDisplayMainTitle(),
					folder = folderName,
					dir = songDir,
					relativePath = relativePath
				})
			end
		end
		if #songList > 0 then
			table.sort(songList, function(a, b) return a.name < b.name end)
			table.insert(library, {
				groupName = group,
				songs = songList
			})
		end
	end
	table.sort(library, function(a, b) return a.groupName < b.groupName end)
	return library
end

local function yaml_quote(value)
	value = tostring(value)
	return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

AP.FormatYAML = function(state)
	local lines = {}
	table.insert(lines, "# Generated by ITGMania Archipelago Config Tool")
	table.insert(lines, "name: " .. yaml_quote(state.player_name))
	table.insert(lines, "description: " .. yaml_quote("ITGMania options for " .. state.player_name))
	table.insert(lines, "game: " .. yaml_quote("ITGMania"))
	table.insert(lines, "")
	table.insert(lines, "ITGMania:")
	
	-- Mode options
	table.insert(lines, "  game_mode: " .. (state.game_mode == 1 and "boss_key" or "clear_count"))
	if state.game_mode == 0 then
		table.insert(lines, "  win_count: " .. tostring(state.win_count))
	else
		local bossKeyNameKeys = {
			[0] = "boss_key",
			[1] = "boss_song_fragment",
			[2] = "mcguffin",
			[3] = "dice_fragment",
			[4] = "golden_disc",
			[5] = "ancient_relic",
			[6] = "puzzle_piece"
		}
		local bNameKey = bossKeyNameKeys[state.boss_key_name] or "boss_key"
		table.insert(lines, "  goal_song: " .. yaml_quote(state.goal_song))
		table.insert(lines, "  boss_key_name: " .. bNameKey)
		table.insert(lines, "  boss_key_count: " .. tostring(state.boss_key_count))
		table.insert(lines, "  boss_keys_required: " .. tostring(state.boss_keys_required))
	end
	
	-- Performance rules
	table.insert(lines, "  fail_allowed: " .. tostring(state.fail_allowed and "true" or "false"))
	table.insert(lines, "  passing_score: " .. tostring(state.passing_score))
	
	local scoreTypeKeys = {
		[0] = "money",
		[1] = "ex",
		[2] = "high_ex"
	}
	table.insert(lines, "  score_type: " .. (scoreTypeKeys[state.score_type] or "ex"))
	
	-- Song count rules
	table.insert(lines, "  number_of_charts: " .. tostring(state.number_of_charts))
	table.insert(lines, "  number_of_starting_charts: " .. tostring(state.number_of_starting_charts))
	
	-- Checks toggles
	table.insert(lines, "  include_85_score_checks: " .. tostring(state.include_85_score_checks and "true" or "false"))
	table.insert(lines, "  include_90_score_checks: " .. tostring(state.include_90_score_checks and "true" or "false"))
	table.insert(lines, "  include_96_score_checks: " .. tostring(state.include_96_score_checks and "true" or "false"))
	table.insert(lines, "  include_98_score_checks: " .. tostring(state.include_98_score_checks and "true" or "false"))
	table.insert(lines, "  include_99_score_checks: " .. tostring(state.include_99_score_checks and "true" or "false"))
	table.insert(lines, "  include_quad_score_checks: " .. tostring(state.include_quad_score_checks and "true" or "false"))
	table.insert(lines, "  include_quint_score_checks: " .. tostring(state.include_quint_score_checks and "true" or "false"))
	
	-- Mod items & traps
	table.insert(lines, "  enable_mod_items: " .. tostring(state.enable_mod_items and "true" or "false"))
	table.insert(lines, "  death_link: " .. tostring(state.death_link and "true" or "false"))
	table.insert(lines, "  trap_chance: " .. tostring(state.trap_chance))
	
	-- Trap Items list
	if #state.trap_items > 0 then
		table.insert(lines, "  trap_items:")
		for _, trap in ipairs(state.trap_items) do
			table.insert(lines, "    - " .. yaml_quote(trap))
		end
	else
		table.insert(lines, "  trap_items: []")
	end
	
	-- Custom Song Pool list
	if #state.custom_song_pool > 0 then
		table.insert(lines, "  custom_song_pool:")
		for _, song in ipairs(state.custom_song_pool) do
			table.insert(lines, "    - " .. yaml_quote(song))
		end
	else
		table.insert(lines, "  custom_song_pool: []")
	end
	
	return table.concat(lines, "\n")
end


