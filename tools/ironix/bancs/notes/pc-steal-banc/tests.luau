---------------------------------------------------------------- pc-steal
-- Invite « Steal » d'un objet sorti d'un colis : sa portée doit rester GrabMaxDistance − 0,5 (7,5 studs),
-- même quand l'objet est vu petit (sortie à 0,2 de sa taille, ShelfOpenController) puis remis à sa taille,
-- et pour un objet agrandi par une mutation (Huge ×2, Colossal ×3).
print("== pc-steal : portée de l'invite de l'objet sorti")
local Heist = requireModule(HeistModule)
taskLib.spawn(Heist.Start)
advance(0.3)
local want = math.max(Balance.Heist.GrabMaxDistance - 0.5, 1)
check(near(want, 7.5), "portée attendue 7,5 studs (GrabMaxDistance 8 − 0,5)")

-- Objet comme le voit le client : déjà à `base` (mutation de taille, serveur), réduit à `seen` quand le
-- tag arrive (sortie en cours), puis rendu à `base`.
local function popItem(n, base, seen, attrs)
	local m = newInstance("Model")
	m.Name = "ITM_Test"
	local p = slotPos(n)
	local body = inst("Part", m, "Body", { CFrame = CFrame.new(p + Vector3.new(0, 0.75, 0)), Size = Vector3.new(1.5, 1.5, 1) })
	m.PrimaryPart = body
	m.WorldPivot = CFrame.new(p)
	m:SetAttribute("SlotId", "STORE_Test:" .. n)
	m:SetAttribute("ItemId", ITEM_ID)
	m:SetAttribute("Tier", "Standard")
	for k, v in attrs or {} do
		m:SetAttribute(k, v)
	end
	m:ScaleTo(base)
	m:ScaleTo(seen)
	CollectionService:AddTag(m, "ShelfItem")
	m.Parent = boxesF
	advance(0.1)
	local prompt = body:FindFirstChild("ShelfItemPrompt")
	check(prompt ~= nil, `objet {n} : invite « Steal » posée`)
	-- Retour à la taille comme ShelfOpenController (Back Out : un peu au-dessus, puis la taille).
	for _, k in { 0.5, 0.9, 1.08, 1 } do
		m:ScaleTo(base * k)
	end
	advance(0.1)
	return m, prompt
end

local _, p1 = popItem(1, 1, 1 * 0.2)
local d1 = if p1 then p1.MaxActivationDistance else -1
check(near(d1, want), `objet normal vu à 0,2 puis 1 : portée {d1} studs (attendu {want}, le bug donnait 37,5)`)

local _, p2 = popItem(2, 1, 1)
local d2 = if p2 then p2.MaxActivationDistance else -1
check(near(d2, want), `objet normal vu à sa taille : portée {d2} studs`)

local m3, p3 = popItem(3, 2, 2 * 0.2, { MutationSize = "Huge" })
local d3 = if p3 then p3.MaxActivationDistance else -1
check(near(d3, want), `objet Huge (×2) vu à 0,4 puis 2 : portée {d3} studs`)

local m4, p4 = popItem(4, 3, 3 * 0.2, { MutationSize = "Colossal" })
local d4 = if p4 then p4.MaxActivationDistance else -1
check(near(d4, want), `objet Colossal (×3) vu à 0,6 puis 3 : portée {d4} studs`)

m3:ScaleTo(6)
m4:ScaleTo(0.5)
local d5 = if p3 then p3.MaxActivationDistance else -1
local d6 = if p4 then p4.MaxActivationDistance else -1
check(near(d5, want) and near(d6, want), `toute autre échelle : portée {d5} et {d6} studs`)
