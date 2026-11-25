--!strict
-- GuardViewController (a433, client ; Cantin, 2026-11-24 : « freiner l'image du vigile côté client ») : chez le joueur
-- poursuivi, son vigile ne le traverse jamais, ne le dépasse plus quand il pile et reste derrière lui. Règle et
-- valeurs : Config/Chase.ClientView.Display (interrupteur Enabled : false = l'état d'a420) ; calcul : Shared/GuardView.
-- a443 : seulement quand la poursuite V3 est allumée (Shared/ChaseV3) ; éteinte : rien n'est suivi, l'état d'a420.
--
-- Ce n'est que de l'affichage. Rien n'est envoyé au serveur, qui reste seul juge de la capture (a416, a420).
--
-- Méthode : le vigile appartient au serveur (SetNetworkOwner(nil)) ; Roblox réplique la place de son HumanoidRootPart
-- (invisible) et ce client y accroche le corps par les joints. Ici, seul le joint entre le HumanoidRootPart et le corps
-- (Motor6D « Root » d'un R15 : C0, ou C1 s'il est monté à l'envers) est décalé, chez ce joueur seulement (un changement
-- fait par un client ne part pas au serveur) : le corps s'affiche à la place freinée, tourné vers le joueur, et le
-- HumanoidRootPart reste à la vraie place (tout ce qui la lit, ici comme ailleurs, lit toujours la vérité). Les
-- animations de Clément, jouées par le serveur, continuent telles quelles sur le corps décalé (Cantin, 24/11 : l'image
-- qui attend garde l'animation du serveur, aucune animation jouée ici). Aucune instance créée, aucun script dans le
-- modèle ; écart nul : le joint retrouve sa valeur d'origine.
-- a450 (Play de fusion101) : les 10 modèles de vigiles de Clément relient le corps au HumanoidRootPart par une
-- AnimationConstraint « Root » (pas un Motor6D) : le corps est alors posé à Attachment0.WorldCFrame × Transform ×
-- Attachment1.CFrame⁻¹ ; l'Animator écrit Transform, donc c'est le CFrame de l'Attachment porté par le HumanoidRootPart
-- qui est décalé (même calcul que C0, ou C1 s'il est monté à l'envers), chez ce joueur seulement. Sans aucun lien (ou
-- corps hors de l'assemblage du HumanoidRootPart : contrainte non cinématique) : image non freinée, un avertissement
-- en Studio, et la retenue au contact (plus bas) se fait sur la vraie place du vigile.
-- Pas d'écriture du CFrame du HumanoidRootPart (la réplication la réécrit, et un vigile immobile ne la réécrit plus :
-- on ne saurait plus lire sa vraie place), pas de copie locale (un second modèle à animer et à nettoyer).
--
-- Suivi : les modèles de Workspace/ActiveGuards dont l'attribut TargetUserId est ce joueur (posé par GuardService).
-- Hors poursuite : aucun calcul par image (RenderStepped débranché). Cible perdue (capture, abandon) : le suivi
-- continue tant qu'un écart reste (même règle : l'image ne rejoint que sans passer devant le joueur), puis s'arrête.
-- Modèle détruit ou sorti du dossier : suivi oublié.
--
-- a443 (Chase.V3.ContactHold ; Cantin, 24/11 : « quand tu fais un demi-tour vers le vigile, t'es censé être attrapé ») : le
-- serveur attrape le joueur qui croise le vigile, mais il ne l'apprend qu'un retard plus tard (0,2 à 0,35 s) : le joueur
-- serait déjà 20 à 30 studs plus loin. Ici, dès que ce joueur touche l'image de son vigile en poursuite V3 (attribut
-- ChaseLaw du modèle, posé par GuardService ; Reach studs à plat, même étage), sa direction de marche est mise à zéro
-- (Humanoid:Move(0) après le pas du ControlModule : BindToRenderStep, priorité Input + 2) pendant Seconds s au plus : la
-- capture du serveur arrive alors au contact. Dès que la capture arrive (sa WalkSpeed passe à 0) ou à la fin du délai,
-- la marche est rendue ; sans capture, pas de nouvelle retenue avant Cooldown s. Rien n'est envoyé au serveur, qui
-- décide seul : un client sans cette retenue est attrapé quand même, il voit seulement la capture arriver plus loin.
--
-- API (client) :
--   GuardViewController.GetOffset(model) -> Vector3   écart place affichée − vraie place (0 si aucun)
--   GuardViewController.IsHeld() -> boolean           la marche du joueur est-elle retenue (contact) ?

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuardView = require(Shared:WaitForChild("GuardView"))
local ChaseV3 = require(Shared:WaitForChild("ChaseV3")) -- a443 : seulement avec la poursuite V3 (Features.ChaseV3, ChaseV3Dev)

-- Mêmes noms que dans GuardService (serveur) et ChaseController : les changer dans les trois fichiers.
local ACTIVE_FOLDER = "ActiveGuards"
local TARGET_ATTRIBUTE = "TargetUserId"
local LAW_ATTRIBUTE = "ChaseLaw" -- a443 : poursuivant en poursuite V3, en course (même nom dans GuardService)
local HOLD_STEP = "GuardContactHold"

local IS_STUDIO = RunService:IsStudio()

-- Un lien entre le HumanoidRootPart et le corps : Motor6D ou Weld (`joint` : C0 si `first`, sinon C1), ou
-- AnimationConstraint (`attachment` : celui que porte le HumanoidRootPart). `body` : la pièce de l'autre bout.
type Joint = { instance: Instance, joint: JointInstance?, attachment: Attachment?, first: boolean, original: CFrame, body: BasePart }

type Entry = {
	model: Model,
	root: BasePart,
	joints: { Joint },
	state: GuardView.State,
	releasing: boolean, -- cible perdue : suivi arrêté dès que l'écart est nul
	applied: boolean,
	offset: Vector3,
}

local GuardViewController = {}

local localPlayer = Players.LocalPlayer
local display: any = nil -- Config/Chase.ClientView.Display, allumé
local entries: { [Model]: Entry } = {}
local watched: { [Model]: { RBXScriptConnection } } = {}
local stepConnection: RBXScriptConnection? = nil
local warned: { [string]: boolean } = {}
-- a443 (Chase.V3.ContactHold) : retenue de la marche au contact de l'image.
local hold: any = nil -- Config/Chase.V3.ContactHold, allumé
local holdUntil = 0 -- fin de la retenue en cours (os.clock)
local holdAgainAt = 0 -- pas de nouvelle retenue avant
local holdBound = false

local function note(key: string, message: string)
	if IS_STUDIO and not warned[key] then
		warned[key] = true
		warn(`[GuardView] {message}`)
	end
end

local function number(value: any, default: number): number
	return if type(value) == "number" and value == value then value else default
end

local function link(instance: Instance, joint: JointInstance?, attachment: Attachment?, first: boolean, original: CFrame, body: BasePart): Joint
	return { instance = instance, joint = joint, attachment = attachment, first = first, original = original, body = body }
end

-- Les liens qui accrochent le corps au HumanoidRootPart : Motor6D « Root » d'un R15, Weld d'un accessoire porté par
-- lui, ou AnimationConstraint « Root » (a450 : les modèles de vigiles de Clément).
local function jointsOf(model: Model, root: BasePart): { Joint }
	local found: { Joint } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("JointInstance") then
			local joint = descendant :: JointInstance
			local part0, part1 = joint.Part0, joint.Part1
			if part0 == root and part1 ~= nil then
				table.insert(found, link(joint, joint, nil, true, joint.C0, part1))
			elseif part1 == root and part0 ~= nil then
				table.insert(found, link(joint, joint, nil, false, joint.C1, part0))
			end
		elseif descendant:IsA("AnimationConstraint") then
			local constraint = descendant :: AnimationConstraint
			local a0, a1 = constraint.Attachment0, constraint.Attachment1
			local part0 = if a0 then a0.Parent else nil
			local part1 = if a1 then a1.Parent else nil
			if a0 and a1 and part0 and part1 and part0 ~= part1 and part0:IsA("BasePart") and part1:IsA("BasePart") then
				if part0 == root then
					table.insert(found, link(constraint, nil, a0, true, a0.CFrame, part1 :: BasePart))
				elseif part1 == root then
					table.insert(found, link(constraint, nil, a1, false, a1.CFrame, part0 :: BasePart))
				end
			end
		end
	end
	return found
end

-- Écrit un lien : `value` = décalage × valeur d'origine (la valeur d'origine pour le rétablir).
local function write(item: Joint, value: CFrame)
	local attachment, joint = item.attachment, item.joint
	if attachment then
		attachment.CFrame = value
	elseif joint then
		if item.first then
			joint.C0 = value
		else
			joint.C1 = value
		end
	end
end

local function restore(entry: Entry)
	entry.offset = Vector3.zero
	if not entry.applied then
		return
	end
	entry.applied = false
	for _, item in entry.joints do
		if item.instance.Parent ~= nil then
			write(item, item.original)
		end
	end
end

local function forget(model: Model)
	local entry = entries[model]
	if entry == nil then
		return
	end
	entries[model] = nil
	pcall(restore, entry)
end

local function localRoot(): BasePart?
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root :: BasePart
end

-- Rend toujours true (pour pcall : une seule valeur rendue en plus de ok).
local function localHumanoid(): Humanoid?
	local character = localPlayer.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function releaseHold()
	holdUntil = 0
	if holdBound then
		holdBound = false
		pcall(function()
			RunService:UnbindFromRenderStep(HOLD_STEP)
		end)
	end
end

-- a443 (Chase.V3.ContactHold) : l'image du vigile (x, z, hauteur y) touche-t-elle ce joueur ? Alors sa marche est retenue.
local function checkContact(x: number, z: number, y: number, mine: BasePart)
	local now = os.clock()
	if hold == nil or now < holdUntil or now < holdAgainAt then
		return
	end
	local at = mine.Position
	local reach = number(hold.Reach, 0)
	if math.abs(y - at.Y) > number(display.HeightMax, math.huge) or (x - at.X) ^ 2 + (z - at.Z) ^ 2 > reach * reach then
		return
	end
	local humanoid = localHumanoid()
	if humanoid == nil or humanoid.WalkSpeed <= 0 then
		return -- déjà immobilisé (capture en cours)
	end
	local seconds = number(hold.Seconds, 0)
	if seconds <= 0 then
		return
	end
	holdUntil = now + seconds
	holdAgainAt = holdUntil + math.max(number(hold.Cooldown, 0), 0)
	if not holdBound then
		holdBound = true
		RunService:BindToRenderStep(HOLD_STEP, Enum.RenderPriority.Input.Value + 2, function()
			local current = localHumanoid()
			if current == nil or os.clock() >= holdUntil then
				releaseHold()
			elseif current.WalkSpeed <= 0 then
				-- La capture est arrivée : marche rendue (le serveur l'immobilise), une autre retenue redevient possible.
				holdAgainAt = 0
				releaseHold()
			else
				current:Move(Vector3.zero, false)
			end
		end)
	end
end

local function stepEntry(entry: Entry, dt: number, mine: BasePart?): boolean
	local root = entry.root
	local real = root.Position
	local constrained = false
	local px, pz = real.X, real.Z
	if mine then
		local at = mine.Position
		px, pz = at.X, at.Z
		-- Écart en cours : la règle tient jusqu'au retour. Sinon : même étage et assez près seulement.
		if entry.applied then
			constrained = true
		else
			local dx, dz = real.X - px, real.Z - pz
			local range = number(display.ActiveRange, math.huge)
			constrained = math.abs(real.Y - at.Y) <= number(display.HeightMax, math.huge) and dx * dx + dz * dz <= range * range
		end
	end
	local contact = hold ~= nil and not entry.releasing and entry.model:GetAttribute(LAW_ATTRIBUTE) == true
	-- Le HumanoidRootPart doit porter l'assemblage (sinon décaler son lien le déplacerait, lui, au lieu du corps), et le
	-- corps en faire partie (a450 : une AnimationConstraint non cinématique laisse le corps dans son propre assemblage,
	-- que la réplication replace). Sinon, ou sans aucun lien : image non freinée ; la retenue au contact (a443) reste,
	-- sur la vraie place du vigile (sans elle, le joueur qui fait demi-tour traverse le vigile avant la capture).
	local reason: string? = nil
	if #entry.joints == 0 then
		reason = "aucun lien (Motor6D, Weld ou AnimationConstraint) entre son HumanoidRootPart et son corps"
	elseif root.AssemblyRootPart ~= root then
		reason = "son HumanoidRootPart ne porte pas l'assemblage"
	else
		for _, item in entry.joints do
			if item.body.AssemblyRootPart ~= root then
				reason = `{item.instance.ClassName} {item.instance.Name} : {item.body.Name} n'est pas dans l'assemblage de son HumanoidRootPart`
				break
			end
		end
	end
	if reason then
		note(`root:{entry.model.Name}`, `{entry.model.Name} : {reason}, image non freinée`)
		GuardView.Reset(entry.state)
		restore(entry)
		if contact and mine then
			checkContact(real.X, real.Z, real.Y, mine)
		end
		return true
	end
	local x, z = GuardView.Step(entry.state, display, real.X, real.Z, px, pz, dt, constrained)
	if contact and mine then
		checkContact(x, z, real.Y, mine) -- a443 (Chase.V3.ContactHold)
	end
	local ox, oz = GuardView.Offset(entry.state)
	if ox == 0 and oz == 0 then
		restore(entry)
		return true
	end
	-- Corps affiché à la place freinée ; tourné vers le joueur à mesure que l'écart grandit.
	local frame = root.CFrame
	local place = Vector3.new(x, real.Y, z)
	local shown = frame.Rotation + place
	local blend = number(display.FaceBlend, 0)
	if mine and (px - x) ^ 2 + (pz - z) ^ 2 > 0.01 then
		local gap = math.sqrt(ox * ox + oz * oz)
		local weight = if blend > 0 then math.min(gap / blend, 1) else 1
		shown = shown:Lerp(CFrame.lookAt(place, Vector3.new(px, real.Y, pz)), weight)
	end
	local shift = frame:ToObjectSpace(shown)
	for _, item in entry.joints do
		write(item, shift * item.original)
	end
	entry.applied = true
	entry.offset = Vector3.new(ox, 0, oz)
	return true
end

local function step(dt: number)
	local mine = localRoot()
	for model, entry in entries do
		if model.Parent == nil or entry.root.Parent == nil then
			forget(model)
			continue
		end
		local ok, err = pcall(stepEntry, entry, dt, mine)
		if not ok then
			note("step", `image du vigile non freinée ({err})`)
			forget(model)
		elseif entry.releasing and not entry.applied then
			forget(model)
		end
	end
	if next(entries) == nil and stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
end

local function follow(model: Model)
	local entry = entries[model]
	if entry then
		entry.releasing = false
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	-- a450 : sans aucun lien, le vigile est suivi quand même (stepEntry : avertissement, retenue au contact seule).
	local joints = jointsOf(model, root :: BasePart)
	entries[model] = {
		model = model,
		root = root :: BasePart,
		joints = joints,
		state = GuardView.new(),
		releasing = false,
		applied = false,
		offset = Vector3.zero,
	}
	if stepConnection == nil then
		stepConnection = RunService.RenderStepped:Connect(step)
	end
end

-- Cible perdue (capture, abandon) : oubli tout de suite sans écart, sinon dès que l'image a rejoint la vraie place.
local function release(model: Model)
	local entry = entries[model]
	if entry == nil then
		return
	end
	if not entry.applied then
		forget(model)
		return
	end
	entry.releasing = true
end

local function refresh(model: Model)
	if model.Parent ~= nil and model:GetAttribute(TARGET_ATTRIBUTE) == localPlayer.UserId and ChaseV3.Enabled() then
		follow(model)
	else
		release(model)
	end
end

local function watch(child: Instance)
	if not child:IsA("Model") or watched[child :: Model] ~= nil then
		return
	end
	local model = child :: Model
	watched[model] = {
		model:GetAttributeChangedSignal(TARGET_ATTRIBUTE):Connect(function()
			refresh(model)
		end),
	}
	refresh(model)
end

local function unwatch(child: Instance)
	if not child:IsA("Model") then
		return
	end
	local model = child :: Model
	local connections = watched[model]
	if connections then
		watched[model] = nil
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	forget(model)
end

local function watchFolder(folder: Instance)
	folder.ChildAdded:Connect(watch)
	folder.ChildRemoved:Connect(unwatch)
	for _, child in folder:GetChildren() do
		watch(child)
	end
end

function GuardViewController.GetOffset(model: Model?): Vector3
	local entry = if model then entries[model] else nil
	return if entry then entry.offset else Vector3.zero
end

function GuardViewController.IsHeld(): boolean
	return holdBound and os.clock() < holdUntil
end

function GuardViewController.Start()
	local chase = require(Shared:WaitForChild("Config"):WaitForChild("Chase") :: ModuleScript) :: any
	local view = chase.ClientView
	local cfg = if type(view) == "table" then view.Display else nil
	if type(view) ~= "table" or view.Enabled ~= true or type(cfg) ~= "table" or cfg.Enabled ~= true then
		return -- interrupteur coupé : l'état d'a420, rien n'est branché
	end
	display = cfg
	local v3 = chase.V3
	local contact = if type(v3) == "table" then v3.ContactHold else nil
	hold = if type(contact) == "table" and contact.Enabled == true then contact else nil -- a443
	local ok, err = pcall(function(): boolean
		local folder = Workspace:FindFirstChild(ACTIVE_FOLDER)
		if folder then
			watchFolder(folder)
			return true
		end
		local connection: RBXScriptConnection? = nil
		connection = Workspace.ChildAdded:Connect(function(child: Instance)
			if child.Name == ACTIVE_FOLDER then
				if connection then
					connection:Disconnect()
					connection = nil
				end
				watchFolder(child)
			end
		end)
		return true
	end)
	if not ok then
		note("start", `suivi des vigiles impossible, image non freinée ({err})`)
	end
end

return GuardViewController
