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
-- Pas d'écriture du CFrame du HumanoidRootPart (la réplication la réécrit, et un vigile immobile ne la réécrit plus :
-- on ne saurait plus lire sa vraie place), pas de copie locale (un second modèle à animer et à nettoyer).
--
-- Suivi : les modèles de Workspace/ActiveGuards dont l'attribut TargetUserId est ce joueur (posé par GuardService).
-- Hors poursuite : aucun calcul par image (RenderStepped débranché). Cible perdue (capture, abandon) : le suivi
-- continue tant qu'un écart reste (même règle : l'image ne rejoint que sans passer devant le joueur), puis s'arrête.
-- Modèle détruit ou sorti du dossier : suivi oublié.
--
-- API (client) :
--   GuardViewController.GetOffset(model) -> Vector3   écart place affichée − vraie place (0 si aucun)

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

local IS_STUDIO = RunService:IsStudio()

type Joint = { joint: JointInstance, first: boolean, original: CFrame }

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

local function note(key: string, message: string)
	if IS_STUDIO and not warned[key] then
		warned[key] = true
		warn(`[GuardView] {message}`)
	end
end

local function number(value: any, default: number): number
	return if type(value) == "number" and value == value then value else default
end

-- Les joints qui accrochent le corps au HumanoidRootPart (Motor6D « Root » d'un R15 ; Weld d'un accessoire porté par lui).
local function jointsOf(model: Model, root: BasePart): { Joint }
	local found: { Joint } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("JointInstance") then
			local joint = descendant :: JointInstance
			if joint.Part0 == root and joint.Part1 ~= nil then
				table.insert(found, { joint = joint, first = true, original = joint.C0 })
			elseif joint.Part1 == root and joint.Part0 ~= nil then
				table.insert(found, { joint = joint, first = false, original = joint.C1 })
			end
		end
	end
	return found
end

local function restore(entry: Entry)
	entry.offset = Vector3.zero
	if not entry.applied then
		return
	end
	entry.applied = false
	for _, item in entry.joints do
		if item.joint.Parent ~= nil then
			if item.first then
				item.joint.C0 = item.original
			else
				item.joint.C1 = item.original
			end
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
	-- Le HumanoidRootPart doit porter l'assemblage (sinon décaler son joint le déplacerait, lui, au lieu du corps).
	if root.AssemblyRootPart ~= root then
		note(`root:{entry.model.Name}`, `{entry.model.Name} : son HumanoidRootPart ne porte pas l'assemblage, image non freinée`)
		GuardView.Reset(entry.state)
		restore(entry)
		return true
	end
	local x, z = GuardView.Step(entry.state, display, real.X, real.Z, px, pz, dt, constrained)
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
		if item.first then
			item.joint.C0 = shift * item.original
		else
			item.joint.C1 = shift * item.original
		end
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
	local joints = jointsOf(model, root :: BasePart)
	if #joints == 0 then
		note(`joints:{model.Name}`, `{model.Name} : aucun joint entre son HumanoidRootPart et son corps, image non freinée`)
		return
	end
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

function GuardViewController.Start()
	local chase = require(Shared:WaitForChild("Config"):WaitForChild("Chase") :: ModuleScript) :: any
	local view = chase.ClientView
	local cfg = if type(view) == "table" then view.Display else nil
	if type(view) ~= "table" or view.Enabled ~= true or type(cfg) ~= "table" or cfg.Enabled ~= true then
		return -- interrupteur coupé : l'état d'a420, rien n'est branché
	end
	display = cfg
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
