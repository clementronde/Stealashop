--!nocheck
-- Catalogue v3 : les boucles « Boucle » des 45 objets Meshy (2 s, 61 images, priorité Action), en KeyframeSequence
-- dans ServerStorage/RBX_ANIMSAVES/ITM_<ItemId>/Boucle, à publier par Clément (clic droit > Save to Roblox, au nom
-- du groupe), puis l'ID est collé dans ITM_<ItemId>/Animations/Boucle. Mêmes courbes que
-- StealAShop-Art/Items/V3_Meshy/_scripts/make_anims.py.
-- La pose du haut porte le nom du MeshPart (ITM_<ItemId>) : sinon l'os racine ne bouge pas.
-- À lancer en Edit. Rejouable : remplace seulement les KeyframeSequence « Boucle » de ces 45 objets.

local INFO = {
	Secret_ToilettesEnOr = {"bascule", 2.245}, Z1_BananeScotchee = {"bascule", 2.000}, Z1_BoissonSigma = {"danse", 2.000},
	Z1_Canette67 = {"danse", 1.636}, Z1_ChipsMystere = {"danse", 1.900}, Z1_ChocolatDeDubai = {"bascule", 1.500},
	Z1_OeufBoudeur = {"danse", 0.940}, Z1_PastequeMewing = {"danse", 1.800}, Z1_PouletALunettes = {"danse", 1.900},
	Z1_TicketGagnant = {"bascule", 1.600}, Z2_BonbonPiquant = {"danse", 1.600}, Z2_BusEnGelatine = {"danse", 1.500},
	Z2_CanardRoyal = {"danse", 1.700}, Z2_CapybaraOrange = {"danse", 1.600}, Z2_SucetteTourbillon = {"danse", 2.200},
	Z2_TheiereDansante = {"danse", 1.700}, Z3_ChatQuiTourne = {"tourne", 1.900}, Z3_ClavierRgb = {"bascule", 0.258},
	Z3_ManetteQuiTranspire = {"danse", 1.300}, Z3_MicroDeStreamer = {"bascule", 2.000}, Z3_PcGamerQuiFume = {"danse", 2.200},
	Z3_SushiNinja = {"danse", 1.600}, Z3_TelephonePliant = {"bascule", 1.600}, Z4_ChaineDrip = {"danse", 2.000},
	Z4_ChihuahuaEnDiamants = {"danse", 2.000}, Z4_FauxOnglesEnOr = {"danse", 2.000}, Z4_GrillzEnDiamant = {"bascule", 0.455},
	Z4_MontreGlacee = {"bascule", 1.700}, Z4_PerruquePresidentielle = {"danse", 1.900}, Z5_BaguetteEnOr = {"bascule", 0.600},
	Z5_BeretDeMime = {"bascule", 1.065}, Z5_CramponsDores = {"bascule", 0.913}, Z5_CroissantRequin = {"danse", 1.037},
	Z5_GoldenBall = {"bascule", 1.500}, Z5_JocondeSelfie = {"bascule", 2.200}, Z5_StatueMewing = {"bascule", 2.200},
	Z6_BilletQuiCourt = {"danse", 2.100}, Z6_CarteNoireInfinie = {"bascule", 1.800}, Z6_CerveauDore = {"danse", 1.561},
	Z6_CoffreADents = {"danse", 2.000}, Z6_LiberteEnOr = {"bascule", 2.300}, Z6_LingotGeant = {"bascule", 0.611},
	Z6_PigeonEnOr = {"danse", 1.754}, Z6_TaxiEnOr = {"bascule", 1.219}, Z6_ValiseDeBillets = {"bascule", 1.513},
}

local TAU = 2 * math.pi
local D = math.rad

local function poses(style: string, h: number, t: number)
	if style == "tourne" then
		return { Base = CFrame.new(0, 0.04 * h * (0.5 - 0.5 * math.cos(2 * TAU * t)), 0) * CFrame.Angles(0, TAU * t, 0) }
	elseif style == "bascule" then
		return { Base = CFrame.Angles(D(1.5) * math.sin(TAU * t), 0, D(4) * math.sin(math.pi * t)) }
	end
	local squash = -0.035 * h * (0.5 - 0.5 * math.cos(2 * TAU * t))
	return {
		Base = CFrame.identity,
		Body = CFrame.Angles(D(2) * math.sin(TAU * t + math.pi / 2), 0, D(5) * math.sin(TAU * t)),
		Top = CFrame.new(0, squash, 0) * CFrame.Angles(D(3) * math.sin(TAU * (t - 0.12) + math.pi / 2), 0, D(7) * math.sin(TAU * (t - 0.12))),
	}
end

-- Les os sont à la pose de liaison de l'import (attribut BindOffset du modèle, jusqu'à 32 studs de côté) :
-- chaque pose est recentrée pour tourner autour du bas de l'objet, pas autour de l'os.
local function build(itemId: string, bindOffset: Vector3): KeyframeSequence
	local style, h = INFO[itemId][1], INFO[itemId][2]
	local oh = Vector3.new(bindOffset.X, 0, bindOffset.Z)
	local function piv(cf: CFrame): CFrame
		return CFrame.new(-oh) * cf * CFrame.new(oh)
	end
	local chain = if style == "danse" then { "Base", "Body", "Top" } else { "Base" }
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "Boucle"
	ks.Loop = true
	ks.Priority = Enum.AnimationPriority.Action
	for i = 0, 60 do
		local t = i / 30
		local p = poses(style, h, t)
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local top = Instance.new("Pose")
		top.Name = "ITM_" .. itemId
		top.Weight = 1
		top.Parent = kf
		local parent = top
		for _, bone in chain do
			local pose = Instance.new("Pose")
			pose.Name = bone
			pose.Weight = 1
			pose.CFrame = piv(p[bone])
			pose.Parent = parent
			parent = pose
		end
		kf.Parent = ks
	end
	return ks
end

local ServerStorage = game:GetService("ServerStorage")
local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
if not saves then
	saves = Instance.new("Model")
	saves.Name = "RBX_ANIMSAVES"
	saves.Parent = ServerStorage
end
local items = game:GetService("ReplicatedStorage").Assets.Items
local n = 0
for itemId in INFO do
	local name = "ITM_" .. itemId
	local holder = saves:FindFirstChild(name)
	if not holder then
		holder = Instance.new("ObjectValue")
		holder.Name = name
		holder.Parent = saves
	end
	local model = items:FindFirstChild(name)
	if model then holder.Value = model end
	local old = holder:FindFirstChild("Boucle")
	if old then old:Destroy() end
	local offset = model and model:GetAttribute("BindOffset") or Vector3.zero
	build(itemId, offset).Parent = holder
	n += 1
	task.wait()
end
game:GetService("ChangeHistoryService"):SetWaypoint("Boucles des objets v3 Meshy")
return n .. " KeyframeSequence « Boucle » dans RBX_ANIMSAVES"
