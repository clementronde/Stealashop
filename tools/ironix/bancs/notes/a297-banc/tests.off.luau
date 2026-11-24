--!nocheck
-- Scénario « off » (a297, serveur) : jeu DEV, zone safe autour du hub, mais Crate.Reveal.Enabled = false (Config, avant
-- le démarrage) : aucune ouverture, objets donnés et tous leurs messages tout de suite.
SET_ENVIRONMENT("Dev")
REPLACE("shared/Config/Monetization.luau", "Enabled = true, -- V0 de Cantin, 21/11 ; false", "Enabled = false, -- V0 de Cantin, 21/11 ; false")
local zone = make("Part", { Name = "SafeZone_Banc", Anchored = true, CanCollide = false, Size = Vector3.new(800, 200, 800), CFrame = CFrame.new(0, 50, 0) }, MAP)
CollectionService:AddTag(zone, "SafeZone")
startServer()
local PREFIX = "Exclusive Crate: you got a"
local SafeZone = sharedModule("SafeZone")
local ada = join("Ada", newProfile())
advance(1.5)
local function exclusives()
	local n = 0
	for _, entry in dataOf(ada).Items do
		if string.find(entry.Id, "^Exclusive_") then
			n += 1
		end
	end
	return n
end
section("O1 ouverture coupée : 3 objets et 3 messages tout de suite")
check(Monetization.Crate.Reveal.Enabled == false and SafeZone.ContainsPlayer(ada), "Reveal.Enabled = false, Ada dans la zone safe")
local starts = #remotes("RevealStarted")
local m0 = #notifies(ada, PREFIX)
check(settle(receipt(ada, 8402, "OFF-3")) == GRANTED, "x3 : PurchaseGranted")
advance(0.2)
check(exclusives() == 3, "3 objets donnés")
check(#remotes("RevealStarted") == starts, "aucune ouverture")
check(#notifies(ada, PREFIX) == m0 + 3, `3 messages tout de suite ({#notifies(ada, PREFIX) - m0})`)
summary("scénario off")
