-- network.lua manages the WebSocket client connection to the Archipelago server,
-- handles connection events (open, close, error), and parses and dispatches 
-- incoming JSON packet payloads.

local AP = ...

AP.CreateAPHandler = function() 
  if AP.apHandler == nil then
    AP.apHandler = Def.ActorFrame{
      Name="ArchipelagoHandler",
		InitCommand=function(self)
			AP.apHandlerInstance = self
			AP.apHandlerShuttingDown = false
			self.socket = nil
			self.connected = false
			self.errorMsg = nil

			AP.Trace("Connecting to Archipelago server at: " .. AP.HOST)

			-- Connection time.
			self.socket = NETWORK:WebSocket{
				url=AP.HOST,
				pingInterval=15,
				automaticReconnect=true,
				enableDeflate=true,
				onMessage=function(msg)
					AP.HandleMessage(self, msg)
				end
			}
        end,
		ScreenChangedMessageCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				local name = screen:GetName()
				if name == "ScreenStageInformation" or name == "ScreenGameplay" then
					-- Run the clamps before gameplay starts drawing
					for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
						AP.ClampSpeedMod(pn)
						AP.ClampBackgroundFilter(pn)
						AP.ClampMini(pn)
					end
				elseif name == "ScreenSelectMusic" then
					AP.ClampedWarnings = {} -- Reset warnings on returning to music wheel
				end
			end
		end
      }
  end

  return AP.apHandler
end

AP.HandleMessage = function(self, msg)
	if msg.type == "WebSocketMessageType_Open" then
		AP.Trace("WebSocket transport connected. Waiting for RoomInfo...")
	elseif msg.type == "WebSocketMessageType_Close" then
		self.connected = false
		AP.initialSyncComplete = false
		AP.connectedSlotName = nil
		AP.Trace("Archipelago connection closed: " .. tostring(msg.reason))
		if AP.lastConnectedState == true then
			AP.QueueNotification({ type = "Disconnected" })
			AP.lastConnectedState = false
		end
	elseif msg.type == "WebSocketMessageType_Error" then
		self.connected = false
		AP.initialSyncComplete = false
		AP.connectedSlotName = nil
		AP.Trace("Archipelago connection error: " .. tostring(msg.reason))
		if AP.lastConnectedState == true then
			AP.QueueNotification({ type = "Disconnected" })
			AP.lastConnectedState = false
		end
	elseif msg.type == "WebSocketMessageType_Message" then
		local success, packets = pcall(JsonDecode, msg.data)
		if not success then
			AP.Trace("Failed to decode JSON from Archipelago server: " .. tostring(msg.data))
			return
		end

		for _, packet in ipairs(packets) do
			local packet_cmd = packet["cmd"]
			if packet_cmd == "RoomInfo" then
				AP.seedName = packet["seed_name"] or "Unknown"
				AP.hasDefaultedToSortOrderPreferred = false
				AP.SaveLastSeed(AP.seedName)
				AP.LoadCacheFromDisk()
				AP.Trace("Received RoomInfo (Seed: " .. AP.seedName .. "). Requesting DataPackage...")
				local get_dp_packet = {
					["cmd"] = "GetDataPackage",
					games = packet["games"]
				}
				local payload = JsonEncode({ get_dp_packet })
				self.socket:Send(payload, false)
			elseif packet_cmd == "DataPackage" then
				local games = packet.data and packet.data.games
				
				AP.datapackage = AP.datapackage or {}
				if games then
					for game_name, game_package in pairs(games) do
						AP.datapackage[game_name] = {
							itemNames = {},
							locationNames = {}
						}
						local item_to_id = game_package.item_name_to_id
						if item_to_id then
							for name, id in pairs(item_to_id) do
								AP.datapackage[game_name].itemNames[tostring(id)] = name
							end
						end
						local location_to_id = game_package.location_name_to_id
						if location_to_id then
							for name, id in pairs(location_to_id) do
								AP.datapackage[game_name].locationNames[tostring(id)] = name
							end
						end
					end
				end

				local game_data = games and games[AP.GAME_NAME]
				local item_to_id = game_data and game_data.item_name_to_id
				local location_to_id = game_data and game_data.location_name_to_id

				AP.itemNames = {}
				local count = 0
				if item_to_id then
					for name, id in pairs(item_to_id) do
						AP.itemNames[id] = name
						AP.itemNames[tostring(id)] = name
						count = count + 1
					end
				end

				AP.locationIds = {}
				AP.folderToChartName = {}
				local loc_count = 0
				local cached_folders = 0
				if location_to_id then
					for name, id in pairs(location_to_id) do
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
				AP.Trace("Loaded " .. tostring(count) .. " item names, " .. tostring(loc_count) .. " locations, and " .. tostring(cached_folders) .. " folder mappings from DataPackage.")

				-- Save updated cache to disk
				AP.SaveCacheToDisk()

				AP.Trace("Sending Connect packet...")
				local connect_packet = {
					["cmd"] = "Connect",
					game = AP.GAME_NAME,
					name = AP.SLOT,
					uuid = "itgmania-ap-client-uuid",
					version = { major = 0, minor = 6, build = 8, ["class"] = "Version" },
					items_handling = 7, -- Receive all items (remote, own, starting)
					password = AP.PASSWORD,
					tags = {},
					slot_data = true
				}
				local connect_payload = JsonEncode({ connect_packet })
				self.socket:Send(connect_payload, false)
			elseif packet_cmd == "Connected" then
				self.connected = true
				AP.initialSyncComplete = false
				AP.connectedSlotName = packet.slot
				AP.slotID = packet.slot
				AP.LoadBonusUsage()
				AP.Trace("Successfully connected to Archipelago! Slot: " .. tostring(packet.slot))
				
				-- Store players and slot info
				AP.playerNames = AP.playerNames or {}
				if packet["players"] then
					for _, player in ipairs(packet["players"]) do
						AP.playerNames[player.slot] = player.alias or player.name
					end
				end

				AP.slotInfo = AP.slotInfo or {}
				if packet["slot_info"] then
					for slot_id, info in pairs(packet["slot_info"]) do
						local id = tonumber(slot_id) or slot_id
						AP.slotInfo[id] = {
							name = info.name,
							game = info.game,
							type = info.type
						}
					end
				end

				-- Save updated cache to disk
				AP.SaveCacheToDisk()

				AP.checkedLocations = {}
				AP.activeLocationIds = {}
				if packet["checked_locations"] then
					for _, loc_id in ipairs(packet["checked_locations"]) do
						AP.checkedLocations[loc_id] = true
						AP.activeLocationIds[loc_id] = true
					end
				end
				if packet["missing_locations"] then
					for _, loc_id in ipairs(packet["missing_locations"]) do
						AP.activeLocationIds[loc_id] = true
					end
				end
				
				if packet["slot_data"] then
					if packet["slot_data"]["score_type"] ~= nil then
						AP.slotOptions.score_type = AP.NormalizeScoreType(packet["slot_data"]["score_type"])
					else
						AP.slotOptions.score_type = 1
					end
					AP.slotOptions.passing_score = tonumber(packet["slot_data"]["passing_score"]) or 0
					local fail_all = packet["slot_data"]["fail_allowed"]
					AP.slotOptions.fail_allowed = (fail_all == true or fail_all == 1 or fail_all == "true")
					AP.slotOptions.win_count = tonumber(packet["slot_data"]["win_count"]) or 15
					local enable_mod = packet["slot_data"]["enable_mod_items"]
					AP.slotOptions.enable_mod_items = (enable_mod == true or enable_mod == 1 or enable_mod == "true")
					local death_link = packet["slot_data"]["deathlink_enabled"]
					AP.slotOptions.deathlink_enabled = (death_link == true or death_link == 1 or death_link == "true")
					AP.slotOptions.trap_items = packet["slot_data"]["trap_items"] or {}
					AP.slotOptions.game_mode = tonumber(packet["slot_data"]["game_mode"]) or 0
					AP.slotOptions.goal_song = packet["slot_data"]["goal_song"] or ""
					AP.slotOptions.bosskey_name = packet["slot_data"]["bosskey_name"] or "Boss Key"
					AP.slotOptions.bosskeys_required = tonumber(packet["slot_data"]["bosskeys_required"]) or 0

					if AP.slotOptions.goal_song and AP.slotOptions.goal_song ~= "" then
						local parts = {}
						for part in AP.slotOptions.goal_song:gmatch("[^/]+") do
							table.insert(parts, part)
						end
						local folderName = nil
						if #parts >= 2 then
							folderName = parts[2]
						elseif #parts == 1 then
							folderName = parts[1]
						end
						if folderName then
							AP.folderToChartName[folderName] = AP.slotOptions.goal_song
						end
					end

					AP.Trace("Slot Options - Score Type: " .. tostring(AP.slotOptions.score_type) .. 
					   ", Passing Score: " .. tostring(AP.slotOptions.passing_score) .. 
					   ", Fail Allowed: " .. tostring(AP.slotOptions.fail_allowed) ..
					   ", Win Count: " .. tostring(AP.slotOptions.win_count) ..
					   ", Enable Mod Items: " .. tostring(AP.slotOptions.enable_mod_items) ..
					   ", DeathLink: " .. tostring(AP.slotOptions.deathlink_enabled) ..
					   ", Game Mode: " .. tostring(AP.slotOptions.game_mode) ..
					   ", Goal: " .. tostring(AP.slotOptions.goal_song) ..
					   ", Boss Key Name: " .. tostring(AP.slotOptions.bosskey_name) ..
					   ", Required: " .. tostring(AP.slotOptions.bosskeys_required))

					if AP.slotOptions.deathlink_enabled then
						AP.Trace("DeathLink is enabled. Sending ConnectUpdate...")
						local connect_update = {
							["cmd"] = "ConnectUpdate",
							tags = { "DeathLink" }
						}
						self.socket:Send(JsonEncode({ connect_update }), false)
					end
				end
			elseif packet_cmd == "RoomUpdate" then
				AP.Trace("Received RoomUpdate from server.")
				
				if packet["checked_locations"] then
					if not AP.checkedLocations then AP.checkedLocations = {} end
					if not AP.activeLocationIds then AP.activeLocationIds = {} end
					for _, loc_id in ipairs(packet["checked_locations"]) do
						AP.checkedLocations[loc_id] = true
						AP.activeLocationIds[loc_id] = true
					end
				end
				
				if packet["slot_data"] then
					if packet["slot_data"]["score_type"] ~= nil then
						AP.slotOptions.score_type = AP.NormalizeScoreType(packet["slot_data"]["score_type"])
					end
					if packet["slot_data"]["passing_score"] ~= nil then
						AP.slotOptions.passing_score = tonumber(packet["slot_data"]["passing_score"]) or AP.slotOptions.passing_score
					end
					if packet["slot_data"]["fail_allowed"] ~= nil then
						local val = packet["slot_data"]["fail_allowed"]
						AP.slotOptions.fail_allowed = (val == true or val == 1 or val == "true")
					end
					if packet["slot_data"]["win_count"] ~= nil then
						AP.slotOptions.win_count = tonumber(packet["slot_data"]["win_count"]) or AP.slotOptions.win_count
					end
					if packet["slot_data"]["enable_mod_items"] ~= nil then
						local val = packet["slot_data"]["enable_mod_items"]
						AP.slotOptions.enable_mod_items = (val == true or val == 1 or val == "true")
					end
					if packet["slot_data"]["deathlink_enabled"] ~= nil then
						local val = packet["slot_data"]["deathlink_enabled"]
						AP.slotOptions.deathlink_enabled = (val == true or val == 1 or val == "true")
					end
					AP.slotOptions.trap_items = packet["slot_data"]["trap_items"] or AP.slotOptions.trap_items
					if packet["slot_data"]["game_mode"] ~= nil then
						AP.slotOptions.game_mode = tonumber(packet["slot_data"]["game_mode"]) or AP.slotOptions.game_mode
					end
					AP.slotOptions.goal_song = packet["slot_data"]["goal_song"] or AP.slotOptions.goal_song
					AP.slotOptions.bosskey_name = packet["slot_data"]["bosskey_name"] or AP.slotOptions.bosskey_name
					if packet["slot_data"]["bosskeys_required"] ~= nil then
						AP.slotOptions.bosskeys_required = tonumber(packet["slot_data"]["bosskeys_required"]) or AP.slotOptions.bosskeys_required
					end
					AP.Trace("Updated Slot Options - Score Type: " .. tostring(AP.slotOptions.score_type) .. 
					   ", Passing Score: " .. tostring(AP.slotOptions.passing_score) .. 
					   ", Fail Allowed: " .. tostring(AP.slotOptions.fail_allowed) ..
					   ", Win Count: " .. tostring(AP.slotOptions.win_count) ..
					   ", Enable Mod Items: " .. tostring(AP.slotOptions.enable_mod_items) ..
					   ", DeathLink: " .. tostring(AP.slotOptions.deathlink_enabled) ..
					   ", Game Mode: " .. tostring(AP.slotOptions.game_mode) ..
					   ", Goal: " .. tostring(AP.slotOptions.goal_song) ..
					   ", Boss Key Name: " .. tostring(AP.slotOptions.bosskey_name) ..
					   ", Required: " .. tostring(AP.slotOptions.bosskeys_required))
				end
			elseif packet_cmd == "ConnectionRefused" then
				self.connected = false
				local errs = packet.errors or {}
				local errStr = table.concat(errs, ", ")
				AP.Trace("Archipelago connection refused: " .. errStr)
			elseif packet_cmd == "Bounced" then
				if packet.tags then
					local isDeathLink = false
					for _, tag in ipairs(packet.tags) do
						if tag == "DeathLink" then
							isDeathLink = true
							break
						end
					end
					if isDeathLink then
						local source = (packet.data and packet.data.source) or "someone"
						if source ~= AP.SLOT then
							local topScreen = SCREENMAN:GetTopScreen()
							if topScreen and topScreen:GetName() == "ScreenGameplay" then
								AP.deathlinkArmed = true
								SCREENMAN:SystemMessage("DeathLink received from " .. source .. " - failing song!")
								AP.Trace("Received DeathLink from " .. source)
							end
						end
					end
				end
			elseif packet_cmd == "PrintJSON" then
				local message = AP.ParsePrintJSON(packet.data)
				AP.Trace(message)
				
				-- If it's an ItemSend and we are the finder but not the receiver (foreign item sent)
				if packet.type == "ItemSend" and packet.item then
					local finder = packet.item.player
					local receiver = packet.receiving
					if finder == AP.SLOT and receiver ~= AP.SLOT then
						local item_id = packet.item.item
						local itemName = AP.GetItemName(item_id, receiver)
						local receiverName = AP.GetPlayerName(receiver)
						AP.QueueNotification({
							type = "Sent",
							name = itemName,
							receiver = receiverName
						})
					end
				end
			elseif packet_cmd == "ReceivedItems" then
				local item_count = packet.items and #packet.items or 0
				local base_idx = packet["index"] or 0
				AP.Trace("Received " .. tostring(item_count) .. " items from server (index " .. tostring(base_idx) .. ")")
				if packet.items then
					local isNewItem = self.connected and AP.initialSyncComplete
					if base_idx == 0 then
						AP.AP_AllReceivedItems = {}
					end
					for i, item in ipairs(packet.items) do
						AP.AP_AllReceivedItems[base_idx + i] = item
						local item_id = item.item
						local name = AP.itemNames[item_id] or "Unknown Item"
						if name:find("/") then
							AP.Trace("Received Song: " .. name .. " (ID=" .. tostring(item_id) .. ", Location=" .. tostring(item.location) .. ", Player=" .. tostring(item.player) .. ")")
						else
							AP.Trace("Received Mod/Filler (Non-Song): " .. name .. " (ID=" .. tostring(item_id) .. ", Location=" .. tostring(item.location) .. ", Player=" .. tostring(item.player) .. ")")
						end
						if isNewItem then
							local sender = AP.GetPlayerName(item.player)
							AP.QueueNotification({ type = "Received", name = name, sender = sender })

							-- Queue trap if received during game session
							if name:sub(1, 7) == "Trap - " then
								table.insert(AP.armedTrapQueue, name)
								SCREENMAN:SystemMessage("Trap incoming: " .. name .. " (queued - applies to your next song)")
							end
						end
					end
					AP.initialSyncComplete = true
					AP.UpdatePlaylist()
					
					if AP.connectedSlotName and AP.lastConnectedState ~= true then
						AP.QueueNotification({ type = "Connected", name = AP.connectedSlotName })
						AP.lastConnectedState = true
						AP.connectedSlotName = nil
					end
				end
			else
				AP.Trace("Received unhandled cmd: " .. tostring(packet_cmd))
			end
		end
	end
end

AP.SendVictoryStatus = function()
	if AP.apHandlerInstance and AP.apHandlerInstance.connected and AP.apHandlerInstance.socket then
		AP.Trace("Sending CLIENT_GOAL status update to server...")
		local status_packet = {
			["cmd"] = "StatusUpdate",
			status = 30 -- ClientStatus.CLIENT_GOAL
		}
		local payload = JsonEncode({ status_packet })
		AP.apHandlerInstance.socket:Send(payload, false)
	end
end
