-- ui/status_overlay/main.lua defines the F10 Archipelago Status Overlay container,
-- header, modifier ribbon, and input routing across sub-panes.

local AP = ...

AP.MakeStatusOverlayActor = function()
	local status_overlay_actor = nil
	local activePane = 1 -- 1 = Songs (left), 2 = Recent Activity (right)
	local overlay_visible = false
	
	local paneWidth = 720
	local paneHeight = 440

	local songsPane = AP.StatusPanes.Songs
	local activityPane = AP.StatusPanes.Activity
	local songsState = songsPane.CreateState()
	local activityState = activityPane.CreateState()

	-- Helper to update all visible UI components in the overlay
	local function updateOverlayUI(self)
		local backdrop = self:GetChild("Backdrop")
		local container = self:GetChild("Container")
		
		backdrop:visible(overlay_visible)
		container:visible(overlay_visible)
		
		if not overlay_visible then return end
		
		local bg_logo = container:GetChild("BackgroundLogo")
		if bg_logo then
			local logo_path, logo_color = AP.GetLogoAssetAndColor(false)
			bg_logo:Load(logo_path)
			bg_logo:zoomtoheight(280):zoomx(bg_logo:GetZoomY())
			bg_logo:diffuse(logo_color):diffusealpha(0.14)
		end
		
		local apHandler = AP.GetAPHandlerInstance()
		if not apHandler or not apHandler.connected then
			container:GetChild("ConnectedGroup"):visible(false)
			container:GetChild("OfflineMsg"):visible(true)
			return
		end
		
		local connectedGroup = container:GetChild("ConnectedGroup")
		connectedGroup:visible(true)
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
		connectedGroup:GetChild("RoomSeedText"):settext(room_str .. "  |  " .. seed_str .. mode_str)
		
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
		
		connectedGroup:GetChild("ProgressText"):settext(progress_text)
		
		-- Update top-right progress bar fill
		local bar_fg = connectedGroup:GetChild("ProgressBarFG")
		bar_fg:zoomto(192 * progress_pct, 6)
		
		-- Update modifier ribbon stats
		local mod_text = ""
		if AP.IsEnforcingMods() then
			local max_bpm, max_filter, mini, bonus_count = AP.GetModifierStats()
			mod_text = string.format("Max Speed: %s  |  BG Filter: %s  |  Mini: %s", max_bpm, max_filter, mini)
		else
			mod_text = "Standard Modifiers"
		end
		connectedGroup:GetChild("ModifierText"):settext(mod_text)
		
		local sync_str = "Score Boosters: " .. tostring(AP.GetAvailableBonusItems()) .. " Available  |  Sync: Connected"
		connectedGroup:GetChild("BoostersSyncText"):settext(sync_str)
		
		-- Delegate updates to sub-panes
		songsPane.Update(connectedGroup, songsState, activePane == 1)
		activityPane.Update(connectedGroup, activityState, activePane == 2)
	end

	-- Toggle overlay active state, routing player input and registering the input listener
	local function toggleOverlay(self)
		overlay_visible = not overlay_visible
		activePane = 1
		songsPane.ResetState(songsState)
		activityPane.ResetState(activityState)
		
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

	-- Build ConnectedGroup children including shared header/ribbon and sub-pane actors
	local connected_children = {
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
		
		-- Vertical divider line between left and right panes
		Def.Quad {
			InitCommand = function(self)
				self:x(-2):y(30):zoomto(1.5, 290):diffuse(0.2, 0.2, 0.2, 1)
			end
		}
	}

	for _, actor in ipairs(songsPane.BuildActors()) do
		connected_children[#connected_children + 1] = actor
	end
	for _, actor in ipairs(activityPane.BuildActors()) do
		connected_children[#connected_children + 1] = actor
	end

	local af = Def.ActorFrame {
		Name = "APStatusOverlayMain",
		InitCommand = function(self)
			status_overlay_actor = self
			self.statusOverlayInputHandler = nil
			self.armed = false
			overlay_visible = false
			songsPane.ResetState(songsState)
			activityPane.ResetState(activityState)
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

				if game_btn == "MenuRight" or key == "DeviceButton_right" or event.button == "MenuRight" or event.button == "Right" then
					-- Switch to Right Pane (Recent Activity)
					if activePane ~= 2 and activityPane.CanActivate() then
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
						songsPane.HandleInput("Down", songsState)
					else
						activityPane.HandleInput("Down", activityState)
					end
					return true
				elseif game_btn == "MenuUp" or key == "DeviceButton_up" or event.button == "MenuUp" or event.button == "Up" then
					if activePane == 1 then
						songsPane.HandleInput("Up", songsState)
					else
						activityPane.HandleInput("Up", activityState)
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
			
			-- Background Archipelago Logo watermark
			Def.Sprite {
				Name = "BackgroundLogo",
				InitCommand = function(self)
					local logo_path, logo_color = AP.GetLogoAssetAndColor(false)
					self:Load(logo_path)
					self:xy(0, 18)
					self:zoomtoheight(280):zoomx(self:GetZoomY())
					self:diffuse(logo_color):diffusealpha(0.14)
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
			
			-- Container for all statistics and panes shown when connected
			Def.ActorFrame(connected_children)
		}
	}
	
	return af
end
