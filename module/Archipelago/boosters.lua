-- boosters.lua manages consumable "Score Booster" items usage status,
-- calculating available and used items, and applying bonus points.

local AP = ...

AP.bonusUsage = AP.bonusUsage or {}

AP.GetTotalUsedBonusItems = function()
	local total = 0
	for _, usage in pairs(AP.bonusUsage or {}) do
		if type(usage) == "table" then
			total = total + (usage.money or 0) + (usage.ex or 0) + (usage.hex or 0)
		else
			total = total + usage
		end
	end
	return total
end

AP.GetAvailableBonusItems = function()
	local _, _, _, total_received = AP.GetModifierStats()
	local total_used = AP.GetTotalUsedBonusItems()
	return math.max(0, total_received - total_used)
end

AP.ApplyBonusPercentage = function(chart_name, proposed)
	if not AP.bonusUsage[chart_name] or type(AP.bonusUsage[chart_name]) ~= "table" then
		AP.bonusUsage[chart_name] = {money=0, ex=0, hex=0}
	end
	local usage = AP.bonusUsage[chart_name]
	usage.money = usage.money + (proposed.money or 0)
	usage.ex = usage.ex + (proposed.ex or 0)
	usage.hex = usage.hex + (proposed.hex or 0)
	
	AP.SaveBonusUsage()
	AP.FinalizeEvaluationAndSendChecks()
end
