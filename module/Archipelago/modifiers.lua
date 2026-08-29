-- modifiers.lua manages active gameplay modifier limit checks and clamps,
-- such as speed limit, background filter, and mini settings. This is optional
-- and can be disabled via the "enable_mod_items" slot option.

local AP = ...

AP.ClampedWarnings = {}

-- Helper to get stats on unlocked Archipelago modifiers.
-- Traverses received items to determine:
-- 1. Highest BPM speed limit modifier item (e.g. "Speed 550bpm")
-- 2. Darkest background filter modifier item (e.g. "Darker Filter")
-- 3. Number of "Score Booster" items received
AP.GetModifierStats = function()
	local max_bpm = "Default (250)"
	local max_filter = "None"
	local mini = "Default (100%)"
	local bonus_count = 0

	local speed_items = {
		["Speed 350bpm"] = 350,
		["Speed 450bpm"] = 450,
		["Speed 550bpm"] = 550,
		["Speed 650bpm"] = 650,
		["Speed 750bpm"] = 750,
		["Speed Any BPM"] = 9999,
	}

	local mini_items = {
		["90% Mini"] = 90,
		["70% Mini"] = 70,
		["50% Mini"] = 50,
		["Any Mini"] = 0,
	}

	local filter_items = {
		["Dark Filter"] = 1,
		["Darker Filter"] = 2,
		["Darkest Filter"] = 3,
	}

	local highest_speed_val = 0
	local highest_filter_val = 0
	local lowest_mini_val = 100

	if AP.AP_AllReceivedItems then
		for _, item in ipairs(AP.AP_AllReceivedItems) do
			local name = AP.itemNames[item.item]
			if name then
				if name == "Score Booster" then
					bonus_count = bonus_count + 1
				elseif speed_items[name] then
					if speed_items[name] > highest_speed_val then
						highest_speed_val = speed_items[name]
						if name == "Speed Any BPM" then
							max_bpm = "Unlimited"
						else
							max_bpm = name:gsub("Speed ", ""):upper()
						end
					end
				elseif filter_items[name] then
					if filter_items[name] > highest_filter_val then
						highest_filter_val = filter_items[name]
						max_filter = name:gsub(" Filter", "")
					end
				elseif mini_items[name] then
					if mini_items[name] < lowest_mini_val then
						lowest_mini_val = mini_items[name]
						mini = name:gsub(" Mini", "")
					end
				end
			end
		end
	end

	return max_bpm, max_filter, mini, bonus_count
end

AP.IsEnforcingMods = function()
	return AP.apHandlerInstance and AP.apHandlerInstance.connected and AP.slotOptions and AP.slotOptions.enable_mod_items
end

AP.GetMaxAllowedMini = function()
	if not AP.IsEnforcingMods() then
		return 100
	end
	local lowest_mini_val = 100
	if AP.AP_AllReceivedItems then
		for _, item in ipairs(AP.AP_AllReceivedItems) do
			local name = AP.itemNames[item.item]
			if name then
				if name == "90% Mini" then
					if 90 < lowest_mini_val then lowest_mini_val = 90 end
				elseif name == "70% Mini" then
					if 70 < lowest_mini_val then lowest_mini_val = 70 end
				elseif name == "50% Mini" then
					if 50 < lowest_mini_val then lowest_mini_val = 50 end
				elseif name == "Any Mini" then
					lowest_mini_val = 0
				end
			end
		end
	end
	if lowest_mini_val == 100 then return 0
	elseif lowest_mini_val == 90 then return 10
	elseif lowest_mini_val == 70 then return 30
	elseif lowest_mini_val == 50 then return 50
	else return 100
	end
end

AP.ClampSpeedMod = function(pn)
	if not AP.IsEnforcingMods() then return end
	
	local max_bpm_str, _, _, _ = AP.GetModifierStats()
	local max_bpm_limit = 250
	if max_bpm_str == "Unlimited" then
		return -- No limit
	elseif max_bpm_str:match("^%d+") then
		max_bpm_limit = tonumber(max_bpm_str:match("^%d+")) or 250
	end
	
	local pName = ToEnumShortString(pn)
	local mods = SL[pName].ActiveModifiers
	if not mods or not mods.SpeedMod then return end
	
	local speed = mods.SpeedMod
	local speed_type = mods.SpeedModType or "X"
	
	if speed_type == "C" or speed_type == "M" then
		if speed > max_bpm_limit then
			mods.SpeedMod = max_bpm_limit
			local playerState = GAMESTATE:GetPlayerState(pn)
			if playerState then
				for _, level in ipairs({"ModsLevel_Preferred", "ModsLevel_Song"}) do
					local playeroptions = playerState:GetPlayerOptions(level)
					if playeroptions then
						playeroptions[speed_type.."Mod"](playeroptions, max_bpm_limit)
					end
				end
			end
			GAMESTATE:ApplyGameCommand("mod," .. speed_type:lower() .. tostring(max_bpm_limit), pn)
			table.insert(AP.ClampedWarnings, "Speed capped to " .. speed_type .. tostring(max_bpm_limit) .. " (Limit: " .. tostring(max_bpm_limit) .. " BPM)")
		end
	elseif speed_type == "X" then
		local bpms = GetDisplayBPMs(pn)
		if bpms and bpms[2] and bpms[2] > 0 then
			local max_chart_bpm = bpms[2]
			local rate = SL.Global.ActiveModifiers.MusicRate or 1.0
			local current_scroll_bpm = speed * max_chart_bpm * rate
			if current_scroll_bpm > max_bpm_limit then
				local max_mult = max_bpm_limit / (max_chart_bpm * rate)
				max_mult = math.floor(max_mult / 0.05) * 0.05
				if max_mult < 0.05 then max_mult = 0.05 end
				
				mods.SpeedMod = max_mult
				local playerState = GAMESTATE:GetPlayerState(pn)
				if playerState then
					for _, level in ipairs({"ModsLevel_Preferred", "ModsLevel_Song"}) do
						local playeroptions = playerState:GetPlayerOptions(level)
						if playeroptions then
							playeroptions:XMod(max_mult)
						end
					end
				end
				GAMESTATE:ApplyGameCommand("mod," .. string.format("%.2f", max_mult) .. "x", pn)
				table.insert(AP.ClampedWarnings, ("Speed capped to %.2fx (Limit: %d BPM)"):format(max_mult, max_bpm_limit))
			end
		end
	end
end

AP.ClampBackgroundFilter = function(pn)
	if not AP.IsEnforcingMods() then return end
	
	local _, max_filter, _, _ = AP.GetModifierStats()
	local pName = ToEnumShortString(pn)
	local mods = SL[pName].ActiveModifiers
	if not mods or not mods.BackgroundFilter then return end
	
	local filter_val = { Off = 0, Dark = 1, Darker = 2, Darkest = 3 }
	local limit_val = filter_val[max_filter] or 0
	local current_val = filter_val[mods.BackgroundFilter] or 0
	if current_val > limit_val then
		local reverse_val = { [0] = "Off", [1] = "Dark", [2] = "Darker", [3] = "Darkest" }
		local clamped_name = reverse_val[limit_val] or "Off"
		mods.BackgroundFilter = clamped_name
		table.insert(AP.ClampedWarnings, "BG Filter capped to " .. clamped_name)
	end
end

AP.ClampMini = function(pn)
	if not AP.IsEnforcingMods() then return end
	
	local max_allowed = AP.GetMaxAllowedMini()
	local pName = ToEnumShortString(pn)
	local mods = SL[pName].ActiveModifiers
	if not mods or not mods.Mini then return end
	
	local current_val = tonumber((tostring(mods.Mini):gsub("%%", ""))) or 0
	if current_val > max_allowed then
		mods.Mini = tostring(max_allowed) .. "%"
		local playerState = GAMESTATE:GetPlayerState(pn)
		if playerState then
			for _, level in ipairs({"ModsLevel_Preferred", "ModsLevel_Song"}) do
				local playeroptions = playerState:GetPlayerOptions(level)
				if playeroptions then
					playeroptions:Mini(max_allowed / 100)
				end
			end
		end
		GAMESTATE:ApplyGameCommand("mod," .. tostring(max_allowed) .. "% mini", pn)
		table.insert(AP.ClampedWarnings, "Mini limited to " .. tostring(max_allowed) .. "%")
	end
end
