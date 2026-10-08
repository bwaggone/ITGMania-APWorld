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
				local slotName = AP.GetPlayerName(AP.slotID)
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
				text = params.receiver and "ITEM SENT" or "CHECK SENT"
				local displayName = AP.FormatNotificationName(params.name)
				if params.receiver then
					sub = displayName .. " (to " .. params.receiver .. ")"
				else
					sub = displayName
				end
				color_highlight = {0.2, 0.6, 1.0, 1}
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
				self:zoom(0.5):maxwidth(480)
			end
		}
	}
end


AP.MakeStatusOverlayActor = function()
	local status_overlay_actor = nil
	local activePane = 1 -- 1 = Songs (left), 2 = Recent Activity (right)
	local scrollOffset = 1
	local selectedIndex = 1
	local activityScrollOffset = 1
	local activitySelectedIndex = 1
	local overlay_visible = false
	
	local paneWidth = 720
	local paneHeight = 440
	local visibleSongs = 5
	local suffixes = { "0", "1", "85", "90", "96", "98", "99", "quad", "quint" }
	local short_labels = { "C1", "C2", "85", "90", "96", "98", "99", "Qd", "Qt" }

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
		
		local ver_badge = container:GetChild("VersionBadgeText")
		if ver_badge then
			ver_badge:settext(AP.APWORLD_VERSION or "")
		end
		
		-- Update metadata: Room, Seed, and Goal status
		local room_str = "Room: " .. tostring(AP.SLOT)
		local seed_str = "Seed: " .. tostring(AP.seedName)
		local mode_str = ""
		if AP.slotOptions.game_mode == 1 then
			local collected = AP.GetReceivedItemCount(AP.slotOptions.bosskey_name)
			local required = AP.slotOptions.bosskeys_required or 0
			local goal_unlocked = collected >= required
			local goal_status = goal_unlocked and "UNLOCKED" or "LOCKED"
			local display_goal = AP.FormatNotificationName(AP.slotOptions.goal_song)
			mode_str = "  |  Goal: " .. display_goal .. " (" .. goal_status .. ")"
		end
		container:GetChild("ConnectedGroup"):GetChild("RoomSeedText"):settext(room_str .. "  |  " .. seed_str .. mode_str)
		
		local progress_text = ""
		local progress_pct = 0
		if AP.slotOptions.game_mode == 1 then
			local collected = AP.GetReceivedItemCount(AP.slotOptions.bosskey_name)
			local required = AP.slotOptions.bosskeys_required or 0
			progress_pct = math.min(1.0, collected / math.max(1, required))
			progress_text = string.format("%s: %d / %d collected (%.1f%%)", AP.slotOptions.bosskey_name, collected, required, progress_pct * 100)
		else
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
			progress_text = string.format("AP Goal: %d / %d clears (%.1f%%)", completed_clears, target_clears, progress_pct * 100)
		end
		
		container:GetChild("ConnectedGroup"):GetChild("ProgressText"):settext(progress_text)
		
		-- Update top-right progress bar fill
		local bar_fg = container:GetChild("ConnectedGroup"):GetChild("ProgressBarFG")
		bar_fg:zoomto(192 * progress_pct, 6)
		
		-- Update modifier ribbon stats
		local mod_text = ""
		if AP.IsEnforcingMods() then
			local max_bpm, max_filter, mini, bonus_count = AP.GetModifierStats()
			mod_text = string.format("Max Speed: %s  |  BG Filter: %s  |  Mini: %s", max_bpm, max_filter, mini)
		else
			mod_text = "Standard Modifiers"
		end
		container:GetChild("ConnectedGroup"):GetChild("ModifierText"):settext(mod_text)
		
		local sync_str = "Score Boosters: " .. tostring(AP.GetAvailableBonusItems()) .. " Available  |  Sync: Connected"
		container:GetChild("ConnectedGroup"):GetChild("BoostersSyncText"):settext(sync_str)
		
		-- Update column header styling based on activePane
		local left_header = container:GetChild("ConnectedGroup"):GetChild("LeftPaneHeader")
		local right_header = container:GetChild("ConnectedGroup"):GetChild("RightPaneHeader")
		if left_header and right_header then
			if activePane == 1 then
				left_header:diffuse(0.3, 0.9, 0.9, 1)
				right_header:diffuse(0.55, 0.55, 0.55, 1)
			else
				left_header:diffuse(0.55, 0.55, 0.55, 1)
				right_header:diffuse(0.3, 0.9, 0.9, 1)
			end
		end

		-- Update scrollable songs list rows with in-line checks
		local songs = AP.GetUnlockedSongs()
		local list_af = container:GetChild("ConnectedGroup"):GetChild("SongList")
		
		for i = 1, visibleSongs do
			local row = list_af:GetChild("Row" .. i)
			local idx = scrollOffset + i - 1
			if idx <= #songs then
				local song_name = songs[idx]
				local comp, tot = AP.GetChecksForSong(song_name)
				
				local display_name = AP.FormatNotificationName(song_name)
				row:GetChild("Name"):settext(idx .. ". " .. display_name)
				
				local checks_str = string.format("%d / %d", comp, tot)
				if comp == tot and tot > 0 then
					checks_str = checks_str .. " *"
					row:GetChild("ChecksPillBG"):diffuse(0.08, 0.38, 0.16, 0.9)
					row:GetChild("Checks"):settext(checks_str):diffuse(0.4, 1.0, 0.5, 1)
				else
					row:GetChild("ChecksPillBG"):diffuse(0.12, 0.12, 0.12, 0.8)
					row:GetChild("Checks"):settext(checks_str):diffuse(0.85, 0.85, 0.85, 1)
				end
				
				-- Update individual in-line check badges
				for k = 1, 9 do
					local suffix = suffixes[k]
					local loc_name = song_name .. "-" .. suffix
					local loc_id = AP.locationIds and AP.locationIds[loc_name]
					local check_actor = row:GetChild("Check_" .. k)
					local bg_actor = row:GetChild("BadgeBG_" .. k)
					
					if not loc_id or not (AP.activeLocationIds and AP.activeLocationIds[loc_id]) then
						-- Inactive / disabled check in seed
						bg_actor:diffuse(0.05, 0.05, 0.05, 0.4)
						check_actor:settext("-"):diffuse(0.35, 0.35, 0.35, 0.35)
					elseif AP.checkedLocations and AP.checkedLocations[loc_id] then
						-- Completed check
						bg_actor:diffuse(0.08, 0.38, 0.16, 0.95)
						check_actor:settext(short_labels[k]):diffuse(0.4, 1.0, 0.5, 1)
					else
						-- Active but unchecked
						bg_actor:diffuse(0.14, 0.14, 0.14, 0.85)
						check_actor:settext(short_labels[k]):diffuse(0.7, 0.7, 0.7, 0.9)
					end
				end
				
				-- Show/hide selection highlight
				if idx == selectedIndex then
					row:GetChild("Highlight"):visible(true)
					if activePane == 1 then
						row:GetChild("Highlight"):diffuse(0.12, 0.35, 0.45, 0.6)
						row:GetChild("Name"):diffuse(0.3, 0.9, 0.9, 1)
					else
						row:GetChild("Highlight"):diffuse(0.10, 0.20, 0.25, 0.3)
						row:GetChild("Name"):diffuse(0.85, 0.85, 0.85, 1)
					end
				else
					row:GetChild("Highlight"):visible(false)
					row:GetChild("Name"):diffuse(1.0, 1.0, 1.0, 1)
				end
				
				row:visible(true)
			else
				row:visible(false)
			end
		end
		
		-- Update song navigation status subtext
		local nav_text = string.format("Showing %d-%d of %d songs", math.min(#songs, scrollOffset), math.min(#songs, scrollOffset + visibleSongs - 1), #songs)
		local song_nav = container:GetChild("ConnectedGroup"):GetChild("SongNavStatus")
		song_nav:settext(nav_text)
		if activePane == 1 then
			song_nav:diffuse(0.7, 0.7, 0.7, 1)
		else
			song_nav:diffuse(0.4, 0.4, 0.4, 1)
		end
		
		-- Update Recent Activity Feed on the right pane
		local act_af = container:GetChild("ConnectedGroup"):GetChild("ActivityFeed")
		local activities = AP.RecentActivity or {}
		local has_activity = #activities > 0
		act_af:GetChild("EmptyMsg"):visible(not has_activity)
		
		local max_act_offset = math.max(1, #activities - 4)
		if activityScrollOffset > max_act_offset then
			activityScrollOffset = max_act_offset
		end
		if activityScrollOffset < 1 then
			activityScrollOffset = 1
		end
		if activitySelectedIndex > #activities then
			activitySelectedIndex = math.max(1, #activities)
		end
		
		for i = 1, 5 do
			local card = act_af:GetChild("Event" .. i)
			local ev_idx = activityScrollOffset + i - 1
			local ev = activities[ev_idx]
			if ev then
				local badge_text = ""
				local detail_text = ""
				local subdetail_text = ""
				local border_color = { 0.3, 0.9, 0.9, 1 }
				local badge_color = { 0.3, 0.9, 0.9, 1 }
				
				if ev.type == "received" then
					if ev.isTrap then
						border_color = { 1.0, 0.5, 0.0, 1 }
						badge_color = { 1.0, 0.6, 0.1, 1 }
						badge_text = "! TRAP TRIGGERED"
						detail_text = "Queued " .. (ev.name or "Trap")
						subdetail_text = "sent maliciously by " .. (ev.sender or "Server")
					elseif ev.isSong then
						border_color = { 0.3, 0.9, 0.3, 1 }
						badge_color = { 0.4, 1.0, 0.5, 1 }
						badge_text = "<- RECEIVED SONG"
						detail_text = "Unlocked " .. AP.FormatNotificationName(ev.name)
						subdetail_text = "from " .. (ev.sender or "Server")
					else
						border_color = { 0.25, 0.85, 0.35, 1 }
						badge_color = { 0.35, 0.95, 0.45, 1 }
						badge_text = "<- RECEIVED ITEM"
						detail_text = (ev.name or "Item")
						subdetail_text = "from " .. (ev.sender or "Server")
					end
				elseif ev.type == "sent" then
					border_color = { 0.2, 0.6, 1.0, 1 }
					badge_color = { 0.35, 0.75, 1.0, 1 }
					badge_text = "SENT CHECK ->"
					detail_text = "Found " .. (ev.item or "Item") .. " for " .. (ev.receiver or "Player")
					subdetail_text = (ev.location and ev.location ~= "") and ("at " .. ev.location) or ""
				elseif ev.type == "self_check" then
					border_color = { 0.25, 0.55, 0.95, 1 }
					badge_color = { 0.45, 0.75, 1.0, 1 }
					local count_str = (ev.count and ev.count > 1) and (" (" .. ev.count .. " checks)") or ""
					badge_text = "SENT SELF-CHECK *"
					detail_text = "Completed " .. (ev.song or "Song") .. count_str
					subdetail_text = "Registered locally & synced to AP"
				else
					border_color = { 0.6, 0.6, 0.6, 1 }
					badge_color = { 0.8, 0.8, 0.8, 1 }
					badge_text = "EVENT"
					detail_text = ev.name or ev.item or "Activity recorded"
					subdetail_text = ""
				end
				
				-- Highlight active selection card on right pane
				local hl = card:GetChild("Highlight")
				if hl then
					if ev_idx == activitySelectedIndex then
						hl:visible(true)
						if activePane == 2 then
							hl:diffuse(0.12, 0.35, 0.45, 0.6)
						else
							hl:diffuse(0.10, 0.20, 0.25, 0.3)
						end
					else
						hl:visible(false)
					end
				end
				
				card:GetChild("Border"):diffuse(unpack(border_color))
				card:GetChild("Badge"):settext(badge_text):diffuse(unpack(badge_color))
				card:GetChild("Detail"):settext(detail_text)
				card:GetChild("SubDetail"):settext(subdetail_text)
				card:GetChild("Time"):settext(AP.FormatTimeAgo(ev.timestamp))
				card:visible(true)
			else
				card:visible(false)
			end
		end
		
		-- Update activity navigation status subtext
		local act_nav_text = ""
		if not has_activity then
			act_nav_text = "No activity recorded  |  Press R to Sync"
		else
			local act_start = activityScrollOffset
			local act_end = math.min(#activities, activityScrollOffset + 4)
			act_nav_text = string.format("Showing %d-%d of %d events", act_start, act_end, #activities)
		end
		local act_nav = container:GetChild("ConnectedGroup"):GetChild("ActivityNavStatus")
		act_nav:settext(act_nav_text)
		if activePane == 2 then
			act_nav:diffuse(0.7, 0.7, 0.7, 1)
		else
			act_nav:diffuse(0.4, 0.4, 0.4, 1)
		end
	end

	-- Toggle overlay active state, routing player input and registering the input listener
	local function toggleOverlay(self)
		overlay_visible = not overlay_visible
		activePane = 1
		scrollOffset = 1
		selectedIndex = 1
		activityScrollOffset = 1
		activitySelectedIndex = 1
		
		if overlay_visible then
			SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
			if status_overlay_actor then
				status_overlay_actor:playcommand("DirectInputToAPStatusOverlay")
			end
		else
			SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			if status_overlay_actor then
				status_overlay_actor:queuecommand("DirectInputToEngineFromStatusOverlay")
			end
		end
		
		MESSAGEMAN:Broadcast("APStatusRefresh")
	end

	-- Persistent listener registered at screen boot to capture F10 toggle presses
	local function F10_listener(event)
		if overlay_visible then return false end
		if event.type == "InputEventType_FirstPress" and event.DeviceInput and event.DeviceInput.button == "DeviceButton_F10" then
			if status_overlay_actor then
				status_overlay_actor:playcommand("ToggleOverlay")
			end
			return true
		end
		return false
	end
	
	-- Pre-generate the 5 2-line song list row actors
	local song_list_children = {}
	for i = 1, 5 do
		local row_children = {
			Name = "Row" .. i,
			InitCommand = function(self)
				self:xy(-175, -78 + (i - 1) * 50)
			end,
			
			-- Base row background quad
			Def.Quad {
				Name = "RowBG",
				InitCommand = function(self)
					self:zoomto(330, 48):diffuse(0.08, 0.08, 0.08, 0.85)
				end
			},
			
			-- Selection highlight quad
			Def.Quad {
				Name = "Highlight",
				InitCommand = function(self)
					self:zoomto(330, 48):diffuse(0.12, 0.35, 0.45, 0.5):visible(false)
				end
			},
			
			-- Top line: Song name
			LoadFont("Common Normal") .. {
				Name = "Name",
				Text = "",
				InitCommand = function(self)
					self:x(-155):y(-12):halign(0):zoom(0.58):maxwidth(250 / 0.58)
				end
			},
			
			-- Top line: Checks total pill background
			Def.Quad {
				Name = "ChecksPillBG",
				InitCommand = function(self)
					self:x(135):y(-12):zoomto(56, 18):diffuse(0.12, 0.12, 0.12, 0.8)
				end
			},
			
			-- Top line: Checks total text
			LoadFont("Common Normal") .. {
				Name = "Checks",
				Text = "",
				InitCommand = function(self)
					self:x(135):y(-12):halign(0.5):zoom(0.50)
				end
			}
		}
		
		-- Bottom line: 9 In-Line Check status badge boxes
		for k = 1, 9 do
			row_children[#row_children+1] = Def.Quad {
				Name = "BadgeBG_" .. k,
				InitCommand = function(self)
					self:x(-144 + (k - 1) * 29):y(12):zoomto(26, 16):diffuse(0.06, 0.06, 0.06, 0.8)
				end
			}
			row_children[#row_children+1] = LoadFont("Common Normal") .. {
				Name = "Check_" .. k,
				Text = short_labels[k],
				InitCommand = function(self)
					self:x(-144 + (k - 1) * 29):y(12):halign(0.5):zoom(0.44)
				end
			}
		end
		
		song_list_children[#song_list_children+1] = Def.ActorFrame(row_children)
	end

	-- Pre-generate the 5 3-line activity feed event cards
	local activity_cards = {}
	for i = 1, 5 do
		activity_cards[#activity_cards+1] = Def.ActorFrame {
			Name = "Event" .. i,
			InitCommand = function(self)
				self:xy(175, -78 + (i - 1) * 50):visible(false)
			end,
			
			-- Background container quad
			Def.Quad {
				Name = "BG",
				InitCommand = function(self)
					self:zoomto(330, 48):diffuse(0.08, 0.08, 0.08, 0.85)
				end
			},
			
			-- Selection highlight quad
			Def.Quad {
				Name = "Highlight",
				InitCommand = function(self)
					self:zoomto(330, 48):diffuse(0.12, 0.35, 0.45, 0.6):visible(false)
				end
			},
			
			-- Left colored accent bar
			Def.Quad {
				Name = "Border",
				InitCommand = function(self)
					self:x(-163):zoomto(4, 48):diffuse(0.3, 0.9, 0.9, 1)
				end
			},
			
			-- Top-left: Event type badge text
			LoadFont("Common Normal") .. {
				Name = "Badge",
				Text = "",
				InitCommand = function(self)
					self:x(-154):y(-14):halign(0):zoom(0.50)
				end
			},
			
			-- Top-right: Timestamp text
			LoadFont("Common Normal") .. {
				Name = "Time",
				Text = "",
				InitCommand = function(self)
					self:x(155):y(-14):halign(1):zoom(0.42):diffuse(0.55, 0.55, 0.55, 1)
				end
			},
			
			-- Middle line: Primary detail text
			LoadFont("Common Normal") .. {
				Name = "Detail",
				Text = "",
				InitCommand = function(self)
					self:x(-154):y(0):halign(0):zoom(0.56):maxwidth(305 / 0.56)
				end
			},
			
			-- Bottom line: Secondary context text
			LoadFont("Common Normal") .. {
				Name = "SubDetail",
				Text = "",
				InitCommand = function(self)
					self:x(-154):y(14):halign(0):zoom(0.46):diffuse(0.6, 0.6, 0.6, 1):maxwidth(305 / 0.46)
				end
			}
		}
	end

	local af = Def.ActorFrame {
		Name = "APStatusOverlayMain",
		InitCommand = function(self)
			status_overlay_actor = self
			self.statusOverlayInputHandler = nil
			self.armed = false
			overlay_visible = false
			scrollOffset = 1
			selectedIndex = 1
		end,
		ScreenChangedMessageCommand = function(self)
			if not self.armed then return end
			local screen = SCREENMAN:GetTopScreen()
			if not screen or not screen:GetName():find("ScreenSelectMusic") then
				self.armed = false
				self:playcommand("DirectInputToEngineFromStatusOverlay")
				overlay_visible = false
			end
		end,
		ModuleCommand = function(self)
			self:stoptweening()
			self.armed = true
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:RemoveInputCallback(F10_listener)
				screen:AddInputCallback(F10_listener)
			end

			-- Defensively release any leftover input redirection
			self:playcommand("DirectInputToEngineFromStatusOverlay")

			overlay_visible = false
			MESSAGEMAN:Broadcast("APStatusRefresh")
		end,
		DirectInputToAPStatusOverlayCommand = function(self)
			local top = SCREENMAN:GetTopScreen()
			if not top then return end

			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, true)
			end

			if self.statusOverlayInputHandler then return end

			self.statusOverlayInputHandler = function(event)
				if not overlay_visible then return false end

				-- Re-assert input redirection on every event while overlay is active
				for player in ivalues(PlayerNumber) do
					SCREENMAN:set_input_redirected(player, true)
				end

				if not event then return false end
				if event.type ~= "InputEventType_FirstPress" then
					return true -- Consume repeat / release events while overlay is active
				end

				local key = event.DeviceInput and event.DeviceInput.button
				local game_btn = event.GameButton

				-- Global escape / cancel / close keys
				if key == "DeviceButton_escape" or key == "DeviceButton_F10" or game_btn == "Back" or game_btn == "Start" then
					toggleOverlay(self)
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
					return true
				end

				local songs = AP.GetUnlockedSongs()
				local num_songs = #songs

				if game_btn == "MenuRight" or key == "DeviceButton_right" or event.button == "MenuRight" or event.button == "Right" then
					-- Switch to Right Pane (Recent Activity)
					local activities = AP.RecentActivity or {}
					if activePane ~= 2 and #activities > 0 then
						activePane = 2
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
						MESSAGEMAN:Broadcast("APStatusRefresh")
					end
					return true
				elseif game_btn == "MenuLeft" or key == "DeviceButton_left" or event.button == "MenuLeft" or event.button == "Left" then
					-- Switch to Left Pane (Songs)
					if activePane ~= 1 then
						activePane = 1
						SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
						MESSAGEMAN:Broadcast("APStatusRefresh")
					end
					return true
				elseif game_btn == "MenuDown" or key == "DeviceButton_down" or event.button == "MenuDown" or event.button == "Down" then
					if activePane == 1 then
						-- Scroll down songs in left pane
						if selectedIndex < num_songs then
							selectedIndex = selectedIndex + 1
							if selectedIndex > scrollOffset + visibleSongs - 1 then
								scrollOffset = selectedIndex - (visibleSongs - 1)
							end
							SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
							MESSAGEMAN:Broadcast("APStatusRefresh")
						end
					else
						-- Scroll down activities in right pane
						local activities = AP.RecentActivity or {}
						if activitySelectedIndex < #activities then
							activitySelectedIndex = activitySelectedIndex + 1
							if activitySelectedIndex > activityScrollOffset + 5 - 1 then
								activityScrollOffset = activitySelectedIndex - (5 - 1)
							end
							SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
							MESSAGEMAN:Broadcast("APStatusRefresh")
						end
					end
					return true
				elseif game_btn == "MenuUp" or key == "DeviceButton_up" or event.button == "MenuUp" or event.button == "Up" then
					if activePane == 1 then
						-- Scroll up songs in left pane
						if selectedIndex > 1 then
							selectedIndex = selectedIndex - 1
							if selectedIndex < scrollOffset then
								scrollOffset = selectedIndex
							end
							SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
							MESSAGEMAN:Broadcast("APStatusRefresh")
						end
					else
						-- Scroll up activities in right pane
						if activitySelectedIndex > 1 then
							activitySelectedIndex = activitySelectedIndex - 1
							if activitySelectedIndex < activityScrollOffset then
								activityScrollOffset = activitySelectedIndex
							end
							SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
							MESSAGEMAN:Broadcast("APStatusRefresh")
						end
					end
					return true
				end

				return true
			end

			top:AddInputCallback(self.statusOverlayInputHandler)
		end,
		DirectInputToEngineFromStatusOverlayCommand = function(self)
			local top = SCREENMAN:GetTopScreen()
			if top and self.statusOverlayInputHandler and type(top.RemoveInputCallback) == "function" then
				top:RemoveInputCallback(self.statusOverlayInputHandler)
			end
			self.statusOverlayInputHandler = nil

			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, false)
			end
		end,
		OffCommand = function(self)
			self.armed = false
			local screen = SCREENMAN:GetTopScreen()
			if screen and type(screen.RemoveInputCallback) == "function" then
				screen:RemoveInputCallback(F10_listener)
			end
			self:playcommand("DirectInputToEngineFromStatusOverlay")
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
					self:y(-paneHeight/2 + 28):zoomto(paneWidth, 56):diffuse(0.09, 0.09, 0.09, 1)
				end
			},
			
			-- Top-left: Header title text
			LoadFont("Common Normal") .. {
				Text = "ARCHIPELAGO STATUS",
				InitCommand = function(self)
					self:x(-340):y(-paneHeight/2 + 18):halign(0):zoom(0.80):diffuse(0.3, 0.9, 0.9, 1)
				end
			},
			
			-- Top-left: Version badge
			Def.Quad {
				Name = "VersionBadgeBG",
				InitCommand = function(self)
					self:x(-105):y(-paneHeight/2 + 18):zoomto(54, 18):diffuse(0.05, 0.20, 0.25, 1)
				end
			},
			LoadFont("Common Normal") .. {
				Name = "VersionBadgeText",
				InitCommand = function(self)
					self:x(-105):y(-paneHeight/2 + 18):zoom(0.44):diffuse(0.4, 0.9, 1, 1)
					self:settext(AP.APWORLD_VERSION or "")
				end
			},
			
			-- Bottom footer instructional strip
			Def.Quad {
				InitCommand = function(self)
					self:y(paneHeight/2 - 16):zoomto(paneWidth, 32):diffuse(0.08, 0.08, 0.08, 1)
				end
			},
			LoadFont("Common Normal") .. {
				Text = "Use &MENULEFT;/&MENURIGHT; to switch panes, &MENUUP;/&MENUDOWN; to scroll. Press R to sync. &BACK;/ESC to exit.",
				InitCommand = function(self)
					self:x(-340):y(paneHeight/2 - 16):halign(0):zoom(0.48):diffuse(0.7, 0.7, 0.7, 1)
				end
			},
			LoadFont("Common Normal") .. {
				Text = "Simply Love * Archipelago",
				InitCommand = function(self)
					self:x(335):y(paneHeight/2 - 16):halign(1):zoom(0.44):diffuse(0.3, 0.85, 0.9, 1)
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
				
				-- Connection metadata: Room name, Seed name, and Goal status
				LoadFont("Common Normal") .. {
					Name = "RoomSeedText",
					Text = "",
					InitCommand = function(self)
						self:x(-340):y(-paneHeight/2 + 41):halign(0):zoom(0.54):diffuse(0.75, 0.75, 0.75, 1)
					end
				},
				
				-- AP Goal Progress count text (top-right)
				LoadFont("Common Normal") .. {
					Name = "ProgressText",
					Text = "",
					InitCommand = function(self)
						self:x(340):y(-paneHeight/2 + 18):halign(1):zoom(0.56):diffuse(0.9, 0.9, 0.9, 1)
					end
				},
				
				-- Progress bar track (top-right)
				Def.Quad {
					Name = "ProgressBarBG",
					InitCommand = function(self)
						self:x(245):y(-paneHeight/2 + 41):zoomto(194, 8):diffuse(0.25, 0.25, 0.25, 1)
					end
				},
				Def.Quad {
					InitCommand = function(self)
						self:x(245):y(-paneHeight/2 + 41):zoomto(192, 6):diffuse(0.08, 0.08, 0.08, 1)
					end
				},
				Def.Quad {
					Name = "ProgressBarFG",
					InitCommand = function(self)
						self:x(149):y(-paneHeight/2 + 41):halign(0):zoomto(0, 6):diffuse(0.2, 0.85, 0.4, 1)
					end
				},
				
				-- Active Archipelago modifiers ribbon strip
				Def.Quad {
					InitCommand = function(self)
						self:y(-146):zoomto(paneWidth, 26):diffuse(0.06, 0.06, 0.06, 1)
					end
				},
				LoadFont("Common Normal") .. {
					Name = "ModifierText",
					Text = "",
					InitCommand = function(self)
						self:x(-340):y(-146):halign(0):zoom(0.50):diffuse(0.95, 0.85, 0.3, 1)
					end
				},
				LoadFont("Common Normal") .. {
					Name = "BoostersSyncText",
					Text = "",
					InitCommand = function(self)
						self:x(340):y(-146):halign(1):zoom(0.50):diffuse(0.85, 0.85, 0.85, 1)
					end
				},
				
				-- Divider line below ribbon
				Def.Quad {
					InitCommand = function(self)
						self:y(-133):zoomto(paneWidth - 30, 1):diffuse(0.2, 0.2, 0.2, 1)
					end
				},
				
				-- Column Header (Left Pane: SONG / IN-LINE CHECKS)
				LoadFont("Common Normal") .. {
					Name = "LeftPaneHeader",
					Text = "SONG / IN-LINE CHECKS",
					InitCommand = function(self)
						self:y(-120):x(-340):halign(0):zoom(0.50):diffuse(0.3, 0.9, 0.9, 1)
					end
				},
				LoadFont("Common Normal") .. {
					Text = "TOTAL",
					InitCommand = function(self)
						self:y(-120):x(-20):halign(1):zoom(0.46):diffuse(0.6, 0.6, 0.6, 1)
					end
				},
				
				-- Column Header (Right Pane: RECENT ACTIVITY & CHECKS)
				LoadFont("Common Normal") .. {
					Name = "RightPaneHeader",
					Text = "RECENT ACTIVITY & CHECKS",
					InitCommand = function(self)
						self:y(-120):x(15):halign(0):zoom(0.50):diffuse(0.55, 0.55, 0.55, 1)
					end
				},
				LoadFont("Common Normal") .. {
					Text = "SENT",
					InitCommand = function(self)
						self:y(-120):x(285):zoom(0.40):diffuse(0.2, 0.6, 1.0, 1)
					end
				},
				LoadFont("Common Normal") .. {
					Text = "RECEIVED",
					InitCommand = function(self)
						self:y(-120):x(325):zoom(0.40):diffuse(0.3, 0.9, 0.3, 1)
					end
				},
				
				-- Vertical divider line between left and right panes
				Def.Quad {
					InitCommand = function(self)
						self:x(-2):y(30):zoomto(1.5, 290):diffuse(0.2, 0.2, 0.2, 1)
					end
				},
				
				-- Left Pane: Scrollable song rows
				Def.ActorFrame {
					Name = "SongList",
					InitCommand = function(self)
						self:x(0):y(0)
					end,
					unpack(song_list_children)
				},
				
				-- Left Pane bottom navigation subtext
				LoadFont("Common Normal") .. {
					Name = "SongNavStatus",
					Text = "",
					InitCommand = function(self)
						self:x(-180):y(158):zoom(0.46):diffuse(0.5, 0.5, 0.5, 1)
					end
				},
				
				-- Right Pane: Recent activity feed cards
				Def.ActorFrame {
					Name = "ActivityFeed",
					InitCommand = function(self)
						self:x(0):y(0)
					end,
					
					-- Empty activity message
					LoadFont("Common Normal") .. {
						Name = "EmptyMsg",
						Text = "No recent activity yet.\nPlay songs to send checks!",
						InitCommand = function(self)
							self:x(175):y(25):zoom(0.5):diffuse(0.6, 0.6, 0.6, 1):visible(true)
						end
					},
					
					unpack(activity_cards)
				},
				
				-- Right Pane bottom subtext
				LoadFont("Common Normal") .. {
					Name = "ActivityNavStatus",
					Text = "Tracking last 25 multiworld events  •  Press R to Sync",
					InitCommand = function(self)
						self:x(175):y(158):zoom(0.46):diffuse(0.5, 0.5, 0.5, 1)
					end
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

	local function getSLEventOverlay()
		local screen = SCREENMAN:GetTopScreen()
		if not screen or type(screen.GetChild) ~= "function" then return nil, nil end
		local overlay = screen:GetChild("Overlay")
		if not overlay or type(overlay.GetChild) ~= "function" then return nil, nil end
		local evalCommon = overlay:GetChild("ScreenEval Common")
		if not evalCommon or type(evalCommon.GetChild) ~= "function" then return nil, nil end
		local autoSubmitMaster = evalCommon:GetChild("AutoSubmitMaster")
		if not autoSubmitMaster or type(autoSubmitMaster.GetChild) ~= "function" then return nil, nil end
		local eventOverlay = autoSubmitMaster:GetChild("EventOverlay")
		return eventOverlay, evalCommon
	end

	toggleOverlay = function(self)
		if not overlay_visible then
			if not AP.LastEvaluation or not AP.LastEvaluation.chart_name or not AP.IsChartInSongPool(AP.LastEvaluation.chart_name) then
				return
			end
		end

		overlay_visible = not overlay_visible
		proposed_items = { money = 0, ex = 0, hex = 0 }
		
		local st = AP.NormalizeScoreType(AP.slotOptions.score_type)
		selected_row = 2
		if st == 0 then selected_row = 1
		elseif st == 2 then selected_row = 3
		end
		
		if overlay_visible then
			SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
			if evaluation_overlay_actor then
				evaluation_overlay_actor:playcommand("DirectInputToAPEvalOverlay")
			end
		else
			SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			if evaluation_overlay_actor then
				evaluation_overlay_actor:queuecommand("DirectInputToEngineFromEvalOverlay")
			end
		end
		
		MESSAGEMAN:Broadcast("APBonusRefresh")
	end

	local function F10_listener(event)
		if overlay_visible then return false end
		if not AP.LastEvaluation or not AP.LastEvaluation.chart_name or not AP.IsChartInSongPool(AP.LastEvaluation.chart_name) then
			return false
		end
		if event.type == "InputEventType_FirstPress" and event.DeviceInput and event.DeviceInput.button == "DeviceButton_F10" then
			if evaluation_overlay_actor then
				evaluation_overlay_actor:playcommand("ToggleOverlay")
			end
			return true
		end
		return false
	end

	local af = Def.ActorFrame {
		Name = "APEvaluationOverlayMain",
		InitCommand = function(self)
			evaluation_overlay_actor = self
			self.evalOverlayInputHandler = nil
			self.armed = false
			overlay_visible = false
			proposed_items = { money = 0, ex = 0, hex = 0 }
		end,
		ScreenChangedMessageCommand = function(self)
			if not self.armed then return end
			local screen = SCREENMAN:GetTopScreen()
			if not screen or not screen:GetName():find("ScreenEvaluation") then
				self.armed = false
				self:playcommand("DirectInputToEngineFromEvalOverlay")
				overlay_visible = false
				AP.pendingSLEventOverlay = false
				AP.FinalizeEvaluationAndSendChecks()
				AP.LastEvaluation = nil
			end
		end,
		ModuleCommand = function(self)
			self:stoptweening()
			self.armed = true
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:RemoveInputCallback(F10_listener)
				screen:AddInputCallback(F10_listener)
			end
			
			-- Defensively release any leftover input redirection (e.g. from Ctrl+R restarts)
			self:playcommand("DirectInputToEngineFromEvalOverlay")
			
			overlay_visible = false
			AP.pendingSLEventOverlay = false
			MESSAGEMAN:Broadcast("APBonusRefresh")
			
			-- Auto-popup if they have available items and song is in AP pool, otherwise finalize immediately
			local available = AP.GetAvailableBonusItems()
			if available > 0 and AP.LastEvaluation and AP.LastEvaluation.chart_name and AP.IsChartInSongPool(AP.LastEvaluation.chart_name) then
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
		DirectInputToAPEvalOverlayCommand = function(self)
			local top = SCREENMAN:GetTopScreen()
			if not top then return end

			local eventOverlay, evalCommon = getSLEventOverlay()
			if eventOverlay and eventOverlay:GetVisible() then
				eventOverlay:visible(false)
				AP.pendingSLEventOverlay = true
			end

			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, true)
			end

			if self.evalOverlayInputHandler then return end

			self.evalOverlayInputHandler = function(event)
				if not overlay_visible then return false end

				-- Re-assert input redirection on every event while overlay is active
				for player in ivalues(PlayerNumber) do
					SCREENMAN:set_input_redirected(player, true)
				end

				if not event then return false end
				if event.type ~= "InputEventType_FirstPress" then
					return true -- Consume repeat / release events while overlay is active
				end

				local key = event.DeviceInput and event.DeviceInput.button
				local game_btn = event.GameButton

				-- Global escape / cancel keys (may not have event.PlayerNumber)
				if key == "DeviceButton_escape" or key == "DeviceButton_F10" or key == "DeviceButton_b" or game_btn == "Back" then
					AP.FinalizeEvaluationAndSendChecks()
					toggleOverlay(self)
					return true
				end

				if not (event.PlayerNumber and event.button) then
					return true
				end

				local available_items = AP.GetAvailableBonusItems()
				local proposed_sum = proposed_items.money + proposed_items.ex + proposed_items.hex

				if game_btn == "MenuUp" or key == "DeviceButton_up" then
					selected_row = selected_row - 1
					if selected_row < 1 then selected_row = 3 end
					SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					MESSAGEMAN:Broadcast("APBonusRefresh")
					return true
				elseif game_btn == "MenuDown" or key == "DeviceButton_down" then
					selected_row = selected_row + 1
					if selected_row > 3 then selected_row = 1 end
					SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
					MESSAGEMAN:Broadcast("APBonusRefresh")
					return true
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
					return true
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
					return true
				elseif game_btn == "Start" then
					if proposed_sum > 0 then
						AP.LastEvaluation.proposed_items = proposed_items
						AP.ApplyBonusPercentage(AP.LastEvaluation.chart_name, proposed_items)
						SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
					else
						AP.FinalizeEvaluationAndSendChecks()
					end
					toggleOverlay(self)
					return true
				end

				return true
			end

			top:AddInputCallback(self.evalOverlayInputHandler)
		end,
		DirectInputToEngineFromEvalOverlayCommand = function(self)
			local top = SCREENMAN:GetTopScreen()
			if top and self.evalOverlayInputHandler and type(top.RemoveInputCallback) == "function" then
				top:RemoveInputCallback(self.evalOverlayInputHandler)
			end
			self.evalOverlayInputHandler = nil

			local eventOverlay, evalCommon = getSLEventOverlay()
			if AP.pendingSLEventOverlay and eventOverlay and evalCommon then
				eventOverlay:visible(true)
				evalCommon:queuecommand("DirectInputToEventOverlayHandler")
				AP.pendingSLEventOverlay = false
			else
				if not (eventOverlay and eventOverlay:GetVisible()) then
					for player in ivalues(PlayerNumber) do
						SCREENMAN:set_input_redirected(player, false)
					end
					if evalCommon then
						evalCommon:queuecommand("DirectInputToEngine")
					end
				end
			end
		end,
		OffCommand = function(self)
			self.armed = false
			local screen = SCREENMAN:GetTopScreen()
			if screen and type(screen.RemoveInputCallback) == "function" then
				screen:RemoveInputCallback(F10_listener)
			end
			self:playcommand("DirectInputToEngineFromEvalOverlay")
			overlay_visible = false
			AP.pendingSLEventOverlay = false
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
				Text = "Use &MENUUP;/&MENUDOWN; to select score, &MENULEFT;/&MENURIGHT; to adjust. Press &START; to apply, &BACK; to cancel.",
				InitCommand = function(self)
					self:y(paneHeight/2 - 18):zoom(0.52):diffuse(0.7, 0.7, 0.7, 1)
				end
			}
		}
	}
	
	return af
end
