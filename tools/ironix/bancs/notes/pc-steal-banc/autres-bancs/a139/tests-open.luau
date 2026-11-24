-- a139 : lu après les scénarios du banc a104 (copie a116), dans la même fonction (leurs locales servent ici).
-- A139_PERF = "on" (Config/PerfClient tel quel) ou "off" (réglages coupés : l'ancien comportement).
print("== a139 : ShelfOpenController, colis relus seulement quand leur état change")
local ON = A139_PERF == "on"
local idleBoxes, idleSet = {}, {}
for n = 1, 30 do
	idleBoxes[n] = makeBox((n - 1) % 10 + 1, "Standard", true)
	idleSet[idleBoxes[n]] = true
end
-- Le perso loin des colis : HeistController (invites « Open ») ne lit plus leur état.
local root = character:FindFirstChild("HumanoidRootPart")
local rootAt = root.CFrame
root.CFrame = CFrame.new(0, 3, 500)
advance(0.1)
local baseGet = Methods.GetAttribute
local reads = 0
Methods.GetAttribute = function(self, k)
	if k == ShelfOpenState.StateAttribute and idleSet[self] then
		reads += 1
	end
	return baseGet(self, k)
end
advance(0.5)
Methods.GetAttribute = baseGet
root.CFrame = rootAt
if ON then
	check(reads == 0, `30 colis au repos : leur état n'est plus lu à chaque image ({reads} lectures en 0,5 s)`)
else
	check(reads >= 30 * 30, `PerfClient coupé : l'état des 30 colis lu à chaque image, comme avant ({reads})`)
end

-- Un colis au repos qui s'ouvre est suivi à l'image suivante.
local first = idleBoxes[1]
open(first, 1)
advance(1 / 60)
check(sessionOf(first) ~= nil and sessionOf(first).Phase == "Opening", "colis au repos ouvert : suivi dès l'image suivante")
first:SetAttribute("ShelfOpenState", nil)
advance(0.1)
check(sessionOf(first) == nil, "ouverture annulée par le serveur : finie")

-- Ouverture annulée par le serveur pendant la sortie : le colis caché revient quand la sortie finit (doneAt et
-- colis caché posés à la fin de la sortie, relus comme avant).
local second = idleBoxes[2]
open(second, 1)
advance(0.7)
check(sessionOf(second) ~= nil and sessionOf(second).Phase == "Waiting", "2e colis : attend l'objet")
local item2 = makeItem(2, { Rarity = "Common", Income = 5 })
advance(1 / 60)
check(sessionOf(second) ~= nil and sessionOf(second).Phase == "Revealing" and second.Body.LocalTransparencyModifier == 1, "2e colis : sortie, colis caché")
second:SetAttribute("ShelfOpenState", nil)
advance(4)
check(sessionOf(second) == nil and second.Body.LocalTransparencyModifier == 0, "état retiré pendant la sortie : colis remis visible à la fin de la sortie")
item2:Destroy()
advance(0.1)

-- Colis retiré (tag ShelfBox) : plus suivi, sans erreur.
local third = idleBoxes[3]
CollectionService:RemoveTag(third, "ShelfBox")
third:SetAttribute("ShelfOpenState", "Opening")
advance(0.1)
check(sessionOf(third) == nil, "colis sans tag : son état n'est plus suivi")
check(errorsInLog() == 0, "a139 : aucune erreur ni avertissement des contrôleurs")
