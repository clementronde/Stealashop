--!nocheck
-- a220 (L-210 point 3) : le meuble casse sous un objet trop gros (Reveal/Shelf, Config/Reveal.Shelf), sur la mise en
-- place du banc a204 (copie a220-banc/autres-bancs/a204 : head.client.luau monte Reveal/Shelf).
--   K pièces du meuble : planche du dessous intacte, planche du dessus et produit cassés, montant intact à ×2 ;
--     sol, mur, pilier, pièce invisible, NoShelfBreak, colis jamais ; morceaux qui tombent, s'effacent ; son une fois ;
--     meuble remis après RestoreAfter
--   G grand objet (×5) : le montant casse aussi, le mur non
--   N objet qui tient (×1) : rien
--   W appareil faible : LowEndPieces morceaux au plus, toutes les pièces touchées cachées
local RevealCfg = sharedModule("Config/Reveal", "client")
local CFG = RevealCfg.Shelf

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(65, 3, -40))
Workspace.CurrentCamera = CAMERA
CAMERA.CameraType = Enum.CameraType.Custom
startClient(alice)
local Shatter = clientModule("ShatterController")
local Shelf = requireModule(CONTROLLERS.Reveal.Shelf, "client")

make("Sound", { Name = CFG.Sound, SoundId = "rbxassetid://7" }, SOUNDS_FOLDER)

local store = STORES[3]
local slotPos = SLOT3.WorldCFrame.Position
local P = {}
local function part(name, size, offset, props)
	local p = make("Part", { Name = name, Anchored = true, Size = size, CFrame = CFrame.new(slotPos + offset) }, store)
	for k, v in props or {} do
		p[k] = v
	end
	P[name] = p
	return p
end
-- Objet ITEM_A : 2 × 3 × 2 studs à la taille 1.
part("PlankLow", Vector3.new(6, 0.3, 2), Vector3.new(0, -0.15, 0))
part("PlankHigh", Vector3.new(6, 0.3, 2), Vector3.new(0, 4, 0))
part("Product", Vector3.new(0.6, 0.8, 0.6), Vector3.new(0.5, 4.55, 0), { CanCollide = false })
part("Upright", Vector3.new(0.2, 5, 2), Vector3.new(3.2, 2, 0))
part("Floor", Vector3.new(30, 1, 28), Vector3.new(0, -1, 0))
part("Wall", Vector3.new(28, 8, 0.4), Vector3.new(0, 3, 1.5))
part("Pillar", Vector3.new(1, 11, 1), Vector3.new(-2, 4, 0))
part("Ghost", Vector3.new(2, 2, 2), Vector3.new(0, 4, -0.5), { Transparency = 1 })
part("Kept", Vector3.new(1, 1, 1), Vector3.new(-1, 4.6, 0)):SetAttribute("NoShelfBreak", true)
local decal = make("Decal", { Name = "Label" }, P.PlankHigh)

local function reveal(scale, class, id)
	NET.Server.RevealStarted:FireAll(alice, store.Name, store.Name .. "/03", ITEM_A.Id, "Rare", "", 50, scale, class, id)
	flush()
end
local function pieces(name)
	local n = 0
	local f = Workspace:FindFirstChild("_RevealFX")
	if f then
		for _, c in f:GetChildren() do
			if c.Name == name then
				n += 1
			end
		end
	end
	return n
end
local function hidden(name)
	return P[name].LocalTransparencyModifier == 1
end
local function played(name)
	local n = 0
	for _, place in { SoundService, Workspace } do
		for _, d in place:GetDescendants() do
			if d:IsA("Sound") and d.Name == name then
				n += 1
			end
		end
	end
	return n
end
local function advanceUntil(cond, limit)
	local start = now()
	while not cond() and now() - start < limit do
		advance(1 / 30)
	end
	return now() - start
end

section("K. Objet ×2 : le dessus du rayon casse")
local picked = Shelf.Pick(store, CFrame.lookAt(slotPos, slotPos + Vector3.new(0, 0, 1)), Vector3.new(2, 3, 2), 2)
local names = {}
for _, p in picked do
	names[p.Name] = true
end
check(names.PlankHigh and names.Product and not names.PlankLow and not names.Upright, "K1 Pick ×2 : planche du dessus et produit, pas la planche du dessous ni le montant")
check(not names.Floor and not names.Wall and not names.Pillar and not names.Ghost and not names.Kept and not names.ShelfBox, "K2 Pick : ni sol, mur, pilier, pièce invisible, NoShelfBreak, colis")
reveal(2, "Small", "k1")
local soundsBefore = played(CFG.Sound)
advance(1.2)
check(not hidden("PlankHigh"), "K3 rien de cassé avant le Grow")
local seen = 0
advanceUntil(function()
	seen = math.max(seen, pieces("PlankHigh"))
	return hidden("PlankHigh")
end, 4)
seen = math.max(seen, pieces("PlankHigh"))
check(hidden("PlankHigh") and decal.LocalTransparencyModifier == 1, "K4 planche du dessus cachée en local, décalque compris")
check(seen == 1, "K5 un morceau de la planche part (" .. seen .. ")")
advanceUntil(function()
	return hidden("Product")
end, 3)
check(hidden("Product"), "K6 produit posé dessus cassé aussi")
check(not hidden("PlankLow") and not hidden("Upright") and not hidden("Wall") and not hidden("Floor") and not hidden("Pillar") and not hidden("Kept"), "K7 le reste intact")
check(BOX3.LocalTransparencyModifier == 1 and BOX3.Parent ~= nil, "K8 colis : seulement caché par la scène")
check(played(CFG.Sound) == soundsBefore + 1, "K9 son Shelf_Break joué une fois")
check(P.PlankHigh.CanCollide == true and P.PlankHigh.Transparency == 0, "K10 rien ne change sur la pièce elle-même (collision, transparence)")
local piece = Workspace._RevealFX:FindFirstChild("PlankHigh")
advance(0.5)
check(piece and not piece.CanCollide and piece.Anchored, "K11 morceau ancré, sans collision")
advance(CFG.Life + CFG.Fade + 0.2)
check(pieces("PlankHigh") == 0 and pieces("Product") == 0, "K12 morceaux effacés puis détruits")
NET.Server.RevealEnded:FireAll("k1")
flush()
check(hidden("PlankHigh"), "K13 fin de la scène : le meuble reste cassé")
advance(CFG.RestoreAfter)
check(not hidden("PlankHigh") and not hidden("Product"), "K14 meuble remis après RestoreAfter")
check(decal.LocalTransparencyModifier ~= 1, "K14b décalque remis")
check(next(Shelf.GetState()) == nil, "K15 état vidé")

section("G. Objet ×5 : le montant casse, pas le mur")
reveal(5, "Large", "g1")
advanceUntil(function()
	return hidden("Upright")
end, 6)
check(hidden("Upright") and hidden("PlankHigh"), "G1 montant et planche cassés")
check(not hidden("Wall") and not hidden("Pillar") and not hidden("Floor") and not hidden("PlankLow"), "G2 mur, pilier, sol, planche du dessous intacts")
NET.Server.RevealEnded:FireAll("g1")
flush()
advance(CFG.RestoreAfter + 1)
check(not hidden("Upright") and not hidden("PlankHigh"), "G3 remis")

section("N. Objet ×1 : il tient, rien ne casse")
reveal(1, "Small", "n1")
advance(5)
check(not hidden("PlankHigh") and not hidden("Product") and next(Shelf.GetState()) == nil, "N1 rien de cassé")
NET.Server.RevealEnded:FireAll("n1")
flush()
advance(1)

section("W. Appareil faible")
for i = 1, 10 do
	part("Can" .. i, Vector3.new(0.4, 0.6, 0.4), Vector3.new(-2.4 + i * 0.45, 4.45, 0.5), { CanCollide = false })
end
Shatter.low = true
reveal(2, "Small", "w1")
advanceUntil(function()
	return hidden("Can10") and hidden("Can1") and hidden("PlankHigh")
end, 6)
local flying = 0
for _, c in Workspace._RevealFX:GetChildren() do
	if c:IsA("BasePart") and (string.sub(c.Name, 1, 3) == "Can" or c.Name == "PlankHigh" or c.Name == "Product") then
		flying += 1
	end
end
local allHidden = true
for i = 1, 10 do
	allHidden = allHidden and hidden("Can" .. i)
end
check(allHidden and hidden("PlankHigh"), "W1 toutes les pièces touchées cachées")
check(flying <= CFG.LowEndPieces and flying > 0, "W2 au plus " .. CFG.LowEndPieces .. " morceaux (" .. flying .. ")")
Shatter.low = false
NET.Server.RevealEnded:FireAll("w1")
flush()
advance(CFG.RestoreAfter + 1)
check(not hidden("Can5"), "W3 remis")

summary("scénario shelf")
