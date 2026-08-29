-- deathlink.lua handles deathlink functionality.

local AP = ...

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
			time = os.time(),
			source = AP.SLOT,
			cause = AP.SLOT .. " failed a song."
		}
	}
	if AP.apHandlerInstance and AP.apHandlerInstance.connected and AP.apHandlerInstance.socket then
		AP.apHandlerInstance.socket:Send(JsonEncode({ bounce_packet }), false)
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
