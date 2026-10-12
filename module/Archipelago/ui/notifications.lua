-- ui/notifications.lua provides the sliding toast notification popups
-- for received items, sent checks, and connection status changes.

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
