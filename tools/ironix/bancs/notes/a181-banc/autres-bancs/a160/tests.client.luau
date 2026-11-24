-- Scénario client (a160) : vrai HubController sur un faux minimal. Entrée dans RewardsZone = UI_Rewards ouvert
-- une fois par entrée ; InviteZone = invitation ; réapparition dans une zone = rien ; cadeau qui flotte et tourne ;
-- étiquettes BB_ZoneLabel écrites depuis LabelKey (billboard ou parent), clé inconnue = texte gardé.
local Hub, HubZone = realHub()

local function folder(map) return { WaitForChild = function(_, n) return map[n] end } end
local opened, invited = 0, 0
local controllers = folder({
	RewardsController = { Open = function() opened += 1 end },
	InviteController = { Prompt = function() invited += 1 end },
})
local Find = { path = function(root, p) return root:FindFirstChild(p, true) end }
local Shared = folder({
	Config = folder({ Hub = Hub }),
	HubZone = HubZone,
	Contract = folder({ Find = Find }),
})

local Workspace = inst("Workspace", "Workspace")
Workspace.DescendantAdded = signal()
local tagged = {}
local added = {}
local CollectionService = {
	GetTagged = function(_, tag) return tagged[tag] or {} end,
	GetInstanceAddedSignal = function(_, tag) added[tag] = added[tag] or signal(); return added[tag] end,
}
local RunService = { RenderStepped = signal(), Heartbeat = signal(), IsStudio = function() return false end }
local me = inst("Player", "Me")
local Players = { LocalPlayer = me }
local services = { Players = Players, Workspace = Workspace, CollectionService = CollectionService, RunService = RunService,
	ReplicatedStorage = folder({ Shared = Shared }) }

-- Map : cadeau (Gift = Model, Zone taggée RewardsZone) et noob (Zone taggée InviteZone).
local function part(name, x)
	local p = inst("Part", name, { "BasePart" })
	p.CFrame = CFrame.new(x, 0.5, 0)
	p.Size = Vector3.new(10, 1, 10)
	return p
end
local giftModel = parent(inst("Model", "ENV_Hub_FreeGift"), Workspace)
local rewardsZone = parent(part("Zone", 0), giftModel)
local gift = parent(inst("Model", "Gift"), giftModel)
gift._pivot = CFrame.new(0, 2, 0)
function gift:GetPivot() return self._pivot end
function gift:PivotTo(c) self._pivot = c end
tagged.RewardsZone = { rewardsZone }
local noobModel = parent(inst("Model", "ENV_Hub_InviteNoob"), Workspace)
local inviteZone = parent(part("Zone", 100), noobModel)
tagged.InviteZone = { inviteZone }

-- Étiquettes.
local function billboard(holder, key, onParent)
	local bb = parent(inst("BillboardGui", "BB_ZoneLabel"), holder)
	local label = parent(inst("TextLabel", "Label"), bb)
	label.Text = "clement"
	if key then
		if onParent then holder:SetAttribute("LabelKey", key) else bb:SetAttribute("LabelKey", key) end
	end
	return bb, label
end
local stand = parent(inst("Model", "ENV_Hub_WeaponStall"), Workspace)
local _, weaponLabel = billboard(stand, "WeaponShop")
local _, giftLabel = billboard(giftModel, "FreeGift", true)
local _, unknownLabel = billboard(noobModel, "Nope")

local function character(x)
	if x == nil then me.Character = nil return end
	local char = inst("Model", "Me")
	local h = parent(inst("Humanoid", "Humanoid"), char)
	h.Health = 100
	local root = parent(inst("Part", "HumanoidRootPart", { "BasePart" }), char)
	root.Position = Vector3.new(x, 3, 0)
	me.Character = char
	return root
end
local function move(root, x) root.Position = Vector3.new(x, 3, 0) end

local HubController = load("client/Controllers/HubController.luau", {
	game = { GetService = function(_, n) return services[n] end },
	script = { Parent = controllers },
	require = function(m) return m end,
	warn = function() end,
})
HubController.Start()
local function tick() RunService.Heartbeat:Fire(Hub.Tick + 0.01) end

check(weaponLabel.Text == "WEAPONS", `E1 LabelKey sur le billboard ({weaponLabel.Text})`)
check(giftLabel.Text == "FREE!", `E2 LabelKey sur le parent ({giftLabel.Text})`)
check(unknownLabel.Text == "clement", "E3 clé inconnue : texte de Clément gardé")
local late, lateLabel = billboard(Workspace, nil)
Workspace.DescendantAdded:Fire(late)
late:SetAttribute("LabelKey", "PawnShop")
check(lateLabel.Text == "PAWN SHOP", `E4 étiquette arrivée plus tard, clé posée ensuite ({lateLabel.Text})`)

-- Réapparition dans la zone du cadeau : rien ne s'ouvre.
local root = character(0)
tick()
check(opened == 0, "Z1 personnage apparu dans la zone : UI_Rewards pas ouvert")
move(root, 50); tick()
move(root, 0); tick()
check(opened == 1, "Z2 entrée dans la zone du cadeau : UI_Rewards ouvert")
tick(); tick()
check(opened == 1, "Z3 on reste : une seule ouverture")
move(root, 6); tick()
check(opened == 1, "Z4 bord de la zone (marge de sortie) : rien")
move(root, 3); tick()
check(opened == 1, "Z5 retour au centre sans être sorti : rien")
move(root, 50); tick()
move(root, 1); tick()
check(opened == 2, "Z6 sortie puis retour : une nouvelle ouverture")
check(invited == 0, "Z7 pas d'invitation dans la zone du cadeau")
move(root, 100); tick()
check(invited == 1 and opened == 2, "I1 entrée dans la zone du noob : invitation")
tick()
check(invited == 1, "I2 on reste : une seule invitation")
character(nil); tick()
root = character(100); tick()
check(invited == 1, "I3 mort puis réapparition dans la zone : rien")

-- Cadeau : flotte et tourne autour de sa place.
local ys, angles = {}, {}
for i = 1, 20 do
	RunService.RenderStepped:Fire(Hub.Gift.FloatPeriod / 20)
	table.insert(ys, gift._pivot.Position.Y)
	table.insert(angles, gift._pivot.Angle)
end
local lo, hi = math.huge, -math.huge
for _, y in ys do lo = math.min(lo, y); hi = math.max(hi, y) end
check(math.abs(hi - (2 + Hub.Gift.FloatHeight)) < 0.05 and math.abs(lo - (2 - Hub.Gift.FloatHeight)) < 0.05, `G1 flotte de ±{Hub.Gift.FloatHeight} autour de 2 ({lo}..{hi})`)
check(math.abs(angles[20] - math.rad(Hub.Gift.SpinSpeed * Hub.Gift.FloatPeriod)) < 1e-6, "G2 tourne à SpinSpeed degrés/s")
check(gift._pivot.Position.X == 0 and gift._pivot.Position.Z == 0, "G3 reste à sa place à l'horizontale")
local st = HubController.GetState()
check(st.Gifts == 1 and st.Labels == 4, `G4 état : 1 cadeau, 4 étiquettes ({st.Gifts}, {st.Labels})`)

print(`{checks} vérification(s), {fails} échec(s)`)
