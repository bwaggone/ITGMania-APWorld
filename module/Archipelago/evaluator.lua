-- evaluator.lua handles the evaluation of completed songs and the sending of location checks to the Archipelago server.

local AP = ...

if not SL then SL = {} end

local HardExWeights = {
	W010=3.5,
	W110=3,
	W2=1,
	W3=0,
	W4=0,
	W5=0,
	Miss=0,
	LetGo=0,
	Held=1,
	HitMine=-1
}

local CalculateHardExScore = function(player, ex_counts, use_actual_w0_weight)
	-- No EX scores in Casual mode, just return some dummy number early.
	if SL.Global.GameMode == "Casual" then return 0 end
	local StepsOrTrail = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)) or GAMESTATE:GetCurrentSteps(player)

	local totalSteps = StepsOrTrail:GetRadarValues(player):GetValue( "RadarCategory_TapsAndHolds" )
	local totalHolds = StepsOrTrail:GetRadarValues(player):GetValue( "RadarCategory_Holds" )
	local totalRolls = StepsOrTrail:GetRadarValues(player):GetValue( "RadarCategory_Rolls" )

	local W0Weight = use_actual_w0_weight and 3.5 or HardExWeights["W010"]
	local total_possible = totalSteps * W0Weight + (totalHolds + totalRolls) * HardExWeights["Held"]

	-- If we can't calculate HardEx score (ex_counts is passed, or sequential_offsets is missing), return 0%.
	local stageStats = SL[ToEnumShortString(player)].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1]
	local sequential_offsets = (not ex_counts) and stageStats and stageStats.sequential_offsets
	if not sequential_offsets then
		return 0, 0, total_possible
	end

	local total_points = 0

	local po = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")

	-- If mines are disabled, they should still be accounted for in EX Scoring based on the weight assigned to it.
	-- Stamina community does often play with no-mines on, but because EX scoring is more timing centric where mines
	-- generally have a negative weight, it's a better experience to make sure the EX score reflects that.
	if po:NoMines() then
		local totalMines = StepsOrTrail:GetRadarValues(player):GetValue( "RadarCategory_Mines" )
		total_points = total_points + totalMines * HardExWeights["HitMine"]
	end

	-- Calculate timing window limits dynamically for parity with theme preferences
	local scale = PREFSMAN:GetPreference("TimingWindowScale")
	local prefs = SL.Preferences["FA+"]
	local timingWindowAdd = prefs and prefs.TimingWindowAdd or 0.0015
	local itgPrefs = SL.Preferences[SL.Global.GameMode] or SL.Preferences["ITG"]

	local W010_limit = 0.0085 * scale + timingWindowAdd
	local W1_limit = (itgPrefs and itgPrefs.TimingWindowSecondsW1 or 0.0215) * scale + timingWindowAdd
	local W2_limit = (itgPrefs and itgPrefs.TimingWindowSecondsW2 or 0.0430) * scale + timingWindowAdd
	local W3_limit = (itgPrefs and itgPrefs.TimingWindowSecondsW3 or 0.1020) * scale + timingWindowAdd
	local W4_limit = (itgPrefs and itgPrefs.TimingWindowSecondsW4 or 0.1350) * scale + timingWindowAdd
	local W5_limit = (itgPrefs and itgPrefs.TimingWindowSecondsW5 or 0.1800) * scale + timingWindowAdd

	local counts = {
		W010 = 0,
		W110 = 0,
		W2 = 0,
		W3 = 0,
		W4 = 0,
		W5 = 0,
		Miss = 0
	}

	for _, entry in ipairs(sequential_offsets) do
		local offset = entry[2]
		if offset == "Miss" then
			counts["Miss"] = counts["Miss"] + 1
		elseif type(offset) == "number" then
			local abs_offset = math.abs(offset)
			if abs_offset <= W010_limit then
				counts["W010"] = counts["W010"] + 1
			elseif abs_offset <= W1_limit then
				counts["W110"] = counts["W110"] + 1
			elseif abs_offset <= W2_limit then
				counts["W2"] = counts["W2"] + 1
			elseif abs_offset <= W3_limit then
				counts["W3"] = counts["W3"] + 1
			elseif abs_offset <= W4_limit then
				counts["W4"] = counts["W4"] + 1
			elseif abs_offset <= W5_limit then
				counts["W5"] = counts["W5"] + 1
			else
				counts["Miss"] = counts["Miss"] + 1
			end
		end
	end

	-- Holds/Rolls/Mines are not in sequential_offsets, get them from game ex_counts
	local game_ex_counts = stageStats and stageStats.ex_counts
	counts["Held"] = game_ex_counts and game_ex_counts.Held or 0
	counts["LetGo"] = game_ex_counts and game_ex_counts.LetGo or 0
	counts["HitMine"] = game_ex_counts and game_ex_counts.HitMine or 0

	local keys = { "W010", "W110", "W2", "W3", "W4", "W5", "Miss", "Held", "LetGo", "HitMine" }
	for _, key in ipairs(keys) do
		local value = counts[key]
		if value ~= nil then
			total_points = total_points + value * HardExWeights[key]
		end
	end

	return math.max(0, math.floor(total_points/total_possible * 10000) / 100), total_points, total_possible
end

AP.EvaluateCompletedSong = function()
	local song = GAMESTATE:GetCurrentSong()
	if not song then return end
	
	-- Extract the folder name from the song's virtual directory path
	local songDir = song:GetSongDir()
	local parts = {}
	for part in songDir:gmatch("[^/]+") do
		table.insert(parts, part)
	end
	local folderName = parts[#parts]
	
	if not folderName then return end
	
	-- Verify if the song is part of the Archipelago run by looking up its folder name
	local chart_name = AP.folderToChartName[folderName]
	if not chart_name then
		-- Not an AP song, ignore silently
		return
	end

	if AP.IsSongLocked(song) then
		AP.Trace("Song is locked in Archipelago! Suppressing location check evaluation.")
		return
	end
	
	AP.Trace("Evaluating completed AP song: " .. chart_name)
	
	AP.LastEvaluation = {
		chart_name = chart_name,
		players = {},
		proposed_items = { money = 0, ex = 0, hex = 0 }
	}
	
	for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(pn)
		if pss then
			local is_failed = pss:GetFailed()
			if is_failed and AP.slotOptions.deathlink_enabled then
				AP.SendDeathLink()
			end
			local moneyPercent = pss:GetPercentDancePoints() * 100
			
			-- EX Percent and High EX Percent (High EX uses CalculateHardExScore)
			local exPercent = 0
			local highExPercent = 0
			if CalculateExScore then
				local success_ex, val_ex = pcall(CalculateExScore, pn)
				if success_ex then exPercent = val_ex end
			else
				AP.Trace("Archipelago warning: CalculateExScore function not found in global scope!")
			end
			
			if CalculateHardExScore then
				local success_hex, val_hex = pcall(CalculateHardExScore, pn, nil, true)
				if success_hex then highExPercent = val_hex end
			elseif CalculateExScore then
				local success_hex, val_hex = pcall(CalculateExScore, pn, nil, true)
				if success_hex then highExPercent = val_hex end
			end
			
			-- Select score percentage based on option
			local st = AP.NormalizeScoreType(AP.slotOptions.score_type)
			local activePercent = exPercent
			local score_system_name = "EX"
			if st == 0 then
				activePercent = moneyPercent
				score_system_name = "Money"
			elseif st == 2 then
				activePercent = highExPercent
				score_system_name = "High EX (FA+)"
			end
			
			local adjustedPercent = activePercent
			
			AP.Trace("Player " .. ToEnumShortString(pn) .. " Performance - " .. score_system_name .. " Score: " .. string.format("%.2f", activePercent) .. "% (Money: " .. string.format("%.2f", moneyPercent) .. "%" .. (CalculateExScore and (", EX: " .. string.format("%.2f", exPercent) .. "%") or "") .. "), Failed: " .. tostring(is_failed))
			
			-- Cache player stats for the score adjuster overlay
			AP.LastEvaluation.players[pn] = {
				is_failed = is_failed,
				moneyPercent = moneyPercent,
				exPercent = exPercent,
				highExPercent = highExPercent,
				activePercent = activePercent,
				adjustedPercent = adjustedPercent,
				score_system_name = score_system_name,
			}
		end
	end
	
	-- If the player has no available bonus items, finalize and send checks immediately.
	-- Otherwise, let them decide via the auto-popup overlay before finalizing.
	local available = AP.GetAvailableBonusItems()
	if available == 0 then
		AP.FinalizeEvaluationAndSendChecks()
	end
end

AP.FinalizeEvaluationAndSendChecks = function()
	if not AP.LastEvaluation or AP.LastEvaluation.finalized then return end
	AP.LastEvaluation.finalized = true
	
	local chart_name = AP.LastEvaluation.chart_name
	local checks_to_send = {}
	local queue_check = function(suffix)
		local loc_name = chart_name .. "-" .. suffix
		local loc_id = AP.locationIds[loc_name]
		if loc_id and not AP.checkedLocations[loc_id] then
			table.insert(checks_to_send, loc_id)
		end
	end
	
	local money_applied = 0
	local ex_applied = 0
	local hex_applied = 0
	
	if AP.LastEvaluation and AP.LastEvaluation.proposed_items then
		money_applied = AP.LastEvaluation.proposed_items.money or 0
		ex_applied = AP.LastEvaluation.proposed_items.ex or 0
		hex_applied = AP.LastEvaluation.proposed_items.hex or 0
	end
	
	for pn, pdata in pairs(AP.LastEvaluation.players) do
		local moneyPercent = pdata.moneyPercent
		local exPercent = pdata.exPercent
		local highExPercent = pdata.highExPercent
		local is_failed = pdata.is_failed
		
		-- Calculate adjusted percentages for each score type
		local adjMoney = moneyPercent + (money_applied * 0.25)
		local adjEx = exPercent + (ex_applied * 0.25)
		local adjHex = highExPercent + (hex_applied * 0.25)
		
		-- Select adjusted percentage based on active score option
		local st = AP.NormalizeScoreType(AP.slotOptions.score_type)
		local adjustedPercent = adjEx
		if st == 0 then
			adjustedPercent = adjMoney
		elseif st == 2 then
			adjustedPercent = adjHex
		end
		
		-- Check clear condition
		local fail_allowed = (AP.slotOptions.fail_allowed == true or AP.slotOptions.fail_allowed == 1)
		local passed_clear = false
		if not is_failed or fail_allowed then
			if adjustedPercent >= AP.slotOptions.passing_score then
				passed_clear = true
			end
		end
		
		if passed_clear then
			AP.Trace("Player " .. ToEnumShortString(pn) .. " CLEARED the song logic!")
			queue_check("0")
			queue_check("1")
		else
			AP.Trace("Player " .. ToEnumShortString(pn) .. " did not clear the song logic (Passing Score target: " .. tostring(AP.slotOptions.passing_score) .. "%)")
		end
		
		-- Check score thresholds (independent of the minimum pass requirement)
		if adjustedPercent >= 85 then queue_check("85") end
		if adjustedPercent >= 90 then queue_check("90") end
		if adjustedPercent >= 96 then queue_check("96") end
		if adjustedPercent >= 98 then queue_check("98") end
		if adjustedPercent >= 99 then queue_check("99") end

		-- Quad and Quint are independent of the selected score_type
		if adjMoney >= 100 then
			AP.Trace("Player " .. ToEnumShortString(pn) .. " got a QUAD money score!")
			queue_check("quad")
		end
		if adjEx >= 100 and CalculateExScore then
			AP.Trace("Player " .. ToEnumShortString(pn) .. " got a QUINT EX score!")
			queue_check("quint")
		end
	end
	
	if #checks_to_send > 0 and AP.apHandlerInstance and AP.apHandlerInstance.connected and AP.apHandlerInstance.socket then
		AP.Trace("Sending " .. tostring(#checks_to_send) .. " location checks to server...")
		local checks_packet = {
			["cmd"] = "LocationChecks",
			locations = checks_to_send
		}
		local payload = JsonEncode({ checks_packet })
		AP.apHandlerInstance.socket:Send(payload, false)
		MESSAGEMAN:Broadcast("APItemNotification", { type = "Sent", name = chart_name })
		
		-- Locally mark checks as completed immediately
		for _, loc_id in ipairs(checks_to_send) do
			AP.checkedLocations[loc_id] = true
		end
	else
		AP.Trace("No locations to check or client is not connected.")
	end

	-- Check for victory
	local is_victory = false
	if AP.slotOptions.game_mode == 1 then
		-- Boss Key mode victory: Goal Song passed
		if AP.slotOptions.goal_song then
			local goal_loc_name = AP.slotOptions.goal_song .. "-0"
			local goal_loc_id = AP.locationIds[goal_loc_name]
			if goal_loc_id and AP.checkedLocations[goal_loc_id] then
				is_victory = true
			end
		end
	else
		-- Clear Count mode victory: total clears >= win_count
		local total_clears = 0
		for name, id in pairs(AP.locationIds) do
			if name:match("%-0$") and AP.checkedLocations[id] then
				total_clears = total_clears + 1
			end
		end
		if total_clears >= (AP.slotOptions.win_count or 15) then
			is_victory = true
		end
	end

	if is_victory then
		AP.SendVictoryStatus()
	end
end
