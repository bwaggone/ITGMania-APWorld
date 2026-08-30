-- ui.lua is the place where we create UI elements to support the archipelago game.

local AP = ...

AP.QueueNotification = function(params)
	table.insert(AP.notificationQueue, params)
	MESSAGEMAN:Broadcast("APTriggerShowNext")
end

AP.MakePopupActor = function(screenName)
	local isScreenActive = false
	
	return Def.ActorFrame {
		InitCommand = function(self)
			self:xy(-300, _screen.h - 100)
			isScreenActive = false
		end,
		ScreenChangedMessageCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen and screen:GetName() == screenName then
				-- Transitioning to our screen
			else
				if isScreenActive then
					isScreenActive = false
					self:finishtweening()
					self:x(-300)
					AP.isNotificationActive = false
				end
			end
		end,
		ModuleCommand = function(self)
			isScreenActive = true
			
			-- Handle startup connection popup if initial sync completed before UI loaded
			if AP.initialSyncComplete and AP.lastConnectedState ~= true and AP.apHandlerInstance and AP.apHandlerInstance.connected then
				local slotName = AP.SLOT or "Unknown"
				AP.QueueNotification({ type = "Connected", name = slotName })
				AP.lastConnectedState = true
			end
			
			if #AP.notificationQueue > 0 and not AP.isNotificationActive then
				self:queuecommand("ShowNext")
			end
		end,
		APTriggerShowNextMessageCommand = function(self)
			if isScreenActive and not AP.isNotificationActive then
				self:queuecommand("ShowNext")
			end
		end,
		ShowNextCommand = function(self)
			if #AP.notificationQueue == 0 then
				AP.isNotificationActive = false
				return
			end
			
			AP.isNotificationActive = true
			local params = table.remove(AP.notificationQueue, 1)
			
			local text = ""
			local sub = ""
			local color_highlight = {1, 1, 1, 1}
			
			if params.type == "Received" then
				local displayName = AP.FormatNotificationName(params.name)
				if params.sender then
					sub = displayName .. " (from " .. params.sender .. ")"
				else
					sub = displayName
				end
				if params.name:sub(1, 7) == "Trap - " then
					text = "TRAP RECEIVED"
					color_highlight = {1, 0.5, 0, 1}
				else
					text = "RECEIVED"
					color_highlight = {0.3, 0.9, 0.3, 1}
				end
			elseif params.type == "Sent" then
				text = "CHECK SENT"
				local displayName = AP.FormatNotificationName(params.name)
				if params.receiver then
					sub = displayName .. " (to " .. params.receiver .. ")"
				else
					sub = displayName
				end
				color_highlight = {0.3, 0.6, 0.9, 1}
			elseif params.type == "Connected" then
				text = "ARCHIPELAGO"
				sub = "CONNECTED: " .. tostring(params.name)
				color_highlight = {0.3, 0.9, 0.9, 1}
			elseif params.type == "Disconnected" then
				text = "ARCHIPELAGO"
				sub = "DISCONNECTED"
				color_highlight = {1, 0.3, 0.3, 1}
			end
			
			local label = self:GetChild("Title")
			local subtext = self:GetChild("Subtext")
			local strip = self:GetChild("AccentStrip")
			
			if label then
				label:settext(text)
				label:diffuse(color_highlight)
			end
			if subtext then
				subtext:settext(sub)
			end
			if strip then
				strip:diffuse(color_highlight)
			end
			
			self:finishtweening()
			self:linear(0.25):x(20)
			self:sleep(1.0)
			self:linear(0.25):x(-300)
			self:queuecommand("ShowNext")
		end,
		
		Def.Quad {
			Name = "Background",
			InitCommand = function(self)
				self:zoomto(260, 48)
				self:halign(0):valign(0)
				self:diffuse(0, 0, 0, 0.8)
			end
		},
		Def.Quad {
			Name = "AccentStrip",
			InitCommand = function(self)
				self:zoomto(4, 48)
				self:halign(0):valign(0)
				self:diffuse(1, 1, 1, 1)
			end
		},
		LoadFont("Common Bold") .. {
			Name = "Title",
			InitCommand = function(self)
				self:xy(12, 4)
				self:halign(0):valign(0)
				self:zoom(0.6)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Subtext",
			InitCommand = function(self)
				self:xy(12, 32)
				self:halign(0):valign(0)
				self:zoom(0.5)
			end
		}
	}
end


AP.MakeStatusOverlayActor = function()
	local status_overlay_actor = nil
	local scrollOffset = 1
	local selectedIndex = 1
	local overlay_visible = false
	
	local paneWidth = 720
	local paneHeight = 440
	local RowHeight = 26
	
	-- Helper to update all visible UI components in the overlay
	local function updateOverlayUI(self)
		local backdrop = self:GetChild("Backdrop")
		local container = self:GetChild("Container")
		
		backdrop:visible(overlay_visible)
		container:visible(overlay_visible)
		
		if not overlay_visible then return end
		
		local apHandler = AP.GetAPHandlerInstance()
		if not apHandler or not apHandler.connected then
			container:GetChild("ConnectedGroup"):visible(false)
			container:GetChild("OfflineMsg"):visible(true)
			return
		end
		
		container:GetChild("ConnectedGroup"):visible(true)
		container:GetChild("OfflineMsg"):visible(false)
		
		-- Update metadata: Room and Seed names
		local room_str = "Room: " .. tostring(AP.SLOT)
		local seed_str = "Seed: " .. tostring(AP.seedName)
		local mode_str = ""
		if AP.slotOptions.game_mode == 1 then
			local collected = AP.GetReceivedItemCount(AP.slotOptions.bosskey_name)
			local required = AP.slotOptions.bosskeys_required or 0
			local goal_unlocked = collected >= required
			local goal_status = goal_unlocked and "UNLOCKED" or "LOCKED"
			local display_goal = AP.FormatNotificationName(AP.slotOptions.goal_song)
			mode_str = "    |    Goal: " .. display_goal .. " (" .. goal_status .. ")"
		end
		container:GetChild("ConnectedGroup"):GetChild("RoomSeedText"):settext(room_str .. "    |    " .. seed_str .. mode_str)
		
		local progress_text = ""
		local progress_pct = 0
		if AP.slotOptions.game_mode == 1 then
			local collected = AP.GetReceivedItemCount(AP.slotOptions.bosskey_name)
			local required = AP.slotOptions.bosskeys_required or 0
			progress_pct = math.min(1.0, collected / math.max(1, required))
			progress_text = string.format("%s Progress: %d / %d collected (%.1f%%)", AP.slotOptions.bosskey_name, collected, required, progress_pct * 100)
		else
			-- Update goal progress numbers: count unique song clears by checking how many songs have their "-0" check completed
			local completed_clears = 0
			if AP.locationIds and AP.activeLocationIds then
				for name, id in pairs(AP.locationIds) do
					if name:match("%-0$") and AP.activeLocationIds[id] then
						if AP.checkedLocations and AP.checkedLocations[id] then
							completed_clears = completed_clears + 1
						end
					end
				end
			end
			local target_clears = AP.slotOptions.win_count or 15
			progress_pct = math.min(1.0, completed_clears / math.max(1, target_clears))
			progress_text = string.format("AP Goal Progress: %d / %d clears (%.1f%%)", completed_clears, target_clears, progress_pct * 100)
		end
		
		container:GetChild("ConnectedGroup"):GetChild("ProgressText"):settext(progress_text)
		
		-- Update progress bar quad width
		local bar_fg = container:GetChild("ConnectedGroup"):GetChild("ProgressBarFG")
		bar_fg:zoomto(500 * progress_pct, 12)
		
		-- Update modifier stats line
		local mod_text
		if AP.IsEnforcingMods() then
			local max_bpm, max_filter, mini, bonus_count = AP.GetModifierStats()
			mod_text = string.format("Max Speed: %s    |    BG Filter: %s    |    Mini: %s    |    Score Boosters: %d", max_bpm, max_filter, mini, AP.GetAvailableBonusItems())
		else
			mod_text = string.format("Score Boosters: %d", AP.GetAvailableBonusItems())
		end
		container:GetChild("ConnectedGroup"):GetChild("ModifierText"):settext(mod_text)
		
		-- Update scrollable songs list rows
		local songs = AP.GetUnlockedSongs()
		local list_af = container:GetChild("ConnectedGroup"):GetChild("SongList")
		
		for i = 1, 10 do
			local row = list_af:GetChild("Row" .. i)
			local idx = scrollOffset + i - 1
			if idx <= #songs then
				local song_name = songs[idx]
				local comp, tot = AP.GetChecksForSong(song_name)
				
				-- Trim filename to show only the folder path
				local display_name = AP.FormatNotificationName(song_name)
				row:GetChild("Name"):settext(idx .. ". " .. display_name)
				row:GetChild("Checks"):settext(string.format("[ %d / %d ]", comp, tot))
				
				-- Show/hide selection highlight
				if idx == selectedIndex then
					row:GetChild("Highlight"):visible(true)
					row:GetChild("Name"):diffuse(0.3, 0.9, 0.9, 1) -- highlighted cyan
				else
					row:GetChild("Highlight"):visible(false)
					row:GetChild("Name"):diffuse(1.0, 1.0, 1.0, 1) -- normal white
				end
				
				-- Diffuse color based on completion percentage (green if finished)
				if comp == tot and tot > 0 then
					row:GetChild("Checks"):diffuse(0.3, 1.0, 0.3, 1) -- completed green
				else
					row:GetChild("Checks"):diffuse(1.0, 1.0, 1.0, 1) -- normal white
				end
				row:visible(true)
			else
				row:visible(false)
			end
		end
		
		-- Update details panel for the selected song
		local detail_panel = container:GetChild("ConnectedGroup"):GetChild("DetailPanel")
		if selectedIndex <= #songs then
			local song_name = songs[selectedIndex]
			
			local score_type_names = {
				[0] = "Money",
				[1] = "EX",
				[2] = "High EX"
			}
			local st = AP.NormalizeScoreType(AP.slotOptions.score_type)
			local score_name = score_type_names[st] or "EX"
			local passing_score = AP.slotOptions.passing_score or 0
			local fail_str = AP.slotOptions.fail_allowed and " (Fail OK)" or " (No Fail)"
			local clear_cond_str = string.format("Clear Condition: Minimum %.0f%% %s%s", passing_score, score_name, fail_str)
			detail_panel:GetChild("ClearCondition"):settext(clear_cond_str):zoom(0.75)
			
			local suffixes = { "0", "1", "85", "90", "96", "98", "99", "quad", "quint" }
			local labels = {
				["0"] = "Clear Check 1",
				["1"] = "Clear Check 2",
				["85"] = "85% Score Check",
				["90"] = "90% Score Check",
				["96"] = "96% Score Check",
				["98"] = "98% Score Check",
				["99"] = "99% Score Check",
				["quad"] = "Quad (100% Money)",
				["quint"] = "Quint (100% EX)"
			}
			
			for _, suffix in ipairs(suffixes) do
				local label = labels[suffix]
				local loc_name = song_name .. "-" .. suffix
				local loc_id = AP.locationIds[loc_name]
				local row_actor = detail_panel:GetChild("Check" .. suffix)
				
				if not loc_id or not AP.activeLocationIds[loc_id] then
					-- Inactive check
					row_actor:settext("[-] " .. label .. " (N/A)")
					row_actor:diffuse(0.6, 0.6, 0.6, 0.7) -- lighter readable grey
				else
					-- Active check
					if AP.checkedLocations and AP.checkedLocations[loc_id] then
						-- Checked
						row_actor:settext("[x] " .. label)
						row_actor:diffuse(0.3, 1.0, 0.3, 1) -- green
					else
						-- Unchecked
						row_actor:settext("[ ] " .. label)
						row_actor:diffuse(1.0, 1.0, 1.0, 1) -- white
					end
				end
			end
			detail_panel:visible(true)
		else
			detail_panel:visible(false)
		end
	end

	-- Custom overlay input callback. Consumes all inputs when overlay is active
	local function input(event)
		if not overlay_visible then return false end
		if not event then return false end
		
		if event.type ~= "InputEventType_FirstPress" then
			return false
		end
		
		local key = event.DeviceInput and event.DeviceInput.button
		local game_btn = event.GameButton
		
		-- Global escape / cancel keys
		if key == "DeviceButton_escape" or key == "DeviceButton_F10" or game_btn == "Back" then
			overlay_visible = false
			SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, false)
			end
			MESSAGEMAN:Broadcast("APStatusRefresh")
			return true
		end
		
		if key == "DeviceButton_r" or key == "DeviceButton_R" then
			local apHandler = AP.GetAPHandlerInstance()
			if apHandler and apHandler.connected then
				-- Sync and regenerate playlist
				AP.UpdatePlaylist()
				
				if apHandler.socket then
					local sync_packet = { ["cmd"] = "Sync" }
					local payload = JsonEncode({ sync_packet })
					apHandler.socket:Send(payload, false)
					AP.Trace("Requested Archipelago sync...")
				end
				
				SOUND:PlayOnce(THEME:GetPathS("", "_unlock.ogg"))
				MESSAGEMAN:Broadcast("APStatusRefresh")
			else
				AP.Trace("Cannot sync or update playlist: Offline.")
				SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			end
			return true
		end
		
		if not (event.PlayerNumber and event.button) then
			return false
		end
		
		local songs = AP.GetUnlockedSongs()
		local num_songs = #songs
		
		if game_btn == "MenuDown" or key == "DeviceButton_down" then
			-- Scroll down
			if selectedIndex < num_songs then
				selectedIndex = selectedIndex + 1
				if selectedIndex > scrollOffset + 9 then
					scrollOffset = selectedIndex - 9
				end
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
				MESSAGEMAN:Broadcast("APStatusRefresh")
			end
		elseif game_btn == "MenuUp" or key == "DeviceButton_up" then
			-- Scroll up
			if selectedIndex > 1 then
				selectedIndex = selectedIndex - 1
				if selectedIndex < scrollOffset then
					scrollOffset = selectedIndex
				end
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
				MESSAGEMAN:Broadcast("APStatusRefresh")
			end
		elseif game_btn == "Start" or game_btn == "Select" then
			-- Toggle overlay off
			overlay_visible = false
			SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, false)
			end
			MESSAGEMAN:Broadcast("APStatusRefresh")
		end
		
		return true -- consume input
	end

	-- Toggle overlay active state, routing player input and registering the input listener
	local function toggleOverlay(self)
		overlay_visible = not overlay_visible
		scrollOffset = 1
		selectedIndex = 1
		
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
		
		self:playcommand("Refresh")
	end

	-- Persistent listener registered at screen boot to capture F10 toggle presses
	local function F10_listener(event)
		if event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_F10" then
			if status_overlay_actor then
				status_overlay_actor:playcommand("ToggleOverlay")
			end
			return true
		end
		return false
	end
	
	-- Pre-generate the table list row actors (Def.ActorFrame doesn't support C++ methods during file parsing)
	local song_list_children = {}
	for i = 1, 10 do
		song_list_children[#song_list_children+1] = Def.ActorFrame {
			Name = "Row" .. i,
			InitCommand = function(self)
				self:y((i - 1) * RowHeight - 52)
			end,
			
			-- Highlight background quad (only visible on selected row)
			Def.Quad {
				Name = "Highlight",
				InitCommand = function(self)
					self:zoomto(400, RowHeight):diffuse(0.2, 0.2, 0.2, 0.5):visible(false)
					self:x(-130)
				end
			},
			
			-- Left column: Song Folder name
			LoadFont("Common Normal") .. {
				Name = "Name",
				Text = "",
				InitCommand = function(self)
					self:x(-paneWidth/2 + 30):halign(0):zoom(0.5):maxwidth(320)
				end
			},
			-- Right column: Completion status counters
			LoadFont("Common Normal") .. {
				Name = "Checks",
				Text = "",
				InitCommand = function(self)
					self:x(paneWidth/2 - 280):halign(1):zoom(0.5)
				end
			}
		}
	end

	local af = Def.ActorFrame {
		Name = "APStatusOverlayMain",
		InitCommand = function(self)
			status_overlay_actor = self
			overlay_visible = false
			scrollOffset = 1
			selectedIndex = 1
		end,
		ModuleCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:RemoveInputCallback(F10_listener)
				screen:AddInputCallback(F10_listener)
				screen:RemoveInputCallback(input)
				screen:AddInputCallback(input)
			end
		end,
		OffCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:RemoveInputCallback(F10_listener)
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
		
		APToggleStatusOverlayMessageCommand = function(self)
			self:sleep(0.05):queuecommand("ToggleOverlay")
		end,
		
		APStatusRefreshMessageCommand = function(self)
			self:playcommand("Refresh")
		end,
		
		RefreshCommand = function(self)
			updateOverlayUI(self)
		end,
		
		-- Fullscreen semi-transparent backdrop to dim the background music wheel
		Def.Quad {
			Name = "Backdrop",
			InitCommand = function(self)
				self:FullScreen():diffuse(0,0,0,0.85):visible(false)
			end
		},
		
		-- Center container dialog panel
		Def.ActorFrame {
			Name = "Container",
			InitCommand = function(self)
				self:xy(_screen.cx, _screen.cy):visible(false)
			end,
			
			-- White outer border box
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(paneWidth + 4, paneHeight + 4):diffuse(Color.White)
				end
			},
			-- Main black background body
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(paneWidth, paneHeight):diffuse(Color.Black)
				end
			},
			
			-- Top header background strip
			Def.Quad {
				InitCommand = function(self)
					self:y(-paneHeight/2 + 25):zoomto(paneWidth, 50):diffuse(0.12, 0.12, 0.12, 1)
				end
			},
			
			-- Header title text
			LoadFont("Common Bold") .. {
				Text = "ARCHIPELAGO STATUS",
				InitCommand = function(self)
					self:y(-paneHeight/2 + 18):zoom(0.7):diffuse(0.3, 0.9, 0.9, 1)
				end
			},
			
			-- Bottom footer instructional text
			LoadFont("Common Normal") .. {
				Text = "Use &MENUUP;/&MENUDOWN; to scroll. Press R to sync & regenerate. Press &SELECT;, &BACK;, or ESC to exit.",
				InitCommand = function(self)
					self:y(paneHeight/2 - 18):zoom(0.55):diffuse(0.7, 0.7, 0.7, 1)
				end
			},
			
			-- Offline warning message (only visible if the WebSocket client is disconnected)
			LoadFont("Common Normal") .. {
				Name = "OfflineMsg",
				Text = "Not connected to Archipelago server.",
				InitCommand = function(self)
					self:zoom(0.85):diffuse(1, 0.3, 0.3, 1):visible(true)
				end
			},
			
			-- Container for all statistics and song lists shown when connected
			Def.ActorFrame {
				Name = "ConnectedGroup",
				InitCommand = function(self)
					self:visible(false)
				end,
				
				-- Connection metadata: Room name and Seed name
				LoadFont("Common Normal") .. {
					Name = "RoomSeedText",
					Text = "",
					InitCommand = function(self)
						self:y(-paneHeight/2 + 40):zoom(0.5):diffuse(0.8, 0.8, 0.8, 1)
					end
				},
				
				-- AP Goal Progress count text (e.g. "AP Goal Progress: 10 / 15 checks")
				LoadFont("Common Bold") .. {
					Name = "ProgressText",
					Text = "",
					InitCommand = function(self)
						self:y(-148):zoom(0.6):diffuse(1, 1, 1, 1)
					end
				},
				
				-- Progress bar background border
				Def.Quad {
					Name = "ProgressBarBG",
					InitCommand = function(self)
						self:y(-124):zoomto(502, 14):diffuse(0.3, 0.3, 0.3, 1)
					end
				},
				-- Progress bar inner background fill (dark track)
				Def.Quad {
					InitCommand = function(self)
						self:y(-124):zoomto(500, 12):diffuse(0.08, 0.08, 0.08, 1)
					end
				},
				-- Progress bar active foreground fill (green fill)
				Def.Quad {
					Name = "ProgressBarFG",
					InitCommand = function(self)
						self:y(-124):halign(0):x(-250):zoomto(0, 12):diffuse(0.3, 0.8, 0.3, 1)
					end
				},
				
				-- Active Archipelago modifiers row: Max BPM speed limit, BG filter, and Bonus items
				LoadFont("Common Normal") .. {
					Name = "ModifierText",
					Text = "",
					InitCommand = function(self)
						self:y(-102):zoom(0.52):diffuse(0.9, 0.9, 0.4, 1)
					end
				},
				
				-- Thin divider line separating metadata from song list
				Def.Quad {
					InitCommand = function(self)
						self:y(-90):zoomto(paneWidth - 40, 2):diffuse(0.4, 0.4, 0.4, 1)
					end
				},
				
				-- Left column header (SONG / CHART)
				LoadFont("Common Bold") .. {
					Text = "SONG / CHART",
					InitCommand = function(self)
						self:y(-74):x(-paneWidth/2 + 30):halign(0):zoom(0.5):diffuse(0.6, 0.6, 0.6, 1)
					end
				},
				-- Right column header (CHECKS)
				LoadFont("Common Bold") .. {
					Text = "CHECKS",
					InitCommand = function(self)
						self:y(-74):x(paneWidth/2 - 280):halign(1):zoom(0.5):diffuse(0.6, 0.6, 0.6, 1)
					end
				},
				
				-- Divider vertical line between left list and right details panel
				Def.Quad {
					InitCommand = function(self)
						self:x(90):y(55):zoomto(2, 250):diffuse(0.4, 0.4, 0.4, 1)
					end
				},
				
				-- Right details panel actors
				Def.ActorFrame {
					Name = "DetailPanel",
					InitCommand = function(self)
						self:x(220)
					end,
					
					LoadFont("Common Bold") .. {
						Text = "CHECK DETAILS",
						InitCommand = function(self)
							self:y(-74):halign(0):x(-100):zoom(0.5):diffuse(0.3, 0.9, 0.9, 1)
						end
					},
					
					LoadFont("Common Normal") .. {
						Name = "ClearCondition",
						Text = "",
						InitCommand = function(self)
							self:y(-48):halign(0):x(-100):zoom(0.42):maxwidth(220):diffuse(0.9, 0.9, 0.4, 1)
						end
					},
					
					LoadFont("Common Normal") .. { Name = "Check0", Text = "", InitCommand = function(self) self:y(-22):halign(0):x(-100):zoom(0.45) end },
					LoadFont("Common Normal") .. { Name = "Check1", Text = "", InitCommand = function(self) self:y(0):halign(0):x(-100):zoom(0.45) end },
					LoadFont("Common Normal") .. { Name = "Check85", Text = "", InitCommand = function(self) self:y(22):halign(0):x(-100):zoom(0.45) end },
					LoadFont("Common Normal") .. { Name = "Check90", Text = "", InitCommand = function(self) self:y(44):halign(0):x(-100):zoom(0.45) end },
					LoadFont("Common Normal") .. { Name = "Check96", Text = "", InitCommand = function(self) self:y(66):halign(0):x(-100):zoom(0.45) end },
					LoadFont("Common Normal") .. { Name = "Check98", Text = "", InitCommand = function(self) self:y(88):halign(0):x(-100):zoom(0.45) end },
					LoadFont("Common Normal") .. { Name = "Check99", Text = "", InitCommand = function(self) self:y(110):halign(0):x(-100):zoom(0.45) end },
					LoadFont("Common Normal") .. { Name = "Checkquad", Text = "", InitCommand = function(self) self:y(132):halign(0):x(-100):zoom(0.45) end },
					LoadFont("Common Normal") .. { Name = "Checkquint", Text = "", InitCommand = function(self) self:y(154):halign(0):x(-100):zoom(0.45) end },
				},
				
				-- ActorFrame holding the list of scrollable song rows
				Def.ActorFrame {
					Name = "SongList",
					InitCommand = function(self)
						self:y(10)
					end,
					unpack(song_list_children)
				}
			}
		}
	}
	
	return af
end


AP.MakeEvaluationOverlayActor = function()
	local evaluation_overlay_actor = nil
	local proposed_items = { money = 0, ex = 0, hex = 0 }
	local selected_row = 2
	local overlay_visible = false
	local toggleOverlay = nil
	
	local paneWidth = 560
	local paneHeight = 340
	
	local function getPendingChecks(chart_name, adjustedScore, moneyAdjusted, exAdjusted, is_failed)
		local pending = {}
		local check_suffix = function(suffix, label)
			local loc_name = chart_name .. "-" .. suffix
			local loc_id = AP.locationIds[loc_name]
			if loc_id and AP.activeLocationIds[loc_id] and not AP.checkedLocations[loc_id] then
				table.insert(pending, label)
			end
		end
		
		local fail_allowed = (AP.slotOptions.fail_allowed == true or AP.slotOptions.fail_allowed == 1)
		local passed_clear = false
		if not is_failed or fail_allowed then
			if adjustedScore >= AP.slotOptions.passing_score then
				passed_clear = true
			end
		end
		
		if passed_clear then
			check_suffix("0", "Clear 1")
			check_suffix("1", "Clear 2")
		end
		
		-- Score threshold checks are independent of minimum pass requirement
		if adjustedScore >= 85 then check_suffix("85", "85% Check") end
		if adjustedScore >= 90 then check_suffix("90", "90% Check") end
		if adjustedScore >= 96 then check_suffix("96", "96% Check") end
		if adjustedScore >= 98 then check_suffix("98", "98% Check") end
		if adjustedScore >= 99 then check_suffix("99", "99% Check") end

		if moneyAdjusted >= 100 then
			check_suffix("quad", "Quad (100% Money)")
		end
		if exAdjusted >= 100 and CalculateExScore then
			check_suffix("quint", "Quint (100% EX)")
		end
		
		return pending
	end
	
	local function getPassedChecks(chart_name)
		local passed = {}
		local check_suffix = function(suffix, label)
			local loc_name = chart_name .. "-" .. suffix
			local loc_id = AP.locationIds[loc_name]
			if loc_id and AP.checkedLocations[loc_id] then
				table.insert(passed, label)
			end
		end
		
		check_suffix("0", "Clear 1")
		check_suffix("1", "Clear 2")
		check_suffix("85", "85%")
		check_suffix("90", "90%")
		check_suffix("96", "96%")
		check_suffix("98", "98%")
		check_suffix("99", "99%")
		check_suffix("quad", "Quad")
		check_suffix("quint", "Quint")
		
		return passed
	end
	
	local function updateOverlayUI(self)
		local backdrop = self:GetChild("Backdrop")
		local container = self:GetChild("Container")
		
		backdrop:visible(overlay_visible)
		container:visible(overlay_visible)
		
		if not overlay_visible then return end
		if not AP.LastEvaluation or not AP.LastEvaluation.chart_name then return end
		
		local chart_name = AP.LastEvaluation.chart_name
		local display_name = AP.FormatNotificationName(chart_name)
		container:GetChild("SongNameText"):settext(display_name)
		
		local pn = GAMESTATE:GetEnabledPlayers()[1] or PLAYER_1
		local pdata = AP.LastEvaluation.players[pn]
		if not pdata then return end
		
		local total_spent = AP.GetTotalUsedBonusItems()
		local available = AP.GetAvailableBonusItems()
		
		container:GetChild("StatsText"):settext(string.format(
			"Available: %d (Total Received: %d)   |   Total Spent Globally: %d",
			available, available + total_spent, total_spent
		))

		local st = AP.NormalizeScoreType(AP.slotOptions.score_type)

		-- Row score values (applied start at 0 since each play is a fresh start for consumable boosters)
		local scores = {
			{
				name = "Money Score",
				original = pdata.moneyPercent,
				applied = 0,
				proposed = proposed_items.money,
				is_active = (st == 0)
			},
			{
				name = "EX Score",
				original = pdata.exPercent,
				applied = 0,
				proposed = proposed_items.ex,
				is_active = (st == 1)
			},
			{
				name = "High EX (HEX)",
				original = pdata.highExPercent,
				applied = 0,
				proposed = proposed_items.hex,
				is_active = (st == 2)
			}
		}
		
		for idx, row in ipairs(scores) do
			local label_actor = container:GetChild("Row" .. idx .. "Label")
			local orig_actor = container:GetChild("Row" .. idx .. "Original")
			local arrow_actor = container:GetChild("Row" .. idx .. "Arrow")
			local adj_actor = container:GetChild("Row" .. idx .. "Adjusted")
			
			local label_text = row.name
			if row.is_active then
				label_text = label_text .. " (AP Logic)"
			end
			if selected_row == idx then
				label_text = "> " .. label_text
				
				-- Highlight active row in cyan
				label_actor:diffuse(0.3, 0.9, 0.9, 1)
				orig_actor:diffuse(0.3, 0.9, 0.9, 1)
				arrow_actor:diffuse(0.3, 0.9, 0.9, 1)
				adj_actor:diffuse(0.3, 0.9, 0.3, 1)
			else
				label_text = "  " .. label_text
				
				-- Dim inactive rows in grey
				label_actor:diffuse(0.6, 0.6, 0.6, 1)
				orig_actor:diffuse(0.6, 0.6, 0.6, 1)
				arrow_actor:diffuse(0.6, 0.6, 0.6, 1)
				adj_actor:diffuse(0.7, 0.7, 0.7, 1)
			end
			
			label_actor:settext(label_text)
			
			local current = row.original + (row.applied * 0.25)
			local proposed = current + (row.proposed * 0.25)
			
			orig_actor:settext(string.format("%.2f%%", current))
			
			local adj_str = string.format("%.2f%%", proposed)
			if row.proposed > 0 then
				adj_str = adj_str .. string.format(" (+%d)", row.proposed)
			end
			adj_actor:settext(adj_str)
		end
		
		-- Calculate pending unlocks for logic
		local proposed_money_total = proposed_items.money
		local proposed_ex_total = proposed_items.ex
		local proposed_hex_total = proposed_items.hex
		
		local adjMoneyScore = pdata.moneyPercent + (proposed_money_total * 0.25)
		local adjExScore = pdata.exPercent + (proposed_ex_total * 0.25)
		local adjHexScore = pdata.highExPercent + (proposed_hex_total * 0.25)
		
		local adjustedPercent = adjExScore
		if st == 0 then
			adjustedPercent = adjMoneyScore
		elseif st == 2 then
			adjustedPercent = adjHexScore
		end
		
		local unlocks = getPendingChecks(chart_name, adjustedPercent, adjMoneyScore, adjExScore, pdata.is_failed)
		local unlocks_str = "Will unlock: None"
		if #unlocks > 0 then
			unlocks_str = "Will unlock: " .. table.concat(unlocks, ", ")
		end
		container:GetChild("UnlocksText"):settext(unlocks_str)
		
		-- Calculate passed checks
		local passed = getPassedChecks(chart_name)
		local passed_str = "Already passed: None"
		if #passed > 0 then
			passed_str = "Already passed: " .. table.concat(passed, ", ")
		end
		container:GetChild("PassedText"):settext(passed_str)
	end

	local function input(event)
		if not overlay_visible then return false end
		if not event then return false end
		
		if event.type ~= "InputEventType_FirstPress" then
			return false
		end
		
		local key = event.DeviceInput and event.DeviceInput.button
		local game_btn = event.GameButton
		
		-- Global escape / cancel keys (may not have event.PlayerNumber)
		if key == "DeviceButton_escape" or key == "DeviceButton_F11" or key == "DeviceButton_b" or game_btn == "Back" or game_btn == "Select" then
			AP.FinalizeEvaluationAndSendChecks()
			toggleOverlay()
			return true
		end
		
		if not (event.PlayerNumber and event.button) then
			return false
		end
		
		local available_items = AP.GetAvailableBonusItems()
		local proposed_sum = proposed_items.money + proposed_items.ex + proposed_items.hex
		
		if game_btn == "MenuUp" or key == "DeviceButton_up" then
			selected_row = selected_row - 1
			if selected_row < 1 then selected_row = 3 end
			SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
			MESSAGEMAN:Broadcast("APBonusRefresh")
		elseif game_btn == "MenuDown" or key == "DeviceButton_down" then
			selected_row = selected_row + 1
			if selected_row > 3 then selected_row = 1 end
			SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
			MESSAGEMAN:Broadcast("APBonusRefresh")
		elseif game_btn == "MenuRight" or key == "DeviceButton_right" then
			if proposed_sum < available_items then
				if selected_row == 1 then
					proposed_items.money = proposed_items.money + 1
				elseif selected_row == 2 then
					proposed_items.ex = proposed_items.ex + 1
				elseif selected_row == 3 then
					proposed_items.hex = proposed_items.hex + 1
				end
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
				MESSAGEMAN:Broadcast("APBonusRefresh")
			else
				SOUND:PlayOnce(THEME:GetPathS("Common", "Invalid"))
			end
		elseif game_btn == "MenuLeft" or key == "DeviceButton_left" then
			local current_val = 0
			if selected_row == 1 then current_val = proposed_items.money
			elseif selected_row == 2 then current_val = proposed_items.ex
			elseif selected_row == 3 then current_val = proposed_items.hex
			end
			
			if current_val > 0 then
				if selected_row == 1 then
					proposed_items.money = proposed_items.money - 1
				elseif selected_row == 2 then
					proposed_items.ex = proposed_items.ex - 1
				elseif selected_row == 3 then
					proposed_items.hex = proposed_items.hex - 1
				end
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
				MESSAGEMAN:Broadcast("APBonusRefresh")
			else
				SOUND:PlayOnce(THEME:GetPathS("Common", "Invalid"))
			end
		elseif game_btn == "Start" then
			if proposed_sum > 0 then
				AP.LastEvaluation.proposed_items = proposed_items
				AP.ApplyBonusPercentage(AP.LastEvaluation.chart_name, proposed_items)
				SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
			else
				AP.FinalizeEvaluationAndSendChecks()
			end
			toggleOverlay()
		end
		
		return true
	end

	toggleOverlay = function(self)
		overlay_visible = not overlay_visible
		proposed_items = { money = 0, ex = 0, hex = 0 }
		
		local st = AP.NormalizeScoreType(AP.slotOptions.score_type)
		selected_row = 2
		if st == 0 then selected_row = 1
		elseif st == 2 then selected_row = 3
		end
		
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		
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
		
		MESSAGEMAN:Broadcast("APBonusRefresh")
	end

	local af = Def.ActorFrame {
		Name = "APEvaluationOverlayMain",
		InitCommand = function(self)
			evaluation_overlay_actor = self
			overlay_visible = false
			proposed_items = 0
		end,
		ModuleCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:RemoveInputCallback(input)
				screen:AddInputCallback(input)
			end
			MESSAGEMAN:Broadcast("APBonusRefresh")
			
			-- Auto-popup if they have available items, otherwise finalize immediately
			local available = AP.GetAvailableBonusItems()
			if available > 0 and AP.LastEvaluation and AP.LastEvaluation.chart_name then
				self:queuecommand("AutoPopup")
			else
				AP.FinalizeEvaluationAndSendChecks()
			end
		end,
		AutoPopupCommand = function(self)
			if not overlay_visible then
				toggleOverlay(self)
			end
		end,
		OffCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:RemoveInputCallback(input)
				for player in ivalues(PlayerNumber) do
					SCREENMAN:set_input_redirected(player, false)
				end
			end
			overlay_visible = false
			-- Ensure checks are finalized and sent if leaving screen
			AP.FinalizeEvaluationAndSendChecks()
		end,
		
		ToggleOverlayCommand = function(self)
			toggleOverlay(self)
		end,
		
		APBonusRefreshMessageCommand = function(self)
			self:playcommand("Refresh")
		end,
		
		RefreshCommand = function(self)
			updateOverlayUI(self)
		end,
		
		-- Helper text banner (bottom right corner, matching credits/player name size & style)
		LoadFont("Common Normal") .. {
			Name = "HelperBanner",
			InitCommand = function(self)
				self:xy(_screen.w - SL_WideScale(38, 45), _screen.h - 9):zoom(SL_WideScale(0.8, 0.9))
				self:halign(1):valign(1) -- right and bottom aligned
				
				local textColor = Color.White
				if ThemePrefs and ThemePrefs.Get and ThemePrefs.Get("RainbowMode") and not HolidayCheer() then
					textColor = Color.Black
				end
				self:diffuse(textColor)
				self:diffusealpha(0.8)
			end,
			APBonusRefreshMessageCommand = function(self)
				if AP.LastEvaluation and AP.LastEvaluation.chart_name then
					local available = AP.GetAvailableBonusItems()
					local chart_name = AP.LastEvaluation.chart_name
					
					-- Sum up total applied on this song play
					local applied = 0
					local prop = AP.LastEvaluation.proposed_items
					if prop then
						applied = (prop.money or 0) + (prop.ex or 0) + (prop.hex or 0)
					end
					
					self:settext(string.format("AP Boosters: %d available (%d applied)", available, applied))
					self:visible(not overlay_visible)
					
					-- Dynamic Y position matching ScreenEvaluationSummary vs Stage/Nonstop
					local screen = SCREENMAN:GetTopScreen()
					if screen and screen:GetName() == 'ScreenEvaluationSummary' then
						self:y(_screen.h - 12)
					else
						self:y(_screen.h - 9)
					end
				else
					self:visible(false)
				end
			end
		},
		
		-- Backdrop
		Def.Quad {
			Name = "Backdrop",
			InitCommand = function(self)
				self:FullScreen():diffuse(0, 0, 0, 0.85):visible(false)
			end
		},
		
		-- Container
		Def.ActorFrame {
			Name = "Container",
			InitCommand = function(self)
				self:xy(_screen.cx, _screen.cy):visible(false)
			end,
			
			-- White outer border box
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(paneWidth + 4, paneHeight + 4):diffuse(Color.White)
				end
			},
			-- Main black background body
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(paneWidth, paneHeight):diffuse(Color.Black)
				end
			},
			
			-- Top header background strip
			Def.Quad {
				InitCommand = function(self)
					self:y(-paneHeight/2 + 25):zoomto(paneWidth, 50):diffuse(0.12, 0.12, 0.12, 1)
				end
			},
			
			-- Header title text
			LoadFont("Common Bold") .. {
				Text = "ARCHIPELAGO SCORE ADJUSTER",
				InitCommand = function(self)
					self:y(-paneHeight/2 + 18):zoom(0.65):diffuse(0.3, 0.9, 0.9, 1)
				end
			},
			
			-- Song Name text
			LoadFont("Common Normal") .. {
				Name = "SongNameText",
				Text = "",
				InitCommand = function(self)
					self:y(-paneHeight/2 + 40):zoom(0.48):diffuse(0.8, 0.8, 0.8, 1)
				end
			},
			
			-- Stats label (available, applied)
			LoadFont("Common Normal") .. {
				Name = "StatsText",
				Text = "",
				InitCommand = function(self)
					self:y(-50):zoom(0.55):diffuse(1, 1, 1, 1)
				end
			},
			
			-- Row 1: Money Score Row
			LoadFont("Common Normal") .. { Name = "Row1Label", InitCommand = function(self) self:y(-10):x(-240):halign(0):zoom(0.58) end },
			LoadFont("Common Normal") .. { Name = "Row1Original", InitCommand = function(self) self:y(-10):x(-70):halign(0):zoom(0.58) end },
			LoadFont("Common Normal") .. { Name = "Row1Arrow", Text = "->", InitCommand = function(self) self:y(-10):x(35):halign(0.5):zoom(0.58) end },
			LoadFont("Common Normal") .. { Name = "Row1Adjusted", InitCommand = function(self) self:y(-10):x(55):halign(0):zoom(0.58) end },
			
			-- Row 2: EX Score Row
			LoadFont("Common Normal") .. { Name = "Row2Label", InitCommand = function(self) self:y(20):x(-240):halign(0):zoom(0.58) end },
			LoadFont("Common Normal") .. { Name = "Row2Original", InitCommand = function(self) self:y(20):x(-70):halign(0):zoom(0.58) end },
			LoadFont("Common Normal") .. { Name = "Row2Arrow", Text = "->", InitCommand = function(self) self:y(20):x(35):halign(0.5):zoom(0.58) end },
			LoadFont("Common Normal") .. { Name = "Row2Adjusted", InitCommand = function(self) self:y(20):x(55):halign(0):zoom(0.58) end },
			
			-- Row 3: High EX Score Row
			LoadFont("Common Normal") .. { Name = "Row3Label", InitCommand = function(self) self:y(50):x(-240):halign(0):zoom(0.58) end },
			LoadFont("Common Normal") .. { Name = "Row3Original", InitCommand = function(self) self:y(50):x(-70):halign(0):zoom(0.58) end },
			LoadFont("Common Normal") .. { Name = "Row3Arrow", Text = "->", InitCommand = function(self) self:y(50):x(35):halign(0.5):zoom(0.58) end },
			LoadFont("Common Normal") .. { Name = "Row3Adjusted", InitCommand = function(self) self:y(50):x(55):halign(0):zoom(0.58) end },
			
			-- Unlocked Checks
			LoadFont("Common Normal") .. {
				Name = "UnlocksText",
				Text = "",
				InitCommand = function(self)
					self:y(80):zoom(0.52):diffuse(0.9, 0.9, 0.4, 1):maxwidth(paneWidth - 40)
				end
			},
			
			-- Passed Checks
			LoadFont("Common Normal") .. {
				Name = "PassedText",
				Text = "",
				InitCommand = function(self)
					self:y(108):zoom(0.52):diffuse(0.5, 0.9, 0.5, 1):maxwidth(paneWidth - 40)
				end
			},
			
			-- Divider vertical line before footer
			Def.Quad {
				InitCommand = function(self)
					self:y(paneHeight/2 - 35):zoomto(paneWidth - 40, 1):diffuse(0.3, 0.3, 0.3, 1)
				end
			},
			
			-- Footer / Help instructions
			LoadFont("Common Normal") .. {
				Text = "Use &MENUUP;/&MENUDOWN; to select score, &MENULEFT;/&MENURIGHT; to adjust. Press &START; to apply, &SELECT;/&BACK; to cancel.",
				InitCommand = function(self)
					self:y(paneHeight/2 - 18):zoom(0.52):diffuse(0.7, 0.7, 0.7, 1)
				end
			}
		}
	}
	
	return af
end
