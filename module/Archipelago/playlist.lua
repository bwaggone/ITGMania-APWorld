-- playlist.lua handles the creation and updating of the Archipelago playlist file based on received items.

local AP = ...

AP.UpdatePlaylist = function()
	local apHandler = AP.GetAPHandlerInstance()
	if not apHandler or not apHandler.connected then return end
	if AP.seedName == "Unknown" then return end
	local path = THEME:GetCurrentThemeDirectory() .. "Other/Playlists/Archipelago - " .. AP.seedName .. ".txt"
	local playlist_content = "--- Archipelago\n"
	local count = 0
	
	for _, item in ipairs(AP.AP_AllReceivedItems) do
		local item_id = item.item
		local item_name = AP.itemNames[item_id]
		if item_name and item_name:find("/") then
			-- Parse the path to get only the song directory name (the middle part in Group/Folder/File)
			local parts = {}
			for part in item_name:gmatch("[^/]+") do
				table.insert(parts, part)
			end
			local songFolder = nil
			if #parts >= 2 then
				songFolder = parts[2]
			elseif #parts == 1 then
				songFolder = parts[1]
			end
			
			if songFolder then
				playlist_content = playlist_content .. songFolder .. "\n"
				count = count + 1
				if not SONGMAN:FindSong(songFolder) then
					AP.Trace("Archipelago warning: Received song is not installed: " .. songFolder)
				end
			end
		end
	end

	-- If in Boss Key mode, check if the Goal Song is unlocked, and explicitly add it to the playlist
	if AP.slotOptions.game_mode == 1 and AP.slotOptions.goal_song ~= "" then
		local collected = AP.GetReceivedItemCount(AP.slotOptions.bosskey_name)
		local required = AP.slotOptions.bosskeys_required or 0
		if collected >= required then
			local parts = {}
			for part in AP.slotOptions.goal_song:gmatch("[^/]+") do
				table.insert(parts, part)
			end
			local goalFolder = nil
			if #parts >= 2 then
				goalFolder = parts[2]
			elseif #parts == 1 then
				goalFolder = parts[1]
			end
			
			if goalFolder then
				playlist_content = playlist_content .. goalFolder .. "\n"
				count = count + 1
				if not SONGMAN:FindSong(goalFolder) then
					AP.Trace("Archipelago warning: Unlocked Goal Song is not installed: " .. goalFolder)
				end
			end
		end
	end
	
	if count > 0 then
		local file = RageFileUtil.CreateRageFile()
		if file:Open(path, 2) then
			file:Write(playlist_content)
			file:Close()
			file:destroy()
			AP.Trace("Updated Archipelago playlist: " .. count .. " songs")
			
			-- Force C++ engine to reload the playlist from disk
			SONGMAN:SetPreferredSongs(path, true)
			
			-- If currently on ScreenSelectMusic and sorted by Preferred, refresh the wheel
			local top = SCREENMAN:GetTopScreen()
			if top and top:GetName() == "ScreenSelectMusic" then
				local wheel = top:GetMusicWheel()
				if wheel and GAMESTATE:GetSortOrder() == "SortOrder_Preferred" then
					wheel:ChangeSort("SortOrder_Preferred")
				end
			end
		else
			AP.Trace("Archipelago error: Could not open '" .. path .. "' to write playlist.")
		end
	end
end
