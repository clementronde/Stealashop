-- Banc a210 (vague 63, L-205 et L-206) : pièces WeldTo des auras de Clément clonées et soudées, mouvement Spin, Orbit,
-- Tumble, Period côté client sans fuite, modèle lu avant le Decal, Features.NewAuras (boutique, migration).
-- Collé après la mise en place du banc a20 (copie a149), à la place de ses scénarios.
local Features = requireModule(ReplicatedStorage.Shared.Config.Features, "server")
local Zones = requireModule(ReplicatedStorage.Shared.Config.Zones, "server")
local NEW = Features.NewAuras == true
print(`\n== X. a210 : Features.NewAuras = {tostring(NEW)}`)

-- Classes et propriétés absentes du faux Roblox d'a20 (ajout pur, comme a78).
ISA.Beam = ISA.Beam or {}
PROPS.Beam = PROPS.Beam or { Enabled = true, Attachment0 = NONE, Attachment1 = NONE }
ISA.Weld = { "JointInstance" }
PROPS.Weld = { Part0 = NONE, Part1 = NONE, C0 = CFrame.identity, C1 = CFrame.identity, Enabled = true }
PROPS.Part.LocalTransparencyModifier = 0 -- même table pour MeshPart
CFrame.fromAxisAngle = CFrame.fromAxisAngle or function(_axis, angle)
	return CFrame.Angles(0, angle, 0) -- faux : la rotation suffit, l'axe est ignoré
end

local function cf(x, y, z)
	return CFrame.new(x, y, z)
end
local function v(x, y, z)
	return Vector3.new(x, y, z)
end
local function nearV(a, b)
	return near(a.X, b.X, 1e-4) and near(a.Y, b.Y, 1e-4) and near(a.Z, b.Z, 1e-4)
end
local function piecesOf(character)
	local out = {}
	for _, child in character:GetChildren() do
		if hasTag(child, "CosmeticPiece") then
			out[child.Name] = child
		end
	end
	return out
end
local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

---------------------------------------------------------------- X. Pièces WeldTo
-- Aura testée : une aura de la boutique, avec son modèle FX_ ; Decal homonyme aussi livré (ignoré).
local AURA = if NEW then "Chained" else "Galaxy"
local def = Cosmetics.ById[AURA]
do
	local assets = ReplicatedStorage:FindFirstChild("Assets") or new("Folder", { Name = "Assets" }, ReplicatedStorage)
	local fx = assets:FindFirstChild("FX") or new("Folder", { Name = "FX" }, assets)
	new("Decal", { Name = def.Texture, Texture = "rbxassetid://5005" }, fx)
	local m = new("Model", { Name = def.Texture })
	local mRoot = new("Part", { Name = "HumanoidRootPart", CFrame = cf(0, 3.01, 0), Size = v(2, 2, 1), Anchored = true, Transparency = 1 }, m)
	new("Part", { Name = "LeftFoot", CFrame = cf(-0.5, 0.3, 0), Size = v(1, 0.6, 1), Anchored = true, Transparency = 1 }, m)
	local mTorso = new("Part", { Name = "UpperTorso", CFrame = cf(0, 4, 0), Anchored = true, Transparency = 1 }, m)
	new("Part", { Name = "Head", CFrame = cf(0, 5.5, 0), Size = v(1, 1, 1), Anchored = true, Transparency = 1 }, m)
	local core = new("Attachment", { Name = "A_Core" }, mTorso)
	new("ParticleEmitter", { Name = "Glow", Rate = 10 }, core)
	-- Auréole soudée à la tête, avec une lumière et un rayon vers le torse.
	local halo = new("MeshPart", { Name = "Halo", CFrame = cf(0, 6.7, 0), Size = v(2, 0.2, 2), Anchored = true }, m)
	halo:SetAttribute("WeldTo", "Head")
	new("PointLight", { Name = "HaloLight" }, halo)
	local tip = new("Attachment", { Name = "HaloTip" }, halo)
	new("Beam", { Name = "HaloBeam", Attachment0 = tip, Attachment1 = core }, tip)
	new("ParticleEmitter", { Name = "HaloSparks", Rate = 6 }, halo)
	-- Chaînes (dossier) soudées au HumanoidRootPart, qui tournent sur elles-mêmes.
	local chains = new("Folder", { Name = "Chains" }, m)
	local c1 = new("MeshPart", { Name = "Chain_1", CFrame = cf(0, 4, 0), Size = v(3, 0.4, 3), Anchored = true }, chains)
	c1:SetAttribute("WeldTo", "HumanoidRootPart")
	c1:SetAttribute("Spin", 0.55)
	local c2 = new("MeshPart", { Name = "Chain_2", CFrame = cf(0, 3, 0), Size = v(3, 0.4, 3), Anchored = true }, chains)
	c2:SetAttribute("WeldTo", "HumanoidRootPart")
	c2:SetAttribute("Spin", -0.45)
	-- Flaque au sol.
	local puddle = new("MeshPart", { Name = "Puddle", CFrame = cf(0, 0.05, 0), Size = v(4.6, 0.1, 4.6), Anchored = true }, m)
	puddle:SetAttribute("WeldTo", "HumanoidRootPart")
	-- Chaise (Model) qui tourne autour du joueur et culbute ; un enfant WeldTo vient avec elle.
	local chair = new("Model", { Name = "Chair_1" })
	local seat = new("Part", { Name = "Seat", CFrame = cf(3, 2, 0), Size = v(1, 0.2, 1), Anchored = true }, chair)
	local leg = new("Part", { Name = "Leg", CFrame = cf(3, 1.5, 0), Size = v(0.2, 1, 0.2), Anchored = true }, chair)
	leg:SetAttribute("WeldTo", "Head")
	chair.PrimaryPart = seat
	chair:SetAttribute("WeldTo", "HumanoidRootPart")
	chair:SetAttribute("Orbit", 2.5)
	chair:SetAttribute("Tumble", 1)
	chair.Parent = m
	-- Bulle de la flaque.
	local bubble = new("MeshPart", { Name = "Bubble_1", CFrame = cf(1, 0.2, 0), Size = v(0.5, 0.5, 0.5), Anchored = true }, m)
	bubble:SetAttribute("WeldTo", "HumanoidRootPart")
	bubble:SetAttribute("Period", 2)
	-- Pièce soudée à une pièce que le personnage n'a pas : ignorée.
	local ghost = new("Part", { Name = "Ghost", CFrame = cf(0, 3, 0), Anchored = true }, m)
	ghost:SetAttribute("WeldTo", "Tail")
	m.Parent = fx:FindFirstChild("Auras") or new("Folder", { Name = "Auras" }, fx)

	-- Perso d'Alice : HumanoidRootPart 2 × 2 × 1, HipHeight 1,8 (sol à 2,8 studs du centre ; mannequin : 3,01).
	local char = P1.Character
	local root = char.HumanoidRootPart
	root.Size = v(2, 2, 1)
	char.Humanoid.HipHeight = 1.8
	local torso = new("Part", { Name = "UpperTorso", CFrame = root.CFrame * cf(0, 1, 0) }, char)
	local head = new("Part", { Name = "Head", CFrame = root.CFrame * cf(0, 2.5, 0) }, char)
	CosmeticService.Grant(P1, AURA)
	CosmeticService.Equip(P1, AURA)
	step(0.1)

	local got = piecesOf(char)
	local cHalo, cC1, cC2, cPuddle, cChair, cBubble = got.Halo, got.Chain_1, got.Chain_2, got.Puddle, got.Chair_1, got.Bubble_1
	check(cHalo ~= nil and cC1 ~= nil and cC2 ~= nil and cPuddle ~= nil and cChair ~= nil and cBubble ~= nil and count(got) == 6,
		`X1 {AURA} : 6 pièces WeldTo clonées dans le perso (auréole, 2 chaînes d'un dossier, flaque, chaise, bulle)`)
	check(got.Ghost == nil and got.Leg == nil and char:FindFirstChild("Ghost", true) == nil,
		"X2 WeldTo vers une pièce absente (Tail) ignoré ; enfant WeldTo d'un Model soudé : pas cloné à part")
	local weld = cHalo and cHalo:FindFirstChild("CosmeticWeld")
	check(weld ~= nil and weld.ClassName == "Weld" and weld.Part0 == head and weld.Part1 == cHalo and nearV(weld.C0.Position, v(0, 1.2, 0)),
		"X3 auréole soudée à la tête du perso, CFrame relatif gardé (1,2 stud au-dessus)")
	check(cHalo and cHalo.Anchored == false and cHalo.CanCollide == false and cHalo.CanQuery == false and cHalo.CanTouch == false and cHalo.Massless == true,
		"X4 pièce décrochée, sans collision, requête, contact ni masse")
	local w1 = cC1 and cC1:FindFirstChild("CosmeticWeld")
	check(w1 ~= nil and w1.Part0 == root and nearV(w1.C0.Position, v(0, 0.99, 0)), "X5 chaîne soudée au HumanoidRootPart à sa hauteur (pas au sol : pas recalée)")
	local wp = cPuddle and cPuddle:FindFirstChild("CosmeticWeld")
	check(wp ~= nil and nearV(wp.C0.Position, v(0, 0.05 - 2.8, 0)), "X6 flaque au sol : 0,05 stud au-dessus des pieds d'un perso plus petit")
	local wChair = cChair and cChair:FindFirstChild("CosmeticWeld", true)
	local cSeat, cLeg = cChair and cChair:FindFirstChild("Seat"), cChair and cChair:FindFirstChild("Leg")
	local glue = cLeg and cLeg:FindFirstChildWhichIsA("WeldConstraint")
	check(wChair ~= nil and wChair.Parent == cSeat and wChair.Part1 == cSeat and near(wChair.C0.Position.X ^ 2 + wChair.C0.Position.Z ^ 2, 9, 1e-3) and near(wChair.C0.Position.Y, -1.01, 1e-4)
		and glue ~= nil and glue.Part0 == cSeat and glue.Part1 == cLeg and cLeg.Anchored == false,
		"X7 Model soudé par son PrimaryPart (à 3 studs de l'axe, déjà en orbite), ses autres pièces collées au PrimaryPart")
	check(cHalo:GetAttribute("CosmeticFx") == "Aura" and cHalo:GetAttribute("CosmeticId") == AURA and cChair:GetAttribute("CosmeticFx") == "Aura"
		and hasTag(cHalo, "CosmeticAura") and hasTag(cSeat, "CosmeticAura") and cHalo.HaloSparks:GetAttribute("FullRate") == 6,
		"X8 clones marqués CosmeticFx et CosmeticId, pièces taggées CosmeticAura, FullRate des émetteurs")
	local cCore = torso:FindFirstChild("A_Core")
	local beam = cHalo.HaloTip:FindFirstChild("HaloBeam")
	check(cCore ~= nil and beam ~= nil and beam.Attachment0 == cHalo.HaloTip and beam.Attachment1 == cCore,
		"X9 Beam de l'auréole relié à sa copie et à la copie de l'Attachment du torse")
	check(#aurasOf(char) == 0 and halo.Anchored == true and halo.Parent == m and c1.Parent == chains,
		"X10 modèle FX_ lu avant le Decal homonyme (pas d'effet V0) ; modèle de Clément intact")
	check(not scriptsIn(char), "X11 aucun script dans le perso")

	-- Client : une seule boucle pour toutes les pièces.
	local n, on = CosCtrl.PieceCount()
	check(n == 6 and on, "X12 client : 6 pièces suivies, boucle de mouvement branchée")
	local look0 = w1.C0.LookVector
	local chair0 = wChair.C0.Position
	local size0 = cBubble.Size
	step(1)
	local chairNow = wChair.C0.Position
	check(nearV(w1.C0.Position, v(0, 0.99, 0)) and not nearV(w1.C0.LookVector, look0),
		"X13 Spin : la chaîne tourne sur elle-même, à la même place")
	check(not nearV(chairNow, chair0) and near(chairNow.X ^ 2 + chairNow.Z ^ 2, 9, 1e-3) and near(chairNow.Y, -1.01, 1e-4),
		"X14 Orbit : la chaise tourne autour de l'axe du HumanoidRootPart, même rayon, même hauteur")
	local sizes, hidden = {}, false
	for _ = 1, 20 do
		step(0.1)
		table.insert(sizes, cBubble.Size.X)
		hidden = hidden or cBubble.LocalTransparencyModifier == 1
	end
	local grew = false
	for i = 2, #sizes do
		grew = grew or sizes[i] > sizes[i - 1]
	end
	check(grew and hidden and math.min(table.unpack(sizes)) < size0.X, "X15 Period : la bulle gonfle, éclate (cachée), repart")

	-- Loin de la caméra : plus de mouvement.
	setCamera(v(5000, 8, 5000))
	step(0.1)
	local frozen = wChair.C0.Position
	step(0.5)
	check(nearV(wChair.C0.Position, frozen), "X16 au-delà de PieceMotion.MaxDistance : pièces figées")
	setCamera(v(-14, 8, -8))

	-- VISUAL EFFECTS OFF : pièces cachées en local, lumière éteinte, puis rallumées.
	P1:SetAttribute("VfxEnabled", false)
	step(0.6)
	local frozenOff = wChair.C0.Position
	step(0.3)
	check(cHalo.LocalTransparencyModifier == 1 and cSeat.LocalTransparencyModifier == 1 and cHalo.HaloLight.Enabled == false and beam.Enabled == false
		and nearV(wChair.C0.Position, frozenOff), "X17 OFF : pièces cachées, lumière et rayon éteints, mouvement arrêté")
	P1:SetAttribute("VfxEnabled", true)
	step(0.6)
	check(cHalo.LocalTransparencyModifier == 0 and cSeat.LocalTransparencyModifier == 0 and cHalo.HaloLight.Enabled == true,
		"X18 ON : pièces rendues, lumière rallumée")

	-- Aura retirée : pièces détruites, boucle débranchée ; remise : tout revient une seule fois.
	CosmeticService.Unequip(P1, "Aura")
	step(0.1)
	n, on = CosCtrl.PieceCount()
	check(count(piecesOf(char)) == 0 and n == 0 and not on and torso:FindFirstChild("A_Core") == nil, "X19 aura retirée : pièces retirées, client sans pièce ni boucle")
	CosmeticService.Equip(P1, AURA)
	step(0.1)
	n, on = CosCtrl.PieceCount()
	check(count(piecesOf(char)) == 6 and n == 6 and on, "X20 aura remise : 6 pièces, une seule fois")
	-- Changement d'aura : les pièces de l'ancienne partent.
	local other = if NEW then "Shine" else "Spark"
	CosmeticService.Grant(P1, other)
	CosmeticService.Equip(P1, other)
	step(0.1)
	n, on = CosCtrl.PieceCount()
	check(count(piecesOf(char)) == 0 and n == 0 and not on, `X21 changement vers {other} : pièces retirées, boucle débranchée`)
	CosmeticService.Equip(P1, AURA)
	step(0.1)
	-- Mort : tout est retiré du corps.
	local hum = char.Humanoid
	hum.Health = 0
	hum.Died:Fire()
	step(0.1)
	n, on = CosCtrl.PieceCount()
	check(count(piecesOf(char)) == 0 and n == 0 and not on, "X22 à la mort : pièces retirées, boucle débranchée")
end

---------------------------------------------------------------- Y. Porteur qui part
do
	local id = if NEW then "Angel" else "Galaxy"
	local m = new("Model", { Name = Cosmetics.ById[id].Texture })
	new("Part", { Name = "HumanoidRootPart", CFrame = cf(0, 3.01, 0), Size = v(2, 2, 1), Anchored = true }, m)
	new("Part", { Name = "Head", CFrame = cf(0, 5.5, 0), Anchored = true }, m)
	local ring = new("MeshPart", { Name = "Ring", CFrame = cf(0, 6.7, 0), Anchored = true }, m)
	ring:SetAttribute("WeldTo", "Head")
	ring:SetAttribute("Spin", 1)
	if id ~= AURA then
		m.Parent = ReplicatedStorage.Assets.FX.Auras
	end
	PRESETS["Player_303"] = {
		Cosmetics = { Auras = { id }, Trails = {}, EquippedAura = id },
	}
	local P3 = new("Player", { Name = "Carol", UserId = 303, DisplayName = "Carol" })
	local char3 = makeCharacter(P3, Vector3.new(-14, 3, -30))
	new("Part", { Name = "Head", CFrame = char3.HumanoidRootPart.CFrame * cf(0, 2.5, 0) }, char3)
	P3.Parent = Players
	Players.PlayerAdded:Fire(P3)
	step(0.2)
	local n, on = CosCtrl.PieceCount()
	check(n >= 1 and on, "Y1 aura d'un autre joueur : ses pièces suivies par le client")
	char3:Destroy()
	P3.Parent = nil
	step(0.1)
	n, on = CosCtrl.PieceCount()
	check(n == 0 and not on, "Y2 porteur parti (perso détruit) : pièces oubliées, boucle débranchée")
end

---------------------------------------------------------------- Z. Features.NewAuras
do
	local ids = {}
	for _, a in Cosmetics.Auras do
		table.insert(ids, a.Id)
	end
	if not NEW then
		check(table.concat(ids, ",") == "Spark,Flame,Lightning,Plasma,Galaxy,Royal", "Z1 NewAuras = false : la boutique d'aujourd'hui (6 auras)")
		check(Cosmetics.ById.Shine == nil and Cosmetics.ById.Spark.Retired == nil and Cosmetics.Current("Spark") == "Spark",
			"Z2 NewAuras = false : aucune nouvelle aura dans ById, rien de retiré, Current ne change rien")
		PRESETS["Player_404"] = { Cosmetics = { Auras = { "Spark", "Royal" }, Trails = {}, EquippedAura = "Royal" } }
	else
		check(table.concat(ids, ",") == "Shine,Fire,Storm,Poison,Tornado,Angel,Demon,Chained", "Z1 NewAuras = true : les 8 auras de Clément, dans son ordre")
		local mult, price, okOrder = {}, {}, true
		for i, a in Cosmetics.Auras do
			table.insert(mult, a.Multiplier)
			table.insert(price, a.Price)
			okOrder = okOrder and a.Order == i and (i == 1 or (a.Multiplier > Cosmetics.Auras[i - 1].Multiplier and a.Price > Cosmetics.Auras[i - 1].Price))
		end
		check(okOrder and mult[1] == 2 and mult[8] == 20 and price[1] == 500 and price[8] == 8e9, "Z2 ×2 à ×20, 500 $ à 8 B, croissants")
		check(Cosmetics.ById.Spark ~= nil and Cosmetics.ById.Spark.Retired == true and Cosmetics.Current("Royal") == "Chained" and Cosmetics.Current("Shine") == "Shine",
			"Z3 anciennes auras gardées dans ById (Retired), Current donne la remplaçante")
		PRESETS["Player_404"] = { Cosmetics = { Auras = { "Spark", "Royal", "Shine" }, Trails = {}, EquippedAura = "Royal" } }
	end
	-- Kits de Config/Zones : mêmes dégâts conseillés (donc mêmes PV de vitrine) avec ou sans NewAuras.
	check(Zones[2].AdvisedDamage / Zones[1].AdvisedDamage > 0 and Cosmetics.ById[Zones[6].Kit[2]].Multiplier == 20 and Cosmetics.ById[Zones[4].Kit[2]].Multiplier == 5,
		"Z4 kits de Config/Zones lus (anciens Id), multiplicateurs inchangés")
	local P4 = new("Player", { Name = "Dan", UserId = 404, DisplayName = "Dan" })
	makeCharacter(P4, Vector3.new(-14, 3, -40))
	P4.Parent = Players
	Players.PlayerAdded:Fire(P4)
	step(0.2)
	local data4 = DataService.Get(P4)
	if not NEW then
		check(table.concat(data4.Cosmetics.Auras, ",") == "Spark,Royal" and data4.Cosmetics.EquippedAura == "Royal" and CosmeticService.GetAuraMultiplier(P4) == 20,
			"Z5 NewAuras = false : sauvegarde inchangée (Spark, Royal équipée ×20)")
	else
		check(table.concat(data4.Cosmetics.Auras, ",") == "Shine,Chained" and data4.Cosmetics.EquippedAura == "Chained",
			"Z5 migration : Spark → Shine (sans doublon), Royal → Chained, l'équipée suit")
		check(CosmeticService.GetAuraMultiplier(P4) == 20 and P4:GetAttribute("EquippedAura") == "Chained" and P4:GetAttribute("OwnedCosmetics") == "Shine,Chained",
			"Z6 même multiplicateur après migration (×20), attributs à jour")
		check(CosmeticService.Grant(P4, "Flame") and table.find(data4.Cosmetics.Auras, "Fire") ~= nil and table.find(data4.Cosmetics.Auras, "Flame") == nil
			and CosmeticService.Owns(P4, "Galaxy") == false and CosmeticService.Owns(P4, "Royal") == true,
			"Z7 Grant d'une ancienne aura (récompense de l'Index) : donne la remplaçante ; Owns lit l'Id à jour")
	end
end
