--!nocheck
-- Scénario « alert » : l'alerte de la victime vue par son client, repli V0 (UI_TheftAlert pas
-- livré), à 3 et 4 joueurs. Bannière, sirène (absente puis livrée), aucune flèche sans Arrow (a227, L-175), surbrillance,
-- batte équipée une seule fois (BatController), et tout disparaît : TheftAlert(false), mort ou
-- départ du voleur. Deux vols en même temps : la réannonce du serveur garde l'alerte sans la
-- relancer.

startServer()

local adaData = victimProfile()
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
giveBat(ada)
-- Les appels à Humanoid:EquipTool sont comptés (la batte ne s'équipe qu'une fois par alerte).
local equips = 0
do
	local base = Methods.EquipTool
	Methods.EquipTool = function(self, tool)
		if tool and tool:GetAttribute("BatTool") == true then
			equips += 1
		end
		return base(self, tool)
	end
end
startClient(ada)
advance(1.2)
local adaShop = shopOf(ada)

section("au repos")
local s = state()
check(not s.Active and s.Thefts == 0 and s.Highlights == 0 and not s.Siren, "au repos : aucune alerte")
check(ada.PlayerGui:FindFirstChild("TheftAlertV0") == nil, "au repos : l'écran V0 n'est pas créé d'avance")
check(logHas("Adrénaline × 1.25 pour la victime d'un vol", "PRINT", "server"), "TheftAlertService démarré")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")

-- a112 (vague 33, Cantin 2026-11-13) : l'alerte part dès la casse de la porte (alerte d'intrusion, sans
-- objet), puis la prise de l'objet la remplace (même voleur).
section("casse : alerte d'intrusion V0 (UI_TheftAlert pas livré)")
clearLog()
local equipsBefore = equips
check(breakDoor(bob, adaShop), "porte d'Ada cassée par Bob")
frame()
s = state()
check(s.Active and s.Thefts == 1 and s.Thief == bob and s.ItemId == "", "casse : alerte d'intrusion, voleur Bob, sans objet")
check(s.Headline == "BOB IS STEALING YOUR SHOP!", `bandeau V0 « BOB IS STEALING YOUR SHOP! » (trouvé {s.Headline})`)
local alertsAtBreak = theftAlerts(ada)
check(#alertsAtBreak == 1 and alertsAtBreak[1].args[1] == true and alertsAtBreak[1].args[2] == bob and alertsAtBreak[1].args[3] == nil, "serveur : un seul TheftAlert(true, Bob, nil)")

section("vol : alerte V0 (UI_TheftAlert pas livré)")
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
check(state().Headline == "BOB IS STEALING YOUR SHOP!", "le message est appliqué à l'image suivante, pas pendant sa réception")
frame()
s = state()
check(s.Active and s.Thefts == 1, "alerte affichée à l'image suivante")
check(s.Thief == bob and s.ItemId == "Z1_CanetteDeSoda", "voleur Bob, objet Z1_CanetteDeSoda")
check(s.Fallback, "repli V0 : UI_TheftAlert n'est pas livré")
check(s.Headline == "BOB IS STEALING YOUR SODA CAN!", `bandeau V0 « BOB IS STEALING YOUR SODA CAN! » (trouvé {s.Headline})`)
local v0 = ada.PlayerGui:FindFirstChild("TheftAlertV0")
check(v0 ~= nil and v0.Enabled == true, "écran TheftAlertV0 allumé dans le PlayerGui")
check(v0 ~= nil and v0.IgnoreGuiInset == true and v0.ResetOnSpawn == false and v0.DisplayOrder == 20, "V0 : plein écran, gardé à la réapparition, au-dessus des autres écrans")
local action = v0 and v0:FindFirstChild("Action", true)
check(action ~= nil and action.Text == "HIT THEM!", "seconde ligne « HIT THEM! »")
local banner = v0 and v0:FindFirstChild("Banner")
check(banner ~= nil and banner.Position.Y.Scale >= 0.2 and banner.Size.X.Scale == 1, "bandeau rouge sur toute la largeur, sous le haut de l'écran (2.2)")
local veil = v0 and v0:FindFirstChild("Veil")
check(veil ~= nil and veil.Size.X.Scale == 1 and veil.Size.Y.Scale == 1 and veil.Active ~= true, "voile rouge plein écran, qui ne prend pas les touches")
check(logHas("UI_TheftAlert pas encore livré", "PRINT", "client"), "sortie : repli V0 signalé")
check(not s.Siren and logCount("son « TheftAlert_Siren » absent de ReplicatedStorage.Assets.Sounds", "PRINT", "client") == 1, "sirène pas livrée : alerte muette, une ligne dans la sortie")
-- a227 (L-175) : plus de Beam V0 au sol sans Arrow, plus de flèche du tout.
check(not s.Arrow and s.Beam == nil and CAMERA:FindFirstChild("TheftAlertArrow") == nil, "pas d'Arrow : aucune flèche, aucun Beam V0 dans la caméra")
local glow = alertHighlightOf(bob)
check(glow ~= nil and glow.Enabled and glow.DepthMode == "Enum.HighlightDepthMode.AlwaysOnTop" and glow.Adornee == bob.Character, "Bob surligné à travers les murs (Highlight AlwaysOnTop sur son personnage)")
local outline = stolenOutlineOf(bob)
check(outline ~= nil and outline.Enabled == false, "contour StolenOutline de CarryService coupé en local (même nombre de Highlight)")
check(s.Highlights == 1, "une surbrillance")
check(holdsBat(ada), "la batte d'Ada s'est équipée toute seule (BatController)")
check(equips - equipsBefore == 1, `batte équipée une seule fois (EquipTool appelé {equips - equipsBefore} fois)`)

section("la flèche suit le voleur, le voile pulse")
walkTo(bob, refsOfShop(adaShop).outside)
check(CAMERA:FindFirstChild("TheftAlertArrow") == nil and not state().Arrow, "Bob sorti de la boutique : toujours aucune flèche")
local seen = {}
for _ = 1, 12 do
	frame()
	seen[math.round(veil.BackgroundTransparency * 100)] = true
end
local distinct = 0
for _ in seen do
	distinct += 1
end
check(distinct >= 3, "le voile rouge pulse")

section("mort du voleur : tout disparaît")
kill(bob)
flush()
frame()
s = state()
check(not s.Active and s.Thefts == 0, "Bob mort : alerte finie")
check(v0.Enabled == false, "écran V0 éteint")
check(CAMERA:FindFirstChild("TheftAlertArrow") == nil, "aucun Beam V0")
check(alertHighlightOf(bob) == nil and s.Highlights == 0, "surbrillance retirée")
local alerts = theftAlerts(ada)
check(alerts[#alerts].args[1] == false, "le serveur a envoyé TheftAlert(false)")
spawnCharacter(bob, SHOPS[2].S.center)
advance(0.2)

section("mort et départ du voleur vus par le client seul")
-- Alerte envoyée par le serveur sans vol derrière : le serveur n'enverra pas de false, le client
-- doit voir lui-même la mort ou le départ du voleur.
NetServer.Server.TheftAlert:Fire(ada, true, cy, "Z1_Donut")
frame()
s = state()
check(s.Active and s.Thief == cy and s.Headline == "CY IS STEALING YOUR DONUT!", "alerte de Cy affichée")
check(alertHighlightOf(cy) ~= nil, "Cy surligné (pas de StolenOutline : rien à couper)")
kill(cy)
frame()
check(not state().Active and alertHighlightOf(cy) == nil, "Cy meurt, sans message du serveur : alerte finie quand même")
spawnCharacter(cy, SHOPS[3].S.center)
advance(0.2)
local dan = join("Dan", newProfile())
NetServer.Server.TheftAlert:Fire(ada, true, dan, "Z1_Banane")
frame()
check(state().Active and state().Thief == dan, "alerte de Dan affichée")
leave(dan)
frame()
check(not state().Active and state().Highlights == 0, "Dan quitte le jeu : alerte finie")
NetServer.Server.TheftAlert:Fire(ada, true, nil, "Z1_Banane")
frame()
check(not state().Active, "TheftAlert(true) sans voleur (parti entre-temps) : ignoré")
check(logHas("sans voleur valable", "PRINT", "client"), "une ligne dans la sortie")

section("deux vols en même temps, sirène livrée")
local sounds = folder(ASSETS, "Sounds")
local sirenTemplate = make("Sound", { Name = "TheftAlert_Siren", Looped = true, SoundId = "rbxassetid://1" }, sounds)
clearLog()
equipsBefore = equips
check(steal(bob, adaShop, 2), "Bob prend le Paquet de chips")
frame()
s = state()
check(s.Active and s.Thief == bob and s.Headline == "BOB IS STEALING YOUR BAG OF CHIPS!", "alerte : Bob, Bag of Chips")
check(s.Siren and soundCount("Play", "TheftAlertSiren") == 1, "sirène jouée au début de l'alerte")
local sirenCopy = SoundService:FindFirstChild("TheftAlertSiren")
check(sirenCopy ~= nil and sirenCopy.IsPlaying == true and sirenCopy ~= sirenTemplate, "une copie de la sirène joue dans SoundService (son 2D)")
check(sirenTemplate.IsPlaying ~= true and sirenTemplate.Parent == sounds, "le Sound de Clément n'est pas touché")
check(steal(cy, adaShop, 4), "Cy prend le Donut")
frame()
s = state()
check(s.Active and s.Thefts == 2 and s.Thief == cy and s.Headline == "CY IS STEALING YOUR DONUT!", "deux vols : le dernier annoncé est affiché (Cy)")
check(s.Highlights == 2 and alertHighlightOf(bob) ~= nil and alertHighlightOf(cy) ~= nil, "les deux voleurs sont surlignés")
check(stolenOutlineOf(bob).Enabled == false and stolenOutlineOf(cy).Enabled == false, "leurs deux contours StolenOutline sont coupés")
check(soundCount("Play", "TheftAlertSiren") == 1, "la sirène ne repart pas pour le second voleur")
check(holdsBat(ada) and equips - equipsBefore <= 1, `batte toujours en main, jamais équipée deux fois (EquipTool appelé {equips - equipsBefore} fois)`)
local before = #theftAlerts(ada)
runHome(cy, adaShop)
local list = theftAlerts(ada)
local tail = {}
for index = before + 1, #list do
	table.insert(tail, list[index])
end
if #tail ~= 2 then
	for _, e in tail do
		print("    tail", e.args[1], e.args[2], e.args[3])
	end
end
check(#tail == 2 and tail[1].args[1] == false and tail[2].args[1] == true and tail[2].args[2] == bob and tail[2].args[3] == "Z1_PaquetDeChips", "dépôt de Cy : TheftAlert(false) puis réannonce (true, Bob, Z1_PaquetDeChips)")
check(near(tail[2].t, tail[1].t, 1e-9), "la réannonce part dans la même image que le false")
s = state()
check(s.Active and s.Thefts == 1 and s.Thief == bob, "l'alerte reste ouverte, sur Bob")
check(s.Headline == "BOB IS STEALING YOUR BAG OF CHIPS!", "bandeau revenu sur Bob")
check(s.Highlights == 1 and alertHighlightOf(cy) == nil and alertHighlightOf(bob) ~= nil, "Cy n'est plus surligné, Bob l'est toujours")
check(soundCount("Play", "TheftAlertSiren") == 1 and soundCount("Stop", "TheftAlertSiren") == 0 and s.Siren, "la sirène ne s'est ni arrêtée ni relancée")
runHome(bob, adaShop)
s = state()
check(not s.Active and s.Thefts == 0 and s.Highlights == 0, "dépôt de Bob : alerte finie")
check(soundCount("Stop", "TheftAlertSiren") == 1 and not s.Siren and sirenCopy.Parent == nil, "sirène arrêtée et détruite")
check(v0.Enabled == false and CAMERA:FindFirstChild("TheftAlertArrow") == nil, "écran V0 éteint, aucun Beam V0")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
check(not logHas("[TheftAlertController]", "WARN"), "aucune erreur du contrôleur")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")

if VERBOSE then
	dumpLog()
end
summary("scénario alert")
