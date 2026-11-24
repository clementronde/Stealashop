---------------------------------------------------------------- a116 : invite « Open » maintenue
-- (après les lignes 1 à 219 du tests.luau de la copie a116 du banc a104 : arbre du jeu, faux joueur, makeBox…)
print("== a116 HeistController" .. (if SHELF_OPEN then " (ShelfOpen)" else " (ShelfOpen = false)"))
local tiers = { "Standard", "Premium", "Luxe" }
for n, tier in tiers do
	makeBox(n, tier, false)
end
local Heist = requireModule(HeistModule)
taskLib.spawn(Heist.Start)
advance(0.3)
for n, tier in tiers do
	local p = slotAtt(n):FindFirstChild("GrabPrompt")
	local t = Balance.Heist.BoxTiers[tier].GrabTime
	if SHELF_OPEN then
		check(p ~= nil and p.ActionText == "Open" and near(p.HoldDuration, t), "C1 " .. tier .. " : invite « Open », maintien " .. t .. " s")
	else
		check(p ~= nil and p.ActionText == "Steal" and near(p.HoldDuration, t), "C1 " .. tier .. " : ShelfOpen = false, invite « Steal » inchangée")
	end
end
if SHELF_OPEN then
	local p = slotAtt(2):FindFirstChild("GrabPrompt")
	check(p.Enabled == true, "C2 invite active")
	p.PromptButtonHoldBegan:Fire()
	check(#NET.open == 1 and #NET.grab == 0 and p.Enabled == true, "C3 début du maintien : un OpenShelfBox, invite toujours active")
	p.Triggered:Fire()
	check(#NET.open == 2 and NET.open[1] == NET.open[2] and #NET.grab == 0, "C4 fin du maintien : second OpenShelfBox, même slotId")
	check(p.Enabled == false, "C5 invite coupée en attendant le serveur")
end
