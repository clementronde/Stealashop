--!nocheck
-- Copie d'a48 (DEV-102) : profil v6 attendu quand Types/Profile a Offline (gains hors ligne), 5 sinon.
-- Scénario « off » : Features.Index = false (MAJ 2 pas ouverte), boutique Robux coupée. Les découvertes
-- sont notées et l'attribut posé (rien n'est perdu à l'ouverture de l'index), mais ni bonus de revenus
-- ni message ; côté client, IndexController ne branche rien (écran fermé, cartes d'exemple laissées,
-- bouton Index sans effet).

advance(1000)
startServer()

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(Features.Index == false, "Features.Index = false (pre.off)")
check(logHas("[IndexService] Features.Index = false : découvertes notées, sans bonus de revenus ni message", "PRINT", "server"), "une ligne dans la sortie au démarrage")

section("découvertes notées, sans bonus ni message")
local data = newProfile()
local count = 0
for _, item in Index.ByZone[1] do
	if item.Id ~= "Z1_Carotte" then
		count += 1
		addItem(data, `z1-{count}`, item.Id, if count <= 3 then count else nil, 1, 500) -- copie a46 : le présentoir 4 reçoit le colis
	end
end
local cid = join("Cid", data)
advance(1.5)
check(dataOf(cid).Version == (if string.find(SOURCES["shared/Types/Profile.luau"] or "", "Spot: Spot?", 1, true) then 7 elseif string.find(SOURCES["shared/Types/Profile.luau"] or "", "Offline: Offline", 1, true) then 6 else 5) and countKeys(dataOf(cid).Index) == 12, "migration v3 → v4 faite quand même : 12 objets découverts")
check(openBox(cid, 4, "Common", "Z1_Carotte", "Standard", 1) ~= nil, "la Carotte ouverte")
check(dataOf(cid).Index.Z1_Carotte ~= nil and string.find(cid:GetAttribute("IndexDiscovered"), "Z1_Carotte", 1, true) ~= nil, "découverte notée, attribut à jour")
check(#IndexService.GetCompletedZones(cid) == 1, "la zone 1 est complète dans l'index")
check(IndexService.GetIncomeBonus(cid) == 0, "mais aucun bonus de revenus")
advance(revealDelay("Common") + 2)
check(#notifies(cid, "complete") == 0, "ni message")
check(cid:GetAttribute("Income") == cid:GetAttribute("ExposedIncome") and DisplayService.GetGlobalMultiplier(cid) == 1, "revenus sans bonus (M global = 1)")

section("client : rien n'est branché")
local playerGui = cid:FindFirstChild("PlayerGui")
local gui = buildIndexGui(playerGui)
local hud = buildHud(playerGui)
startClient(cid)
check(logHas("[Loader Client] 1 module(s) démarré(s)", "PRINT", "client"), "IndexController chargé")
check(gui.Root.Window.List:FindFirstChild("Preview_1") ~= nil, "écran pas branché : cartes d'exemple laissées")
click(hud.LeftRail.IndexButton)
check(gui.Enabled == false and #cardsOf(gui) == 0, "le bouton Index ne fait rien")

summary("scénario off")
