--!nocheck
-- Banc a231 (vague 70, L-223) : la foule NPC_Crowd_01 à _12 de Clément (Assets/Crowd/Models) avec ses 5 animations
-- Cheer, Boo, Shout, HoldSign, TakePhoto : le vrai ContractChecker la lit avec Animations.Crowd (plus comme un vigile).
-- Contenu des animations : un faux AnimationClipProvider rend une KeyframeSequence réglée comme le contrat.

moduleScript(SERVICES, "ContractChecker", "server/Services/ContractChecker.luau")

local CLIPS = {
	["rbxassetid://1001"] = { Loop = true, Priority = "Action", Marker = "Shout" }, -- Cheer
	["rbxassetid://1002"] = { Loop = true, Priority = "Action", Marker = "Shout" }, -- Boo
	["rbxassetid://1003"] = { Loop = true, Priority = "Action", Marker = "Shout" }, -- Shout
	["rbxassetid://1004"] = { Loop = true, Priority = "Action" }, -- HoldSign
	["rbxassetid://1005"] = { Loop = true, Priority = "Action", Marker = "Flash" }, -- TakePhoto
	["rbxassetid://1006"] = { Loop = false, Priority = "Action" }, -- Cheer mal réglée (sans boucle, sans marqueur)
}
AnimationClipProvider.GetAnimationClipAsync = function(_self, id)
	local spec = CLIPS[id]
	if spec == nil then
		error("animation inconnue du banc : " .. tostring(id))
	end
	local clip = make("KeyframeSequence", { Name = "Clip", Loop = spec.Loop, Priority = { Name = spec.Priority } })
	local key = make("Keyframe", { Name = "K1" }, clip)
	if spec.Marker then
		make("KeyframeMarker", { Name = spec.Marker }, key)
	end
	return clip
end

local ORDER = { "Cheer", "Boo", "Shout", "HoldSign", "TakePhoto" }
local crowdFolder = make("Folder", { Name = "Crowd" }, ASSETS)
local modelsFolder = make("Folder", { Name = "Models" }, crowdFolder)
local function crowdModel(index)
	local model = make("Model", { Name = string.format("NPC_Crowd_%02d", index) })
	make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CanCollide = false }, model)
	local humanoid = make("Humanoid", { Name = "Humanoid" }, model)
	make("Animator", { Name = "Animator" }, humanoid)
	local anims = make("Folder", { Name = "Animations" }, model)
	for i, name in ORDER do
		make("Animation", { Name = name, AnimationId = "rbxassetid://100" .. i }, anims)
	end
	model.Parent = modelsFolder
	return model
end
local crowd = {}
for index = 1, 12 do
	crowd[index] = crowdModel(index)
end

startServer()
local Animations = sharedModule("Contract/Animations")
local Checker = serverModule("ContractChecker")
local function rerun()
	clearLog()
	Checker.Start()
	flush()
end

section("Contract/Animations : Animations.Crowd")
local names = {}
for _, spec in Animations.Crowd do
	names[#names + 1] = spec.Name
	check(spec.Loop == true and spec.Priority == "Action", `{spec.Name} : en boucle, priorité Action`)
end
check(table.concat(names, ",") == "Cheer,Boo,Shout,HoldSign,TakePhoto", `5 noms de L-223 ({table.concat(names, ",")})`)
local markers = {}
for _, spec in Animations.Crowd do
	markers[spec.Name] = spec.Marker or "-"
end
check(markers.Cheer == "Shout" and markers.Boo == "Shout" and markers.Shout == "Shout" and markers.HoldSign == "-" and markers.TakePhoto == "Flash", "marqueurs Shout (×3), aucun, Flash")
-- a252 : PickUp ajoutée aux vigiles de magasin (6e), pas aux vigiles de nuit.
local guardCount = #Animations.Guard
local lastGuard = Animations.Guard[guardCount]
-- a277 : Sprint ajoutée après PickUp (7e), en boucle, Movement, pas aux vigiles de nuit.
local sprintOk = guardCount == 7 and lastGuard.Name == "Sprint" and lastGuard.Loop == true and lastGuard.Priority == "Movement"
	and Animations.Guard[6].Name == "PickUp" and Animations.Guard[6].Marker == "Grab"
check((guardCount == 5 or (guardCount == 6 and lastGuard.Name == "PickUp" and lastGuard.Marker == "Grab") or sprintOk) and #Animations.NightGuard == 6 and #Animations.Witness == 6,
	"vigiles (5, 6 avec PickUp d a252, ou 7 avec Sprint d a277), vigiles de nuit (6) et témoins inchangés")

section("ContractChecker : 12 NPC_Crowd livrés comme L-223")
rerun()
check(logHas("[Contrat] Contrat :", nil, "server"), "le vérificateur tourne jusqu'au bout")
check(logCount("NPC_Crowd", nil, "server") == 0, `aucune ligne sur la foule ({logCount("NPC_Crowd", nil, "server")})`)
check(logCount("hors contrat", nil, "server") == 0, "aucune animation hors contrat")

section("ContractChecker : la foule a encore ses contrôles")
crowd[1].Animations.HoldSign:Destroy()
crowd[2].Animations.Cheer.AnimationId = "rbxassetid://1006"
make("Animation", { Name = "Wave", AnimationId = "rbxassetid://1001" }, crowd[3].Animations)
crowd[4].Animations:Destroy()
rerun()
check(logHas("NPC_Crowd_01.Animations : pas encore livrée(s) : HoldSign", nil, "server"), "HoldSign manquante : pas encore livrée")
check(logHas("NPC_Crowd_02.Animations.Cheer : sans boucle, attendu en boucle", nil, "server"), "Cheer sans boucle : signalée")
check(logHas("NPC_Crowd_02.Animations.Cheer : marqueur Shout absent", nil, "server"), "Cheer sans marqueur Shout : signalée")
check(logHas("NPC_Crowd_03.Animations.Wave : animation hors contrat 2.4 (nom mal écrit ? attendus : Cheer, Boo, Shout, HoldSign, TakePhoto)", nil, "server"), "Wave hors contrat, avec les 5 noms de la foule")
check(logHas("NPC_Crowd_04.Animations absent : animations de foule pas encore livrées (Cheer, Boo, Shout, HoldSign, TakePhoto)", nil, "server"), "dossier absent : « foule » et ses 5 noms")
check(logCount("NPC_Crowd", nil, "server") == 5, `rien d'autre sur la foule ({logCount("NPC_Crowd", nil, "server")} lignes)`)

summary("scénario a231 checker")
