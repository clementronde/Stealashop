--!nocheck
-- Scénario « place » (L-089 point 2) : PlaceBox(boxUid, point) pose un colis de l'inventaire au sol de SA
-- boutique, à l'endroit visé : Spot dans le repère de la parcelle, ReadyAt = maintenant + attente de sa
-- rareté, FloorBox au sol (attributs, minuteur), état de l'inventaire à jour (copie d'a61). Refus : hors de sa boutique, chez un autre,
-- trop loin, sur un meuble (le dessus n'est pas le sol), dans un meuble, près d'un présentoir, près d'un
-- autre colis, trop de colis posés, colis inconnu ou déjà posé, mains prises, sans boutique. Double clic.
-- Attente : BoxReady(boxUid) à l'heure, « Ready! ». Boutique tournée de 90° : le point reste le même.

advance(1000)
startServer()

local function stateOfBox(player, uid)
	local m = floorBoxOf(player, uid)
	return if m then m:GetAttribute("UnboxState") else "absent"
end

section("pose au sol")
local ada = join("Ada", nil)
advance(1.5)
local uid = bringBox(ada, "Uncommon", "Z1_Donut", "Standard", 1)
check(uid ~= nil, "colis rangé dans l'inventaire")
local placed = {}
UnboxService.OnBoxPlaced(function(player, boxUid, box)
	table.insert(placed, { player = player, uid = boxUid, box = box })
end)
local t0 = serverTime()
local box = placeAt(ada, uid, 6, 20)
check(box ~= nil and box.Spot ~= nil, "PlaceBox accepté : Spot posé")
check(box and near(box.Spot.X, 6, 0.02) and near(box.Spot.Y, 0.3, 0.02) and near(box.Spot.Z, 20, 0.02), `Spot dans le repère de la parcelle (6, 0.3, 20) : ({box and box.Spot and box.Spot.X}, {box and box.Spot and box.Spot.Y}, {box and box.Spot and box.Spot.Z})`)
local delay = Rarities.ById.Uncommon.OpenDelay
check(box and box.ReadyAt >= t0 + delay and box.ReadyAt <= t0 + delay + 0.5, `ReadyAt = maintenant + {delay} s (Peu commun, 7.3)`)
local model = floorBoxOf(ada, uid)
check(model ~= nil and model:GetAttribute("OwnerUserId") == ada.UserId and model:GetAttribute("Rarity") == "Uncommon" and near(model:GetAttribute("ReadyAt"), box.ReadyAt, 1e-6), "FloorBox dans la boutique (BoxUid, OwnerUserId, Rarity, ReadyAt)")
check(model ~= nil and model:GetAttribute("UnboxState") == "Waiting" and model:GetAttribute("ItemId") == nil, "UnboxState « Waiting », aucun ItemId (5.7)")
local pivot = model and model:GetPivot().Position
check(pivot ~= nil and (pivot - floorPoint(ada, 6, 20)).Magnitude < 0.05, "son pivot sur le point du sol visé")
local label = model and model:FindFirstChild("Label", true)
check(label ~= nil and string.match(label.Text, "^%d+:%d%d$") ~= nil, `minuteur au-dessus ({label and label.Text or "absent"})`)
check(invOf(ada)["Box:" .. uid] == nil and invBox(ada, uid) ~= nil and invBox(ada, uid).Placed and near(invBox(ada, uid).ReadyAt, box.ReadyAt, 1e-3), "état : le colis a quitté l'inventaire, posé au sol avec son heure (copie d'a61)")
flush()
check(#placed == 1 and placed[1].uid == uid and placed[1].box.ReadyAt == box.ReadyAt, "OnBoxPlaced(player, uid, copie du colis)")

section("attente puis BoxReady")
advance(delay - 1)
check(#remotes("BoxReady", function(e) return e.to == ada end) == 0 and stateOfBox(ada, uid) == "Waiting", "pas prêt avant l'heure")
advance(1.5)
local readies = remotes("BoxReady", function(e) return e.to == ada end)
check(#readies == 1 and readies[1].args[1] == uid, "BoxReady(boxUid) à l'heure, une fois")
check(stateOfBox(ada, uid) == "Ready" and label and label.Text == "Ready!", "UnboxState « Ready », minuteur « Ready! »")
advance(2)
check(#remotes("BoxReady", function(e) return e.to == ada end) == 1, "BoxReady pas répété")

section("refus")
local u2 = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
-- `patterns` : messages acceptés (« dans un meuble » : le vrai Raycast ne voit pas la pièce où part le
-- rayon, donc le volume du colis la touche (« No room here ») ; le faux d'a36 la voit à t = 0 (« floor »).
local function refused(label, lx, lz, patterns, from)
	local before = #notifies(ada)
	local result = placeAt(ada, u2, lx, lz, from)
	local sent = notifies(ada)
	local last = sent[#sent]
	local matched = false
	for _, pattern in patterns do
		if last and string.find(last.args[1], pattern, 1, true) then
			matched = true
		end
	end
	check(result ~= nil and result.Spot == nil and #sent == before + 1 and matched, `{label} ({last and last.args[1] or "aucun message"})`)
end
refused("hors de sa boutique (au-delà de Bounds) : refusé", 6, 45, { "inside your own shop" })
refused("au bord de Bounds (marge) : refusé", 31.5, 0, { "inside your own shop" })
refused("trop loin du personnage : refusé", 6, 30, { "Get closer" }, floorPoint(ada, 6, 10) + Vector3.new(0, 3, 0))
refused("dans un meuble (comptoir solide) : refusé", 10, 10, { "No room here", "on the floor" })
refused("sur un meuble bas (son dessus n'est pas le sol) : refusé", -10, 10, { "No room here", "on the floor" })
refused("contre un présentoir : refusé", -24, -29, { "No room here" })
refused("à 2 studs du colis déjà posé : refusé", 7.5, 21, { "No room here" })
refused("sur le tapis de course (1 stud de haut : pas le sol) : refusé", -20, 27.5, { "on the floor" })
refused("à côté du tapis de course : refusé (le volume du colis le touche)", -17.5, 30, { "No room here" })
-- Point visé chez Bob (sa boutique) : jamais chez un autre.
local bob = join("Bob", nil)
advance(1.5)
local bobPoint = floorPoint(bob, 6, 20)
clearLog()
moveTo(ada, bobPoint + Vector3.new(1, 3, 1))
advance(0.05)
fireAs(ada, "PlaceBox", u2, bobPoint)
flush()
check(dataOf(ada).Boxes[u2].Spot == nil and #notifies(ada, "inside your own shop") >= 1, "point dans la boutique de Bob : refusé")
-- Colis inconnu, déjà posé : sans message.
local n = #notifies(ada)
advance(0.6)
fireAs(ada, "PlaceBox", "pas-un-colis", floorPoint(ada, 12, 20))
fireAs(ada, "PlaceBox", uid, floorPoint(ada, 12, 20))
flush()
check(#notifies(ada) == n and near(dataOf(ada).Boxes[uid].Spot.X, 6, 0.02), "colis inconnu ou déjà posé : refusé sans message, rien ne bouge")
-- Mains prises (un autre colis porté, juste avant son rangement : la boucle passe 4 fois par seconde).
standNear(ada, floorPoint(ada, 12, 20))
advance(0.6)
CarryService.Give(ada, npcBox("Common", "Z1_Banane"))
fireAs(ada, "PlaceBox", u2, floorPoint(ada, 12, 20))
flush()
check(dataOf(ada).Boxes[u2].Spot == nil, "porte déjà un colis : refusé")
CarryService.Consume(ada)
-- Forme : Net refuse un point qui n'est pas un Vector3.
advance(0.6)
fireAs(ada, "PlaceBox", u2, "pas un point")
flush()
check(dataOf(ada).Boxes[u2].Spot == nil, "point mal formé : refusé par Net")

section("pose acceptée ailleurs, double clic")
standNear(ada, floorPoint(ada, 12, 20))
advance(0.6)
fireAs(ada, "PlaceBox", u2, floorPoint(ada, 12, 20))
fireAs(ada, "PlaceBox", u2, floorPoint(ada, 18, 20))
flush()
local b2 = dataOf(ada).Boxes[u2]
check(b2.Spot ~= nil and near(b2.Spot.X, 12, 0.02), "deux PlaceBox d'affilée : posé une fois, au premier point")
local count = 0
for _, child in shopOf(ada):GetChildren() do
	if child.Name == "FloorBox" and child:GetAttribute("BoxUid") == u2 then
		count += 1
	end
end
check(count == 1, "un seul FloorBox pour ce colis")

section("trop de colis posés")
local uids = {}
for i = 3, Unbox.MaxPlacedBoxes do
	local u = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
	local p = placeAt(ada, u, -24 + 6 * (i - 3), 16)
	check(p and p.Spot ~= nil, `colis {i} posé`)
	table.insert(uids, u)
end
local extra = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
local before = #notifies(ada, "Too many boxes on the floor")
local e = placeAt(ada, extra, 18, 26)
check(e.Spot == nil and #notifies(ada, "Too many boxes on the floor") == before + 1, `{Unbox.MaxPlacedBoxes + 1}e colis posé : refusé, « Too many boxes on the floor… »`)

section("sans boutique")
local data = newProfile()
local players = {}
for i = 1, 4 do
	players[i] = join("P" .. i, nil)
end
advance(1.5)
local late = join("Late", nil)
advance(1.5)
check(shopOf(late) == nil, "7e joueur : pas de boutique")
dataOf(late).Boxes["lateBox"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", At = 0 }
local before2 = #notifies(late, "You don't have a shop yet")
fireAs(late, "PlaceBox", "lateBox", Vector3.new(0, 0.3, 0))
flush()
check(dataOf(late).Boxes.lateBox.Spot == nil and #notifies(late, "You don't have a shop yet") == before2 + 1, "sans boutique : refusé, « You don't have a shop yet… »")

section("boutique tournée de 90° : même point dans son repère")
leave(late)
leave(bob)
advance(0.5)
-- Late part (sans boutique), puis Bob : sa boutique (la 2, tournée) se libère, Cy la prend.
local cy = join("Cy", nil)
advance(1.5)
check(shopOf(cy) == SHOPS[2].model, "Cy a la boutique 2 (tournée de 90°)")
local uc = bringBox(cy, "Common", "Z1_Banane", "Standard", 1)
local bc = placeAt(cy, uc, 6, 20)
check(bc and bc.Spot and near(bc.Spot.X, 6, 0.02) and near(bc.Spot.Z, 20, 0.02), "Spot = (6, 20) dans le repère de la boutique tournée")
local mc = floorBoxOf(cy, uc)
local expected = SHOPS[2].S.origin * Vector3.new(6, 0.3, 20)
check(mc and (mc:GetPivot().Position - expected).Magnitude < 0.05, "FloorBox au bon point du monde")

summary("scénario place")
