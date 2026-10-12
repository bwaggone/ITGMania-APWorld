-- ui/eval_overlay.lua provides the Archipelago Score Adjuster overlay
-- displayed on ScreenEvaluation for spending consumable Score Boosters.

local AP = ...

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
		
		local bg_logo = container:GetChild("BackgroundLogo")
		if bg_logo then
			local logo_path, logo_color = AP.GetLogoAssetAndColor(false)
			bg_logo:Load(logo_path)
			bg_logo:zoomtoheight(220):zoomx(bg_logo:GetZoomY())
			bg_logo:diffuse(logo_color):diffusealpha(0.14)
		end
		
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
			
			-- Background Archipelago Logo watermark
			Def.Sprite {
				Name = "BackgroundLogo",
				InitCommand = function(self)
					local logo_path, logo_color = AP.GetLogoAssetAndColor(false)
					self:Load(logo_path)
					self:xy(0, 8)
					self:zoomtoheight(220):zoomx(self:GetZoomY())
					self:diffuse(logo_color):diffusealpha(0.14)
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
