--!nocheck
-- C. PV partagés entre deux joueurs, portée, débit ; HitController vise le camion comme une vitrine,
-- coup au marqueur Impact, pas de retour de verre ; barre de vie (TruckController) ; les vitrines
-- ne changent pas.

local Tool = serverModule("ToolService")
local Shatter = clientModule("ShatterController")
local TruckEvent = sharedModule("Config/TruckEvent")
startServer()
local A = newPlayer("Alice")
local B = newPlayer("Bob")
-- Camion de la zone 2 : x 123 à 157, z −6,3 à 6,3, y 0 à 15,8.
spawnCharacter(A, Vector3.new(140, 3, 10), Vector3.new(0, 0, -1))
spawnCharacter(B, Vector3.new(150, 3, -10), Vector3.new(0, 0, 1))
local toolA = giveTool(A, "Crowbar")
giveTool(B, "Wrench")
Tool.damage[A] = 30
Tool.damage[B] = 45
startClient(A)

Workspace:SetAttribute("TruckSpawnNow", 2)
flush()
local truck = currentTruck()
check(truck ~= nil and truck:GetAttribute("Zone") == 2, "C0 (crochet) camion en zone 2")
local id = truck:GetAttribute("WindowId")
local function hp()
	return truck:GetAttribute("HP")
end

section("C. PV partagés")
fireAs(A, "HitWindow", id)
advance(0.15)
check(hp() == 970, `C1 un coup d'Alice (30) : 1000 → 970 ({hp()})`)
fireAs(B, "HitWindow", id)
advance(0.15)
check(hp() == 925, `C2 un coup de Bob (45) sur les mêmes PV : 925 ({hp()})`)
advance(10)
check(hp() == 925, "C3 aucune régénération en 10 s")
check(#remotes("WindowHP", function(e) return e.args[1] == id end) == 0, "C4 aucun WindowHP pour le camion (ses PV sont l'attribut HP)")
check(#remotes("WindowHit", function(e) return e.args[1] == id end) == 0, "C5 aucun WindowHit pour le camion (pas de fissures de verre)")

section("C'. Portée et outil (règles des vitrines)")
moveTo(B, Vector3.new(150, 3, -18.5), Vector3.new(0, 0, 1)) -- 12,2 studs du camion
clearLog()
fireAs(B, "HitWindow", id)
advance(0.15)
check(hp() == 925 and logHas("trop loin"), "C6 à 12,2 studs : refusé (10 au plus au serveur)")
moveTo(B, Vector3.new(150, 3, -15.8), Vector3.new(0, 0, 1)) -- 9,5 studs
fireAs(B, "HitWindow", id)
advance(0.15)
check(hp() == 880, `C7 à 9,5 studs : compté ({hp()})`)
moveTo(B, Vector3.new(150, 3, -10), Vector3.new(0, 0, 1))
B.Character:FindFirstChildOfClass("Tool").Parent = B.Backpack
advance(1.1) -- WindowService n'écrit qu'un refus par seconde et par joueur
clearLog()
fireAs(B, "HitWindow", id)
advance(0.15)
check(hp() == 880 and logHas("outil de casse pas en main"), "C8 sans outil en main : refusé")

section("C''. Débit : 10 coups par seconde au plus")
advance(1.1)
local before = hp()
for _ = 1, 25 do
	fireAs(A, "HitWindow", id)
end
advance(0.15)
check(before - hp() == 10 * 30, `C9 25 coups dans la même seconde : 10 comptés ({(before - hp()) / 30})`)
advance(1.1)

section("C'''. HitController : le camion visé comme une vitrine")
MARKER_DELAY = nil -- animation pas livrée : le coup part au clic
local calls0 = #serverCalls("HitWindow")
before = hp()
toolA.Activated:Fire()
flush()
local calls = serverCalls("HitWindow")
check(#calls == calls0 + 1 and calls[#calls].args[1] == id, "C10 clic devant le camion : HitWindow(EventTruck)")
advance(0.15)
check(hp() == before - 30, "C11 coup compté")
check(#Shatter.localHits == 0, "C12 pas de retour de verre (ShatterController.LocalHit) sur le camion")
-- Coup au marqueur Impact (0,133 s, comme HitWindow chez Clément).
MARKER_DELAY = 0.133
advance(0.2)
calls0 = #serverCalls("HitWindow")
local clickAt = now()
toolA.Activated:Fire()
flush()
check(#serverCalls("HitWindow") == calls0, "C13 avec l'animation : rien au clic…")
advance(0.2)
calls = serverCalls("HitWindow")
check(#calls == calls0 + 1 and near(calls[#calls].t - clickAt, 0.133, 0.02), `C14 … HitWindow au marqueur Impact ({calls[#calls] and calls[#calls].t - clickAt})`)
-- Trop loin côté client (8 studs) : aucun envoi.
moveTo(A, Vector3.new(140, 3, 15.5), Vector3.new(0, 0, -1)) -- 9,2 studs
advance(0.2)
calls0 = #serverCalls("HitWindow")
toolA.Activated:Fire()
advance(0.5)
check(#serverCalls("HitWindow") == calls0, "C15 à 9,2 studs : HitController ne vise rien (8 studs côté client)")
-- Dos au camion : rien non plus.
moveTo(A, Vector3.new(140, 3, 10), Vector3.new(0, 0, 1))
advance(0.2)
toolA.Activated:Fire()
advance(0.5)
check(#serverCalls("HitWindow") == calls0, "C16 dos au camion : rien")

section("C''''. Les vitrines ne changent pas")
-- Vitrine du magasin de droite de la zone 2 : x 130 à 150, z = 30,75.
moveTo(A, Vector3.new(140, 3, 25), Vector3.new(0, 0, 1))
MARKER_DELAY = nil
advance(0.2)
local storeWindow = nil
for _, store in STORES do
	if store:GetAttribute("Zone") == 2 and store.Name:find("Right") then
		storeWindow = store.Window
	end
end
local windowId = storeWindow:GetAttribute("WindowId")
calls0 = #serverCalls("HitWindow")
toolA.Activated:Fire()
advance(0.15)
calls = serverCalls("HitWindow")
check(#calls == calls0 + 1 and calls[#calls].args[1] == windowId, `C17 devant une vitrine : HitWindow({windowId})`)
check(#Shatter.localHits == 1 and Shatter.localHits[1].id == windowId, "C18 retour de verre sur la vitrine, comme avant")
check(#remotes("WindowHit", function(e) return e.args[1] == windowId and e.to == A end) == 1, "C19 WindowHit envoyé pour la vitrine (au frappeur et aux joueurs proches)")
check(#remotes("WindowHP", function(e) return e.args[1] == windowId end) >= 1, "C20 WindowHP envoyé pour la vitrine")
local maxHp = storeWindow:GetAttribute("MaxHP")
local hpWindow = nil
for _, e in remotes("WindowHP", function(e) return e.args[1] == windowId end) do
	hpWindow = e.args[2]
end
advance(2)
local last = nil
for _, e in remotes("WindowHP", function(e) return e.args[1] == windowId end) do
	last = e.args[2]
end
check(maxHp ~= nil and last ~= nil and last > hpWindow, "C21 la vitrine se régénère toujours (3 %/s)")

section("C'''''. Barre de vie (TruckController)")
local gui = A.PlayerGui:FindFirstChild("BB_WindowHP_EventTruck")
check(gui ~= nil and gui:IsA("BillboardGui"), "C22 copie de BB_WindowHP chez le joueur")
check(gui and gui.Adornee == truck:FindFirstChild("HealthBarPoint", true), "C23 accrochée à HealthBarPoint")
check(gui and gui.Size == UDim2.new(8, 0, 1.2, 0) and gui.MaxDistance == TruckEvent.HealthBarMaxDistance, "C24 deux fois la taille de Clément, visible de loin")
check(gui and gui.Enabled == true, "C25 visible")
local label = gui and gui:FindFirstChild("Label", true)
local fill = gui and gui:FindFirstChild("Fill", true)
check(label and label.Text == `{hp()} / 1000`, `C26 Label « {label and label.Text} »`)
check(fill and near(fill.Size.X.Scale, hp() / 1000, 1e-9), "C27 Fill à la largeur des PV")
-- Un joueur qui arrive en cours de route lit les PV dans l'attribut (pas de WindowHP à attendre).
check(truck:GetAttribute("HP") == hp(), "C28 PV lisibles par un client qui arrive : attribut HP")

section("C''''''. Plusieurs joueurs jusqu'à la casse")
Tool.damage[A] = 400
Tool.damage[B] = 400
local wrench = B.Backpack:FindFirstChildOfClass("Tool")
wrench.Parent = B.Character
moveTo(A, Vector3.new(140, 3, 10), Vector3.new(0, 0, -1))
fireAs(A, "HitWindow", id) -- 520 → 120
fireAs(B, "HitWindow", id) -- 120 → 0 : Bob casse
fireAs(A, "HitWindow", id) -- déjà cassé : ignoré
flush()
check(truck:GetAttribute("Broken") == true and truck:GetAttribute("HP") == 0, "C29 à 0 PV : Broken, HP = 0 tout de suite")
check(logHas("cassé par Bob"), "C30 OnBroken : le casseur est l'auteur du dernier coup (Bob)")
check(#truckDrops() == 12, "C31 il explose et lâche ses 12 colis")
advance(0.2)
check(gui.Enabled == false, "C32 barre de vie cachée à l'explosion")
local hpAfter = hp()
fireAs(B, "HitWindow", id)
advance(0.2)
check(hp() == hpAfter and not logHas("vitrine inconnue"), "C33 un coup après la casse : ignoré sans bruit")

summary("scénario coups")
