-- ui/status_overlay/songs_pane.lua defines the Unlocked Songs & In-Line Checks pane
-- for the F10 Archipelago Status Overlay.

local AP = ...
AP.StatusPanes = AP.StatusPanes or {}

local visibleSongs = 5
local suffixes = { "0", "1", "85", "90", "96", "98", "99", "quad", "quint" }
local short_labels = { "C1", "C2", "85", "90", "96", "98", "99", "Qd", "Qt" }

AP.StatusPanes.Songs = {
	CreateState = function()
		return {
			scrollOffset = 1,
			selectedIndex = 1
		}
	end,

	ResetState = function(state)
		state.scrollOffset = 1
		state.selectedIndex = 1
	end,

	BuildActors = function()
		-- Pre-generate the 5 2-line song list row actors
		local song_list_children = {}
		for i = 1, visibleSongs do
			local row_children = {
				Name = "Row" .. i,
				InitCommand = function(self)
					self:xy(-175, -78 + (i - 1) * 50)
				end,
				
				-- Base row background quad
				Def.Quad {
					Name = "RowBG",
					InitCommand = function(self)
						self:zoomto(330, 48):diffuse(0.08, 0.08, 0.08, 0.68)
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

		return {
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
			}
		}
	end,

	Update = function(connectedGroup, state, isActive)
		local left_header = connectedGroup:GetChild("LeftPaneHeader")
		if left_header then
			if isActive then
				left_header:diffuse(0.3, 0.9, 0.9, 1)
			else
				left_header:diffuse(0.55, 0.55, 0.55, 1)
			end
		end

		-- Update scrollable songs list rows with in-line checks
		local songs = AP.GetUnlockedSongs()
		local list_af = connectedGroup:GetChild("SongList")
		
		for i = 1, visibleSongs do
			local row = list_af:GetChild("Row" .. i)
			local idx = state.scrollOffset + i - 1
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
				if idx == state.selectedIndex then
					row:GetChild("Highlight"):visible(true)
					if isActive then
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
		local nav_text = string.format("Showing %d-%d of %d songs", math.min(#songs, state.scrollOffset), math.min(#songs, state.scrollOffset + visibleSongs - 1), #songs)
		local song_nav = connectedGroup:GetChild("SongNavStatus")
		song_nav:settext(nav_text)
		if isActive then
			song_nav:diffuse(0.7, 0.7, 0.7, 1)
		else
			song_nav:diffuse(0.4, 0.4, 0.4, 1)
		end
	end,

	HandleInput = function(direction, state)
		local songs = AP.GetUnlockedSongs()
		local num_songs = #songs
		if direction == "Down" then
			if state.selectedIndex < num_songs then
				state.selectedIndex = state.selectedIndex + 1
				if state.selectedIndex > state.scrollOffset + visibleSongs - 1 then
					state.scrollOffset = state.selectedIndex - (visibleSongs - 1)
				end
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
				MESSAGEMAN:Broadcast("APStatusRefresh")
			end
			return true
		elseif direction == "Up" then
			if state.selectedIndex > 1 then
				state.selectedIndex = state.selectedIndex - 1
				if state.selectedIndex < state.scrollOffset then
					state.scrollOffset = state.selectedIndex
				end
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
				MESSAGEMAN:Broadcast("APStatusRefresh")
			end
			return true
		end
		return false
	end
}
