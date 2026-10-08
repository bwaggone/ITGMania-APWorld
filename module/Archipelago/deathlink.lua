-- deathlink.lua handles deathlink functionality.

local AP = ...

local function getTimestamp()
	if type(GetUnixTime) == "function" then
		local ok, t = pcall(GetUnixTime)
		if ok and type(t) == "number" and t > 0 then
			return t
		end
	end
	if AP.GetTimestamp then
		return AP.GetTimestamp()
	end
	return 0
end

AP.SendDeathLink = function()
	if not AP.slotOptions.deathlink_enabled then return end
	if AP.ignoreNextDeathReport then
		AP.ignoreNextDeathReport = false
		AP.Trace("Ignored sending DeathLink because the death was caused by an incoming DeathLink.")
		return
	end

	AP.Trace("Sending DeathLink to server...")
	local bounce_packet = {
		["cmd"] = "Bounce",
		tags = { "DeathLink" },
		data = {
			time = getTimestamp(),
			source = AP.SLOT,
			cause = AP.SLOT .. " failed a song."
		}
	}
	if AP.apHandlerInstance and AP.apHandlerInstance.connected and AP.apHandlerInstance.socket then
	AP.apHandlerInstance.socket:Send(JsonEncode({ bounce_packet }), false)
	AP.Trace("DeathLink Bounce packet sent.")
else
	AP.Trace("DeathLink NOT sent - apHandlerInstance=" .. tostring(AP.apHandlerInstance ~= nil)
		.. ", connected=" .. tostring(AP.apHandlerInstance and AP.apHandlerInstance.connected)
		.. ", socket=" .. tostring(AP.apHandlerInstance and AP.apHandlerInstance.socket ~= nil))
end

end

AP.TriggerDeathLinkFailure = function()
	AP.ignoreNextDeathReport = true
	GAMESTATE:SetSongOptions("ModsLevel_Song", "failimmediate")
	for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
		local topScreen = SCREENMAN:GetTopScreen()
		if topScreen then
			local suffix = (pn == PLAYER_1) and "P1" or "P2"
			local playerActor = topScreen:GetChild("Player" .. suffix)
			if playerActor then
				playerActor:SetLife(0.0)
				AP.Trace("DeathLink failure applied to player " .. suffix)
			end
		end
	end
end
