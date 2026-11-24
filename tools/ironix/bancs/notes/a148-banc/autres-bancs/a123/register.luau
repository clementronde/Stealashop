--!nocheck
-- a123 : FortuneTowerService et FortuneTowerController dans l'arbre du banc a27 (Script Sync).
moduleScript(SERVICES, "FortuneTowerService", "server/Services/FortuneTowerService.luau")
moduleScript(CONTROLLERS, "FortuneTowerController", "client/Controllers/FortuneTowerController.luau")

-- La vitrine en jeu (tag FortuneVault), ou nil.
function vaults()
	local out = {}
	for _, inst in CollectionService:GetTagged("FortuneVault") do
		table.insert(out, inst)
	end
	return out
end
function currentVault()
	return vaults()[1]
end
-- Colis de la vitrine au sol (Workspace/CarryDrops, attribut FortuneBox).
function fortuneDrops()
	local out = {}
	local drops = Workspace:FindFirstChild("CarryDrops")
	if drops then
		for _, child in drops:GetChildren() do
			if child:GetAttribute("FortuneBox") == true then
				table.insert(out, child)
			end
		end
	end
	return out
end
-- Patch d'un interrupteur de Config/Features (avant le démarrage).
function setFeature(name, value)
	local features = SOURCES["shared/Config/Features.luau"]
	local patched, n = string.gsub(features, name .. " = %a+,", name .. " = " .. tostring(value) .. ",", 1)
	assert(n == 1, "interrupteur " .. name .. " introuvable dans Config/Features")
	SOURCES["shared/Config/Features.luau"] = patched
	-- a210 (vague 63) : Config/Cosmetics requiert Features, déjà chargé (Config/Zones) avant ce correctif : on l oublie
	local config = SHARED and SHARED:FindFirstChild("Config")
	local module = config and config:FindFirstChild("Features")
	if module then
		for _, cache in caches do
			cache[module] = nil
		end
	end
end
