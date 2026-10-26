-- ui/status_overlay/activity_pane.lua defines the Recent Activity & Checks pane
-- for the F10 Archipelago Status Overlay.

local AP = ...
AP.StatusPanes = AP.StatusPanes or {}

local visibleEvents = 5

AP.StatusPanes.Activity = {
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

	CanActivate = function()
		local activities = AP.RecentActivity or {}
		return #activities > 0
	end,

	BuildActors = function()
		-- Pre-generate the 5 3-line activity feed event cards
		local activity_cards = {}
		for i = 1, visibleEvents do
			activity_cards[#activity_cards+1] = Def.ActorFrame {
				Name = "Event" .. i,
				InitCommand = function(self)
					self:xy(175, -78 + (i - 1) * 50):visible(false)
				end,
				
				-- Background container quad
				Def.Quad {
					Name = "BG",
					InitCommand = function(self)
						self:zoomto(330, 48):diffuse(0.08, 0.08, 0.08, 0.68)
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
						self:x(-154):y(-14):halign(0):zoom(0.7):maxwidth(220 / 0.7)
					end
				},
				
				-- Top-right: Timestamp text
				LoadFont("Common Normal") .. {
					Name = "Time",
					Text = "",
					InitCommand = function(self)
						self:x(155):y(-14):halign(1):zoom(0.7):diffuse(0.55, 0.55, 0.55, 1)
					end
				},
				
				-- Middle line: Primary detail text
				LoadFont("Common Normal") .. {
					Name = "Detail",
					Text = "",
					InitCommand = function(self)
						self:x(-154):y(0):halign(0):zoom(0.7):maxwidth(305 / 0.7)
					end
				},
				
				-- Bottom line: Secondary context text
				LoadFont("Common Normal") .. {
					Name = "SubDetail",
					Text = "",
					InitCommand = function(self)
						self:x(-154):y(14):halign(0):zoom(0.7):diffuse(0.6, 0.6, 0.6, 1):maxwidth(305 / 0.7)
					end
				}
			}
		end

		return {
			-- Column Header (Right Pane: RECENT ACTIVITY & CHECKS)
			LoadFont("Common Normal") .. {
				Name = "RightPaneHeader",
				Text = "RECENT ACTIVITY & CHECKS",
				InitCommand = function(self)
					self:y(-120):x(15):halign(0):zoom(0.7):diffuse(0.55, 0.55, 0.55, 1):maxwidth(190 / 0.7)
				end
			},
			LoadFont("Common Normal") .. {
				Text = "SENT",
				InitCommand = function(self)
					self:y(-120):x(240):zoom(0.7):diffuse(0.2, 0.6, 1.0, 1)
				end
			},
			LoadFont("Common Normal") .. {
				Text = "RECEIVED",
				InitCommand = function(self)
					self:y(-120):x(300):zoom(0.7):diffuse(0.3, 0.9, 0.3, 1)
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
						self:x(175):y(25):zoom(0.7):diffuse(0.6, 0.6, 0.6, 1):visible(true)
					end
				},
				
				unpack(activity_cards)
			},
			-- Right Pane bottom subtext
			LoadFont("Common Normal") .. {
				Name = "ActivityNavStatus",
				Text = "Tracking last 25 multiworld events  •  Press R to Sync",
				InitCommand = function(self)
					self:x(175):y(158):zoom(0.7):diffuse(0.5, 0.5, 0.5, 1):maxwidth(330 / 0.7)
				end
			}
		}
	end,

	Update = function(connectedGroup, state, isActive)
		local right_header = connectedGroup:GetChild("RightPaneHeader")
		if right_header then
			if isActive then
				right_header:diffuse(0.3, 0.9, 0.9, 1)
			else
				right_header:diffuse(0.55, 0.55, 0.55, 1)
			end
		end

		local act_af = connectedGroup:GetChild("ActivityFeed")
		local activities = AP.RecentActivity or {}
		local has_activity = #activities > 0
		act_af:GetChild("EmptyMsg"):visible(not has_activity)
		
		local max_act_offset = math.max(1, #activities - (visibleEvents - 1))
		if state.scrollOffset > max_act_offset then
			state.scrollOffset = max_act_offset
		end
		if state.scrollOffset < 1 then
			state.scrollOffset = 1
		end
		if state.selectedIndex > #activities then
			state.selectedIndex = math.max(1, #activities)
		end
		
		for i = 1, visibleEvents do
			local card = act_af:GetChild("Event" .. i)
			local ev_idx = state.scrollOffset + i - 1
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
					if ev_idx == state.selectedIndex then
						hl:visible(true)
						if isActive then
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
			local act_start = state.scrollOffset
			local act_end = math.min(#activities, state.scrollOffset + (visibleEvents - 1))
			act_nav_text = string.format("Showing %d-%d of %d events", act_start, act_end, #activities)
		end
		local act_nav = connectedGroup:GetChild("ActivityNavStatus")
		act_nav:settext(act_nav_text)
		if isActive then
			act_nav:diffuse(0.7, 0.7, 0.7, 1)
		else
			act_nav:diffuse(0.4, 0.4, 0.4, 1)
		end
	end,

	HandleInput = function(direction, state)
		local activities = AP.RecentActivity or {}
		if direction == "Down" then
			if state.selectedIndex < #activities then
				state.selectedIndex = state.selectedIndex + 1
				if state.selectedIndex > state.scrollOffset + visibleEvents - 1 then
					state.scrollOffset = state.selectedIndex - (visibleEvents - 1)
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
