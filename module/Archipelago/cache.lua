-- cache.lua handles loading and saving Archipelago room data, slot names,
-- data packages, and booster items usage information to disk.

local AP = ...

AP.SaveCacheToDisk = function()
	if not AP.seedName or AP.seedName == "Unknown" or not AP.slotInfo or not AP.datapackage then
		return
	end
	local dir = THEME:GetCurrentThemeDirectory() .. "Modules/Archipelago/SAVE_AP_" .. AP.seedName .. "/"
	for slotId, slot_data in pairs(AP.slotInfo) do
		local playerName = AP.playerNames[slotId] or ("Player_" .. tostring(slotId))
		-- Filter out invalid folder/file name characters
		playerName = playerName:gsub("[%s%c\\/:%*%?\"<>|]", "_")
		local gameName = slot_data.game
		local gameData = AP.datapackage[gameName]
		
		if gameData then
			local playerData = {
				playerName = playerName,
				slot = slotId,
				game = gameName,
				itemNames = gameData.itemNames or {},
				locationNames = gameData.locationNames or {}
			}
			local jsonStr = JsonEncode(playerData)
			local path = dir .. playerName .. ".txt"
			local file = RageFileUtil.CreateRageFile()
			if file:Open(path, 2) then -- Mode 2 = Write
				file:Write(jsonStr)
				file:Close()
				file:destroy()
			else
				file:destroy()
				AP.Trace("Archipelago error: Could not write cache file to " .. path)
			end
		end
	end
end

AP.LoadCacheFromDisk = function()
	if not AP.seedName or AP.seedName == "Unknown" then return end
	local dir = THEME:GetCurrentThemeDirectory() .. "Modules/Archipelago/SAVE_AP_" .. AP.seedName .. "/"
	
	if not AP.playerNames then AP.playerNames = {} end
	if not AP.slotInfo then AP.slotInfo = {} end
	if not AP.datapackage then AP.datapackage = {} end
	
	local files = FILEMAN:GetDirListing(dir .. "*", false, false)
	if files and #files > 0 then
		local loadedCount = 0
		for _, filename in ipairs(files) do
			if filename:match("%.txt$") then
				local path = dir .. filename
				local file = RageFileUtil.CreateRageFile()
				if file:Open(path, 1) then -- Mode 1 = Read
					local content = file:Read()
					file:Close()
					file:destroy()
					
					if content then
						local success, data = pcall(JsonDecode, content)
						if success and data and data.slot and data.game then
							local slotId = tonumber(data.slot) or data.slot
							local gameName = data.game
							local playerName = data.playerName or filename:gsub("%.txt$", "")
							
							AP.playerNames[slotId] = playerName
							AP.slotInfo[slotId] = {
								name = playerName,
								game = gameName,
								type = data.type or 0
							}
							
							if not AP.datapackage[gameName] then
								AP.datapackage[gameName] = {
									itemNames = {},
									locationNames = {}
								}
							end
							
							if data.itemNames then
								for id_str, name in pairs(data.itemNames) do
									AP.datapackage[gameName].itemNames[id_str] = name
								end
							end
							if data.locationNames then
								for id_str, name in pairs(data.locationNames) do
									AP.datapackage[gameName].locationNames[id_str] = name
								end
							end
							
							loadedCount = loadedCount + 1
						end
					end
				else
					file:destroy()
				end
			end
		end
		AP.Trace("Loaded " .. tostring(loadedCount) .. " players from local seed cache.")
	end
end

AP.LoadBonusUsage = function()
	AP.bonusUsage = {}
	if AP.seedName == "Unknown" or not AP.SLOT then return end
	
	local dir = THEME:GetCurrentThemeDirectory() .. "Modules/Archipelago/SAVE_AP_" .. AP.seedName .. "/"
	local path = dir .. "Archipelago_Bonus_" .. AP.seedName .. "_" .. AP.SLOT .. ".txt"
	
	local file = RageFileUtil.CreateRageFile()
	if file:Open(path, 1) then -- Mode 1 = Read
		local content = file:Read()
		file:Close()
		file:destroy()
		
		if content then
			for line in content:gmatch("[^\r\n]+") do
			-- Format: song_name:score_type=count
			local name, score_type, count_str = line:match("^([^:]+):([^=]+)=(%d+)$")
				if not AP.bonusUsage[name] then AP.bonusUsage[name] = {money=0, ex=0, hex=0} end
				AP.bonusUsage[name][score_type] = tonumber(count_str)
			end
		end
	else
		file:destroy()
	end
end

AP.SaveBonusUsage = function()
	if AP.seedName == "Unknown" or not AP.SLOT then return end
	local dir = THEME:GetCurrentThemeDirectory() .. "Modules/Archipelago/SAVE_AP_" .. AP.seedName .. "/"
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
	local path = THEME:GetCurrentThemeDirectory() .. "Modules/Archipelago/last_seed.txt"
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
	local path = THEME:GetCurrentThemeDirectory() .. "Modules/Archipelago/last_seed.txt"
	local file = RageFileUtil.CreateRageFile()
	local seedName = nil
	if file:Open(path, 1) then -- Mode 1 = Read
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
