-- traps.lua handles the application of trap items to player options during gameplay.

local AP = ...

AP.cachedHalfSpeedTarget = AP.cachedHalfSpeedTarget or {}
AP.debugAnnouncedThisSong = AP.debugAnnouncedThisSong or {}

local TRAP_APPLIERS = {
	["Trap - Reverse Scroll"] = function(pOptions) pOptions:Reverse(1, 100); return 1, "Reverse" end,
	["Trap - Mini"] = function(pOptions) pOptions:Mini(0.5, 100); return 0.5, "Mini" end,
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
	end
end
