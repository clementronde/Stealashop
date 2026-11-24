--!nocheck
-- Scénario depositoff du banc a152 : HeldItem.DepositToHand = false (l'ancien déroulé du dépôt).
do
	local key = "shared/Config/HeldItem.luau"
	local text, n = string.gsub(SOURCES[key], "DepositToHand = true,", "DepositToHand = false,")
	assert(n == 1, "DepositToHand = true introuvable dans Config/HeldItem")
	SOURCES[key] = text
end
