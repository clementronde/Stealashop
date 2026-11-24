--!nocheck
-- Scénario « cameras » (a84) : Cameras N1 = alerte au propriétaire dès le 1er coup sur sa vitrine, une par
-- attaque (coups à moins de 30 s d'écart) ; N2 = en plus, CameraSpotted(attaquant, fin = heure + 30 s) au
-- seul propriétaire, et le vrai CameraAlertController (client d'Ada) surligne l'attaquant jusqu'à la fin.
-- Coup refusé (bouclier débutant) : aucune alerte.
startSkills()
local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
startClient(ada)
advance(1.2)
local adaShop = shopOf(ada)
local ALERT = "Your cameras spotted"
local function spotted(to)
	return remotes("CameraSpotted", function(e)
		return to == nil or e.to == to
	end)
end
local CameraAlert = clientModule("CameraAlertController")

section("sans caméras")
hitDoor(bob, adaShop, 3)
check(#notifies(ada, ALERT) == 0 and #spotted() == 0, "Cameras 0 : aucune alerte, aucun surlignage")

section("niveau 1 : alerte au 1er coup, une par attaque")
adaData.Cash = 1e9
fireAs(ada, "BuySkill", "Cameras")
advance(32) -- plus de 30 s depuis les coups d'avant : nouvelle attaque
hitDoor(bob, adaShop, 1)
check(#notifies(ada, ALERT) == 1, "1er coup : une alerte à Ada")
local msg, kind = lastNotify(ada)
check(msg == "Your cameras spotted Bob hitting your shop door!" and (kind == "Warning" or kind == "Alert"), `texte : « {msg} » ({kind})`)
hitDoor(bob, adaShop, 15)
advance(10)
hitDoor(bob, adaShop, 3)
check(#notifies(ada, ALERT) == 1, "même attaque (coups à moins de 30 s d'écart) : pas d'autre alerte")
check(#notifies(bob, ALERT) == 0 and #notifies(cy, ALERT) == 0, "seul le propriétaire est alerté")
check(#spotted() == 0, "niveau 1 : pas de surlignage")
hitDoor(cy, adaShop, 2)
check(#notifies(ada, ALERT) == 2 and string.find(lastNotify(ada), "Cy", 1, true), "un autre attaquant : une autre alerte")
advance(31)
hitDoor(bob, adaShop, 1)
check(#notifies(ada, ALERT) == 3, "plus de 30 s sans coup : nouvelle attaque, nouvelle alerte")

section("niveau 2 : attaquant surligné 30 s chez le propriétaire")
fireAs(ada, "BuySkill", "Cameras")
advance(31.5)
check(ada:GetAttribute("Skill_Cameras") == 2, "Cameras niveau 2")
local t0 = Workspace:GetServerTimeNow()
hitDoor(bob, adaShop, 1)
local list = spotted()
local e = list[#list]
check(#list == 1 and e.to == ada and e.args[1] == bob and math.abs(e.args[2] - (t0 + 30)) < 0.5, `CameraSpotted(Bob, heure + 30) à Ada seule (fin dans {e and string.format("%.1f", e.args[2] - t0)} s)`)
check(#notifies(ada, ALERT) == 4, "l'alerte du niveau 1 part aussi")
advance(0.5)
local glow = bob.Character:FindFirstChild("CameraHighlight")
check(glow and glow:IsA("Highlight") and glow.DepthMode == Enum.HighlightDepthMode.AlwaysOnTop and glow.Adornee == bob.Character, "client d'Ada : Highlight AlwaysOnTop dans le personnage de Bob")
check(CameraAlert.GetState().Highlights == 1, "GetState : 1 surlignage")
hitDoor(bob, adaShop, 5)
check(#spotted() == 1, "même attaque : CameraSpotted n'est pas renvoyé")
advance(20)
check(bob.Character:FindFirstChild("CameraHighlight") ~= nil, "toujours surligné 20 s plus tard")
advance(10)
check(bob.Character:FindFirstChild("CameraHighlight") == nil and CameraAlert.GetState().Spotted == 0, "surlignage retiré après 30 s")

section("coup refusé : pas d'alerte")
advance(31)
SHIELDED[ada] = true
advance(0.6)
local before = #notifies(ada, ALERT)
hitDoor(bob, adaShop, 3)
check(#notifies(ada, ALERT) == before and #spotted() == 1, "bouclier débutant : coups refusés, aucune alerte")
SHIELDED[ada] = false

section("départ de l'attaquant")
advance(1)
hitDoor(cy, adaShop, 1)
advance(0.5)
check(cy.Character:FindFirstChild("CameraHighlight") ~= nil, "Cy surligné")
leave(cy)
advance(0.5)
check(CameraAlert.GetState().Spotted == 0, "Cy parti : plus suivi")

section("sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("CameraAlertController]", "WARN"), "aucune erreur du client")
summary("scénario cameras")
