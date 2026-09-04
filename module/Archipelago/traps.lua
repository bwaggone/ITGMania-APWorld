-- traps.lua handles the application and clearing of trap items during gameplay.

local AP = ...

AP.cachedHalfSpeedTarget = AP.cachedHalfSpeedTarget or {}
AP.cachedMiniTarget = AP.cachedMiniTarget or {}
AP.debugAnnouncedThisSong = AP.debugAnnouncedThisSong or {}
AP.currentSongTrap = AP.currentSongTrap or nil
AP.trapWasAppliedThisSong = AP.trapWasAppliedThisSong or false

local TRAP_APPLIERS = {
	["Trap - Reverse Scroll"] = function(pOptions) pOptions:Reverse(1, 100); return 1, "Reverse" end,
	["Trap - Mini"] = function(pOptions, pn)
		if AP.cachedMiniTarget[pn] == nil then
			local magnitude = math.random(20, 50) / 100
			local sign = math.random(0, 1) == 0 and -1 or 1
			AP.cachedMiniTarget[pn] = magnitude * sign
		end
		local pct = AP.cachedMiniTarget[pn]
		pOptions:Mini(pct, 100)
		return pct, "Mini"
		end,
	["Trap - Dark"] = function(pOptions) pOptions:Dark(0.95, 100); return 0.95, "Dark" end,
	["Trap - Half Speed"] = function(pOptions, pn)
		if AP.cachedHalfSpeedTarget[pn] == nil then
			local usingCMod = pOptions:TimeSpacing() and pOptions:TimeSpacing() > 0
			if usingCMod then
				local previous = pOptions:ScrollBPM()
				AP.cachedHalfSpeedTarget[pn] = { method = "ScrollBPM", target = (previous or 200) * 0.5 }
			else
				local previous = pOptions:ScrollSpeed()
				AP.cachedHalfSpeedTarget[pn] = { method = "ScrollSpeed", target = (previous or 1) * 0.5 }
			end
		end
		local cached = AP.cachedHalfSpeedTarget[pn]
		pOptions[cached.method](pOptions, cached.target, 100)
		return cached.target, cached.method
	end,
}

AP.ApplyTrapToken = function(pn, trapName, useCurrentAccessor)
	local applier = TRAP_APPLIERS[trapName]
	if applier == nil then return false end
	local pState = GAMESTATE:GetPlayerState(pn)
	if not pState then return false end
	local pOptions = useCurrentAccessor and pState:GetCurrentPlayerOptions() or pState:GetPlayerOptions("ModsLevel_Song")
	if not pOptions then return false end
	local appliedValue, appliedMethod = applier(pOptions, pn)
	return true, appliedValue, appliedMethod
end

AP.ApplyArmedTrapsNow = function()
	local nextTrap = AP.armedTrapQueue[1]
	if nextTrap ~= nil then
		AP.currentSongTrap = nextTrap
		AP.trapWasAppliedThisSong = true
		for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
			local ok, appliedValue, appliedMethod = AP.ApplyTrapToken(pn, nextTrap, false) -- false = ModsLevel_Song
			if ok and not AP.debugAnnouncedThisSong[pn] then
				local readback = "?"
				pcall(function()
					local pOptions = GAMESTATE:GetPlayerState(pn):GetPlayerOptions("ModsLevel_Song")
					readback = tostring(pOptions[appliedMethod](pOptions))
				end)
				AP.Trace("[AP TRAP] " .. nextTrap .. " -> " .. tostring(appliedValue)
					.. " (" .. appliedMethod .. ") | readback: " .. readback)
				AP.debugAnnouncedThisSong[pn] = true
			end
		end
	else
		AP.currentSongTrap = nil
		AP.trapWasAppliedThisSong = false
		AP.ResetAllTrapPlayerOptions()
	end
end

AP.ResetTrapPlayerOptions = function(pn)
	local pState = GAMESTATE:GetPlayerState(pn)
	if not pState then return end

	-- 1. Use engine's native method to reset all mods levels to ModsLevel_Preferred
	if pState.ApplyPreferredOptionsToOtherLevels then
		pcall(function() pState:ApplyPreferredOptionsToOtherLevels() end)
	end

	-- 2. Explicitly ensure trap-specific modifiers are reset on ModsLevel_Song and ModsLevel_Current
	local prefPO = pState:GetPlayerOptions("ModsLevel_Preferred")
	for _, level in ipairs({ "ModsLevel_Song", "ModsLevel_Current" }) do
		pcall(function()
			local po = pState:GetPlayerOptions(level)
			if po then
				local prefReverse = prefPO and prefPO:Reverse() or 0
				local prefMini = prefPO and prefPO:Mini() or 0
				local prefDark = prefPO and prefPO:Dark() or 0
				po:Reverse(prefReverse, 100)
				po:Mini(prefMini, 100)
				po:Dark(prefDark, 100)

				if prefPO then
					local usingCMod = prefPO:TimeSpacing() and prefPO:TimeSpacing() > 0
					if usingCMod then
						local prefBPM = prefPO:ScrollBPM()
						if prefBPM and prefBPM > 0 then
							po:ScrollBPM(prefBPM, 100)
						end
					else
						local prefSpeed = prefPO:ScrollSpeed()
						if prefSpeed and prefSpeed > 0 then
							po:ScrollSpeed(prefSpeed, 100)
						end
					end
				end
			end
		end)
	end

	-- 3. Re-apply Simply Love's active modifiers speed if Simply Love is running
	pcall(function()
		local pName = ToEnumShortString(pn)
		if SL and SL[pName] and SL[pName].ActiveModifiers and SL[pName].ActiveModifiers.SpeedMod then
			local mods = SL[pName].ActiveModifiers
			local fmt = {
				X = "mod,%.2fx",
				C = "mod,c%d",
				M = "mod,m%d"
			}
			local speed_type = mods.SpeedModType or "X"
			if fmt[speed_type] then
				local gcString = fmt[speed_type]:format(mods.SpeedMod)
				GAMESTATE:ApplyGameCommand(gcString, pn)
			end
		end
	end)
end

AP.ResetAllTrapPlayerOptions = function()
	for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
		AP.ResetTrapPlayerOptions(pn)
	end
end

AP.ConsumeCurrentTrap = function()
	AP.cachedHalfSpeedTarget = {}
	AP.cachedMiniTarget = {}
	AP.debugAnnouncedThisSong = {}
	if AP.currentSongTrap ~= nil then
		for i, trapName in ipairs(AP.armedTrapQueue) do
			if trapName == AP.currentSongTrap then
				table.remove(AP.armedTrapQueue, i)
				break
			end
		end
		AP.currentSongTrap = nil
	elseif #AP.armedTrapQueue > 0 and AP.trapWasAppliedThisSong then
		table.remove(AP.armedTrapQueue, 1)
	end
	AP.trapWasAppliedThisSong = false
	AP.ResetAllTrapPlayerOptions()
end
