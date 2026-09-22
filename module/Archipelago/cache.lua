-- cache.lua handles loading and saving Archipelago room data, slot names,
-- data packages, and booster items usage information to disk.

local AP = ...

AP.PopulateLocalLookups = function()
	local game_data = AP.datapackage and AP.datapackage[AP.GAME_NAME]
	if not game_data then return end

	local item_to_id = game_data.itemNames
	local location_to_id = game_data.locationNames

	AP.itemNames = AP.itemNames or {}
	local count = 0
	if item_to_id then
		for id_str, name in pairs(item_to_id) do
			local id = tonumber(id_str) or id_str
			AP.itemNames[id] = name
			AP.itemNames[tostring(id)] = name
			count = count + 1
		end
	end

	AP.locationIds = AP.locationIds or {}
	AP.folderToChartName = AP.folderToChartName or {}
	local loc_count = 0
	local cached_folders = 0
	if location_to_id then
		for id_str, name in pairs(location_to_id) do
			local id = tonumber(id_str) or id_str
			AP.locationIds[name] = id
			loc_count = loc_count + 1

			if name:match("%-0$") then
				local base_chart = name:gsub("%-0$", "")
				local parts = {}
				for part in base_chart:gmatch("[^/]+") do
					table.insert(parts, part)
				end
				local folderName = nil
				if #parts >= 2 then
					folderName = parts[2]
				elseif #parts == 1 then
					folderName = parts[1]
				end
				if folderName then
					AP.folderToChartName[folderName] = base_chart
					cached_folders = cached_folders + 1
				end
			end
		end
	end
	AP.Trace("Populated lookups: " .. tostring(count) .. " items, " .. tostring(loc_count) .. " locations, " .. tostring(cached_folders) .. " folder mappings.")
end

AP.SaveCacheToDisk = function()
	if not AP.seedName or AP.seedName == "Unknown" then
		return
	end
	local dir = "/Save/Archipelago/SAVE_AP_" .. AP.seedName .. "/"
	local path = dir .. "cache.json"

	local cacheData = {
		seed = AP.seedName,
		checksums = AP.datapackageChecksums or {},
		slots = AP.slotInfo or {},
		playerNames = AP.playerNames or {},
		datapackage = AP.datapackage or {}
	}

	local success, jsonStr = pcall(JsonEncode, cacheData)
	if not success or not jsonStr then
		AP.Trace("Archipelago error: Failed to serialize cache to JSON")
		return
	end

	local file = RageFileUtil.CreateRageFile()
	if file:Open(path, 2) then -- Mode 2 = Write
		file:Write(jsonStr)
		file:Close()
		file:destroy()
		AP.cacheDirty = false
		AP.Trace("Saved seed cache to " .. path)
	else
		file:destroy()
		AP.Trace("Archipelago error: Could not write cache file to " .. path)
	end
end

AP.LoadCacheFromDisk = function()
	if not AP.seedName or AP.seedName == "Unknown" then return end
	local dir = "/Save/Archipelago/SAVE_AP_" .. AP.seedName .. "/"
	local path = dir .. "cache.json"

	if not AP.playerNames then AP.playerNames = {} end
	if not AP.slotInfo then AP.slotInfo = {} end
	if not AP.datapackage then AP.datapackage = {} end
	if not AP.datapackageChecksums then AP.datapackageChecksums = {} end

	local file = RageFileUtil.CreateRageFile()
	if file:Open(path, 1) then -- Mode 1 = Read
		local content = file:Read()
		file:Close()
		file:destroy()

		if content then
			local success, data = pcall(JsonDecode, content)
			if success and data then
				if data.checksums then
					for k, v in pairs(data.checksums) do
						AP.datapackageChecksums[k] = v
					end
				end
				if data.slots then
					for slot_id, info in pairs(data.slots) do
						local id = tonumber(slot_id) or slot_id
						AP.slotInfo[id] = info
					end
				end
				if data.playerNames then
					for slot_id, name in pairs(data.playerNames) do
						local id = tonumber(slot_id) or slot_id
						AP.playerNames[id] = name
					end
				end
				if data.datapackage then
					for gameName, pkg in pairs(data.datapackage) do
						AP.datapackage[gameName] = pkg
					end
				end
				AP.PopulateLocalLookups()
				AP.Trace("Loaded seed cache from " .. path)
			end
		end
	else
		file:destroy()
	end
end

AP.LoadBonusUsage = function()
	AP.bonusUsage = {}
	if AP.seedName == "Unknown" or not AP.SLOT then return end
	
	local dir = "/Save/Archipelago/SAVE_AP_" .. AP.seedName .. "/"
	local filename = "Archipelago_Bonus_" .. AP.seedName .. "_" .. AP.SLOT .. ".txt"
	local path = dir .. filename
	
	local file = RageFileUtil.CreateRageFile()
	if file:Open(path, 1) then
		local content = file:Read()
		file:Close()
		file:destroy()
		
		if content then
			for line in content:gmatch("[^\r\n]+") do
				-- Format: song_name:score_type=count
				local name, score_type, count_str = line:match("^([^:]+):([^=]+)=(%d+)$")
				if name and score_type and count_str then
					if not AP.bonusUsage[name] then AP.bonusUsage[name] = {money=0, ex=0, hex=0} end
					AP.bonusUsage[name][score_type] = tonumber(count_str)
				end
			end
		end
	else
		file:destroy()
	end
end

AP.SaveBonusUsage = function()
	if AP.seedName == "Unknown" or not AP.SLOT then return end
	local dir = "/Save/Archipelago/SAVE_AP_" .. AP.seedName .. "/"
	local path = dir .. "Archipelago_Bonus_" .. AP.seedName .. "_" .. AP.SLOT .. ".txt"
	local file = RageFileUtil.CreateRageFile()
	if file:Open(path, 2) then -- Mode 2 = Write
		local lines = {}
		for name, usage in pairs(AP.bonusUsage or {}) do
			if type(usage) == "table" then
				if (usage.money or 0) > 0 then
					table.insert(lines, name .. ":money=" .. tostring(usage.money))
				end
				if (usage.ex or 0) > 0 then
					table.insert(lines, name .. ":ex=" .. tostring(usage.ex))
				end
				if (usage.hex or 0) > 0 then
					table.insert(lines, name .. ":hex=" .. tostring(usage.hex))
				end
			end
		end
		local content = table.concat(lines, "\n")
		file:Write(content)
		file:Close()
		file:destroy()
	else
		file:destroy()
		AP.Trace("Archipelago error: Could not save bonus usage to " .. path)
	end
end

AP.SaveLastSeed = function(seedName)
	if not seedName or seedName == "Unknown" then return end
	local path = "/Save/Archipelago/last_seed.txt"
	local file = RageFileUtil.CreateRageFile()
	if file:Open(path, 2) then -- Mode 2 = Write
		file:Write(seedName)
		file:Close()
		file:destroy()
	else
		file:destroy()
	end
end

AP.LoadLastSeed = function()
	local path = "/Save/Archipelago/last_seed.txt"
	local file = RageFileUtil.CreateRageFile()
	local seedName = nil
	if file:Open(path, 1) then
		local content = file:Read()
		file:Close()
		file:destroy()
		if content then
			seedName = content:gsub("[%s\r\n]", "")
		end
	else
		file:destroy()
	end
	return seedName
end
