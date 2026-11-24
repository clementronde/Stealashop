--!nocheck
-- Banc a129 (vague 39, 2026-11-14), scénario « pvp » : PvPController ne revoit les objets d'une boutique
-- qu'au tour où son état change (Version), sans retarder une invite : elle s'allume et s'éteint au même
-- tour (0,2 s) qu'avant, et tout de suite quand Carrying change. Mise en place : celle du banc a29.

startServer()

local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3) -- le meilleur : à l'abri
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
startClient(bob)
advance(1.2)
local adaShop = shopOf(ada)

section("invite au même tour qu'avant")
local broken = breakDoor(bob, adaShop)
check(broken, "porte d'Ada cassée")
moveTo(bob, SHOPS[1].S.outside + Vector3.new(0, 0, -6)) -- dehors
advance(0.5)
local soda = displayModel(adaShop, 1)
local prompt1 = soda and PvPController.GetPrompt(soda)
check(prompt1 ~= nil and not prompt1.Enabled, "dehors : invite créée, éteinte")
standBy(bob, adaShop, 1)
advance(0.21)
check(prompt1 and prompt1.Enabled, "entré dans la boutique : invite allumée dès le tour suivant (0,2 s)")

section("rien à revoir sans changement")
-- On éteint l'invite à la main : tant que l'état de la boutique ne change pas, elle n'est plus réécrite
-- (avant la vague 39, chaque tour la réécrivait).
prompt1.Enabled = false
advance(0.6)
check(not prompt1.Enabled, "état de la boutique inchangé : l'invite n'est pas réécrite à chaque tour")
prompt1.Enabled = true

section("Carrying : tout de suite, sans attendre le tour")
bob:SetAttribute("Carrying", "Test")
flush()
check(not prompt1.Enabled, "mains pleines : invite éteinte aussitôt (signal Carrying)")
bob:SetAttribute("Carrying", nil)
flush()
check(prompt1.Enabled, "mains vides : invite rallumée aussitôt")

section("SafeSlots : au tour suivant")
local before = bob.PlayerGui:FindFirstChild("SafeTag") ~= nil
adaShop:SetAttribute("SafeSlots", "1,3")
advance(0.21)
check(not prompt1.Enabled, "présentoir 1 mis à l'abri : invite éteinte au tour suivant")
local tags = 0
for _, child in bob.PlayerGui:GetChildren() do
	if child.Name == "SafeTag" then
		tags += 1
	end
end
check(before and tags == 2, `deux étiquettes « SAFE » (présentoirs 1 et 3 ; trouvé {tags})`)
adaShop:SetAttribute("SafeSlots", "3")
advance(0.21)
check(prompt1.Enabled, "présentoir 1 rendu : invite rallumée au tour suivant")

section("sortie de la boutique")
moveTo(bob, SHOPS[1].S.outside + Vector3.new(0, 0, -6))
advance(0.21)
check(not prompt1.Enabled, "sorti : invite éteinte au tour suivant")
standBy(bob, adaShop, 1)
advance(0.21)
check(prompt1.Enabled, "revenu : invite rallumée au tour suivant")

section("autres objets de la boutique")
local chips = displayModel(adaShop, 2)
check(chips and PvPController.GetPrompt(chips) and PvPController.GetPrompt(chips).Enabled, "les autres objets de la boutique suivent aussi")
check(not logHas("[PvPController]", "WARN"), "aucune erreur dans la boucle de PvPController")

summary("scénario pvp")
