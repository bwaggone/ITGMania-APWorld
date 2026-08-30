-- actor_handler.lua defines theme actors and screen hooks,
-- delegating connection logic to network.lua.

local AP = ...

AP.MakeScreenActor = function(screenName)
	local af = Def.ActorFrame {}
	
	-- Only add standard popup notifications if it's NOT gameplay to avoid distractions during play
	if screenName ~= "ScreenGameplay" then
		af[#af+1] = AP.MakePopupActor(screenName)
	end

	if screenName == "ScreenSelectMusic" then
		af[#af+1] = Def.Actor {
			ModuleCommand = function(self)
				AP.ClampedWarnings = {} -- Reset warnings on music wheel
				pcall(AP.ConsumeCurrentTrap)
				pcall(AP.ResetAllTrapPlayerOptions)
				local apHandler = AP.GetAPHandlerInstance()
				if not AP.hasDefaultedToSortOrderPreferred and apHandler and apHandler.connected and AP.seedName and AP.seedName ~= "Unknown" and SONGMAN:GetPreferredSortSongs() then
					local top = SCREENMAN:GetTopScreen()
					if top and top:GetName() == "ScreenSelectMusic" then
						local wheel = top:GetMusicWheel()
						if wheel then
							wheel:ChangeSort("SortOrder_Preferred")
							AP.hasDefaultedToSortOrderPreferred = true
						end
					end
				end
				self:playcommand("InstallSortMenuHook")
			end,
			InstallSortMenuHookCommand = function(self)
				local top = SCREENMAN:GetTopScreen()
				if not top or top:GetName() ~= "ScreenSelectMusic" then return end

				local overlay = top:GetChild("Overlay")
				local sortmenu = overlay and overlay:GetChild("SortMenu") or nil
				if not sortmenu then
					self:sleep(0.15):queuecommand("InstallSortMenuHook")
					return
				end

				if sortmenu.custom_functions == nil then
					sortmenu.custom_functions = {}
				end

				if not sortmenu.custom_functions["AP Status"] then
					sortmenu.custom_functions["AP Status"] = function(event)
						local screen = SCREENMAN:GetTopScreen()
						if not screen or screen:GetName() ~= "ScreenSelectMusic" then return end
						local ov = screen:GetChild("Overlay")
						if ov then
							ov:queuecommand("DirectInputToEngine")
						end
						MESSAGEMAN:Broadcast("APToggleStatusOverlay")
					end
				end

				if not sortmenu.custom_functions["AP Config Tool"] then
					sortmenu.custom_functions["AP Config Tool"] = function(event)
						local screen = SCREENMAN:GetTopScreen()
						if not screen or screen:GetName() ~= "ScreenSelectMusic" then return end
						local ov = screen:GetChild("Overlay")
						if ov then
							ov:queuecommand("DirectInputToEngine")
						end
						MESSAGEMAN:Broadcast("APToggleConfigOverlay")
					end
				end

				if sortmenu.wheel_options then
					local statusIndex = nil
					local configIndex = nil
					local insertAfterIndex = nil

					for i = 1, #sortmenu.wheel_options do
						local option = sortmenu.wheel_options[i]
						if option and option[1] and option[1][1] == "Archipelago" then
							if option[1][2] == "AP Status" then
								statusIndex = i
							elseif option[1][2] == "AP Config Tool" then
								configIndex = i
							end
						elseif option and option[1] and option[1][1] == "ArrowCloud" and option[1][2] == "ACLeaderboard" then
							insertAfterIndex = i
						elseif insertAfterIndex == nil and option and option[1] and option[1][1] == "NextPlease" and option[1][2] == "SwitchProfile" then
							insertAfterIndex = i
						end
					end

					local statusOption = statusIndex and sortmenu.wheel_options[statusIndex]
						or { { "Archipelago", "AP Status" }, function() return true end }
					local configOption = configIndex and sortmenu.wheel_options[configIndex]
						or { { "Archipelago", "AP Config Tool" }, function() return true end }

					local to_remove = {}
					if statusIndex then table.insert(to_remove, statusIndex) end
					if configIndex then table.insert(to_remove, configIndex) end
					table.sort(to_remove, function(a,b) return a > b end)
					for _, idx in ipairs(to_remove) do
						table.remove(sortmenu.wheel_options, idx)
						if insertAfterIndex and idx < insertAfterIndex then
							insertAfterIndex = insertAfterIndex - 1
						end
					end

					if insertAfterIndex ~= nil then
						table.insert(sortmenu.wheel_options, insertAfterIndex + 1, configOption)
						table.insert(sortmenu.wheel_options, insertAfterIndex + 1, statusOption)
					else
						table.insert(sortmenu.wheel_options, statusOption)
						table.insert(sortmenu.wheel_options, configOption)
					end
				end
			end
		}
		
		-- Small helper text in the footer: "Press F10 for AP Status"
		af[#af+1] = LoadFont("Common Normal") .. {
			Name = "APStatusHelperText",
			Text = "Press F10 for AP Status",
			InitCommand = function(self)
				self:xy(_screen.cx + SL_WideScale(138, 191), _screen.h - 9)
				self:zoom(SL_WideScale(0.8, 0.9))
				self:diffusealpha(0)
				self:halign(0.5):valign(1)
			end,
			ModuleCommand = function(self)
				self:stoptweening()
				self:diffusealpha(0):sleep(0.1):decelerate(0.33):diffusealpha(1)
			end
		}
		
		af[#af+1] = AP.MakeStatusOverlayActor()
		af[#af+1] = AP.MakeConfigOverlayActor()
	end
	if screenName:find("ScreenEvaluation") then
		af[#af+1] = Def.Actor {
			ModuleCommand = function(self)
				-- Consume trap and reset states
				pcall(AP.ConsumeCurrentTrap)
				pcall(AP.ResetAllTrapPlayerOptions)
				AP.deathlinkArmed = false
				AP.ignoreNextDeathReport = false

				AP.EvaluateCompletedSong()
			end
		}
		af[#af+1] = AP.MakeEvaluationOverlayActor()
	end


	if screenName == "ScreenGameplay" then
		-- Custom pop-up warning for clamped modifiers on song start
		af[#af+1] = Def.ActorFrame {
			Name = "APGameplayWarningFrame",
			InitCommand = function(self)
				self:xy(_screen.cx, _screen.cy - 120)
				self:diffusealpha(0)
			end,
			ModuleCommand = function(self)
				if AP.ClampedWarnings and #AP.ClampedWarnings > 0 then
					self:playcommand("ShowWarning")
				end
			end,
			ShowWarningCommand = function(self)
				local warning_text = table.concat(AP.ClampedWarnings, "\n")
				local subtext = self:GetChild("Subtext")
				if subtext then
					subtext:settext(warning_text)
				end
				
				-- slide/fade in, hold for 3.5 seconds, fade out
				self:finishtweening()
				self:diffusealpha(0):y(_screen.cy - 140)
				self:decelerate(0.4):diffusealpha(1):y(_screen.cy - 120)
				self:sleep(3.5)
				self:accelerate(0.4):diffusealpha(0):y(_screen.cy - 100)
			end,
			
			-- Background box
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(500, 80)
					self:diffuse(0.05, 0.05, 0.05, 0.85)
				end
			},
			-- Accent outline / border with a yellow color
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(4, 80):x(-250)
					self:diffuse(0.9, 0.8, 0.1, 1) -- yellow warning accent
				end
			},
			-- Warning Title
			LoadFont("Common Bold") .. {
				Text = "ARCHIPELAGO MODIFIERS CLAMPED",
				InitCommand = function(self)
					self:y(-22):zoom(0.65)
					self:diffuse(0.9, 0.8, 0.1, 1) -- yellow warning title
				end
			},
			-- Clamped details subtext
			LoadFont("Common Normal") .. {
				Name = "Subtext",
				Text = "",
				InitCommand = function(self)
					self:y(12):zoom(0.65)
					self:diffuse(0.9, 0.9, 0.9, 1)
				end
			}
		}
		
		-- Hook PlayerOptionsChanged to enforce clamped speed if changed mid-song before first note
		af[#af+1] = Def.Actor {
			PlayerOptionsChangedMessageCommand = function(self, params)
				-- guard from recursion when we re-broadcast our clamp below
				if params and params.Clamped then return end
				if params and params.Player then
					local pn = params.Player
					AP.ClampedWarnings = {}
					AP.ClampSpeedMod(pn)
					if #AP.ClampedWarnings > 0 then
						-- Format and apply new clamped speed immediately to the engine
						local pName = ToEnumShortString(pn)
						local mods = SL[pName].ActiveModifiers
						local fmt = {
							X = "mod,%.2fx",
							C = "mod,c%d",
							M = "mod,m%d"
						}
						local speed_type = mods.SpeedModType or "X"
						local gcString = fmt[speed_type]:format(mods.SpeedMod)
						GAMESTATE:ApplyGameCommand(gcString, pn)
						
						-- Re-broadcast option change so displays update, but guard from recursion
						MESSAGEMAN:Broadcast("PlayerOptionsChanged", {Player=pn, Clamped=true})
					end
				end
			end
		}

		af[#af+1] = Def.Actor {
			ModuleCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if song and AP.IsSongLocked(song) then
					local songDir = song:GetSongDir()
					local parts = {}
					for part in songDir:gmatch("[^/]+") do table.insert(parts, part) end
					local folderName = parts[#parts]
					local chart_name = AP.folderToChartName[folderName]
					if chart_name == AP.slotOptions.goal_song then
						SCREENMAN:SystemMessage("Warning: Goal Song is locked! Clears will not count until you have all Boss Keys.")
					else
						SCREENMAN:SystemMessage("Warning: Song is locked! Clears will not count until unlocked in Archipelago.")
					end
				end
				pcall(AP.ApplyArmedTrapsNow)
				self:playcommand("APGameplayDeathLinkPoll")
			end,
			OffCommand = function(self)
				pcall(AP.ConsumeCurrentTrap)
				pcall(AP.ResetAllTrapPlayerOptions)
			end,
			APGameplayDeathLinkPollCommand = function(self)
				if AP.deathlinkArmed then
					AP.deathlinkArmed = false
					pcall(AP.TriggerDeathLinkFailure)
				end
				local topScreen = SCREENMAN:GetTopScreen()
				if topScreen and topScreen:GetName() == "ScreenGameplay" then
					self:sleep(5.0):queuecommand("APGameplayDeathLinkPoll")
				end
			end
		}
	end
	
	return af
end
