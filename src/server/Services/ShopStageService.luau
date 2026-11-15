--!strict
-- ShopStageService (DEV-020, MOD-015 ; liaison L-096 point 1) : la boutique du joueur grandit avec ses
-- rayons (règle de Clément vérifiée le 2026-11-11, notes/retours-clement-poursuite-gains-boutique.md,
-- « La boutique grandit avec les rayons »).
--
-- Niveau de la boutique = k, nombre de rayons visibles (1 à 5) : c'est RayonService qui le calcule (un rayon
-- apparaît dès que son premier présentoir est débloqué) et qui appelle ShopStageService.Apply(plot, k) AVANT de
-- montrer ses rayons (les contours RayonSpot_0n arrivent avec Stage_2). Ce service n'écoute rien lui-même :
-- attribution, achat de présentoirs, contrôle d'une seconde et départ du joueur passent tous par RayonService.
--
-- Ce que fait Apply (côté serveur, répliqué à tous ; les clients reçoivent les copies par le streaming) :
--   1. retire de la boutique chaque `Stage_j` avec j > k (j ≥ 2 ; `Stage_1` n'est jamais touché) ;
--   2. pour j de 2 à k, si la boutique n'a pas d'enfant `Stage_j`, copie
--      ReplicatedStorage/Assets/Plots/PLOT_Shop/Stage_j, sans aucun script (Script, LocalScript, ModuleScript
--      retirés de la copie), posée comme les RayonVisuals : plot:GetPivot() * gabarit:GetPivot():Inverse() *
--      copie:GetPivot(), et rangée dans la boutique sous le nom `Stage_j`. Le gabarit n'est jamais modifié ;
--   3. dans la copie, les pièces et les lumières qui ont l'attribut `Accent` prennent la couleur de l'attribut
--      `AccentColor` (Color3) de la boutique ; sans AccentColor, elles gardent la couleur du gabarit (une ligne) ;
--   4. dans toute la boutique (copies, Stage_1 et PlotBarrier compris), tout ce qui porte `HideFromStage` ≤ k
--      est caché, avec ses descendants ; le reste est rendu. Cacher (comme RayonService) : BasePart
--      Transparency = 1, CanCollide, CanTouch et CanQuery coupés ; Decal et Texture Transparency = 1 ;
--      SurfaceGui, BillboardGui, lumières, ParticleEmitter, Beam, Trail, Fire, Smoke, Sparkles, Highlight
--      Enabled = false. Les valeurs d'origine sont mémorisées et rendues telles quelles quand k redescend
--      (parcelle libérée : retour au niveau 1 ; renaissance en Partie 2) ;
--   5. pose sur la boutique l'attribut `StageLevel` = k (nom V0 proposé, absent du doc) : UpgradeController
--      (client) y lit où planter le panneau du niveau suivant (StageUpgradePoint, puis StageUpgradePoint_2).
-- Visuels de compétence sans niveau de boutique (Config/SkillTree.PlotVisuals avec EveryStage, ex. Stage_3/Walls ;
-- Clément, 2026-11-14, L-137 point 3) : pour chaque Stage_j du gabarit (j ≥ 2) au-dessus de k, chaque pièce de ce
-- Stage_j qui porte un de ces noms est copiée à part (même pose, même recoloration, sans script) dans le dossier
-- `SkillVisuals` de la boutique (SkillTree.SkillVisualsFolder) ; dès que k atteint j, cette copie est retirée (la
-- pièce arrive avec la copie de Stage_j). Montrée ou cachée par ShopWallsService selon la compétence, pas ici.
-- `Bounds` et `DepositZone` ne changent pas (grande taille dès le niveau 1, à décider avec Clément).
--
-- Croissance petit à petit (vague 55, a179, retour de Cantin du 15/11 ; valeurs V0 dans Config/ShopGrowth) :
-- `Stage_2` du gabarit contient à lui seul toute l'extension (sol PlotFloorExt, damier, allée, murets, champ de
-- force et grands murs invisibles jusqu'au fond, z 40), et `Stage_3` à `Stage_5` les murs, le toit et le décor
-- sur toute la longueur : au 5e présentoir, toute la base arrivait d'un coup. Désormais, avec le nombre de
-- présentoirs débloqués (3e argument d'Apply, donné par RayonService), le fond de la boutique est posé derrière
-- le rang du dernier présentoir débloqué (position de son `DisplaySlot_xx` dans le repère de la boutique,
-- + RowMargin, arrondi au damier) ; quand ce rang est le dernier de la boutique (19 ou 20 présentoirs), ou sans
-- ce 3e argument, rien n'est coupé, comme avant. Les copies `Stage_j` (et SkillVisuals) sont coupées en les
-- posant, d'après le fond du gabarit (bord arrière le plus loin de ses `Stage_j`) : pièce entièrement devant le
-- nouveau fond : intacte ; pièce fine du fond (mur du fond, parapet, caméras) : avancée avec le fond ; longue
-- pièce (sol, murs, toit) : raccourcie ; le reste au-delà : retiré de la copie. Quand le fond change, les copies
-- sont refaites depuis le gabarit : un profil chargé voit la même base qu'en y arrivant pas à pas. Les points
-- `StageUpgradePoint_n` (n ≥ 2) du fond avancent aussi (position d'origine rendue sans coupe) et la boutique
-- porte l'attribut `StageDepth` (z du fond dans son repère ; absent sans coupe ; nom V0) : UpgradeController
-- y replace son panneau. Le gabarit et les pièces de Clément posées dans le Workspace ne changent pas.
-- Gabarit découpé (L-190) : avec l'attribut ShopGrowth.RowCutAttribute (`RowCut` = true) sur PLOT_Shop, Clément a
-- coupé chaque pièce aux plans des fonds ; rien n'est plus raccourci : une pièce dont le bord arrière dépasse le
-- fond de moins de ShopGrowth.RowCutTolerance est gardée telle quelle, une pièce fine du fond avance encore, le
-- reste est retiré de la copie.
--
-- API (serveur) :
--   ShopStageService.Apply(plot, k, unlocked?) -> number
--       Met la boutique au niveau k (ramené à 1 au moins), coupée au fond du présentoir `unlocked` (nombre de
--       présentoirs débloqués ; nil : pas de coupe) ; renvoie le niveau posé. Sans yield.
--   ShopStageService.GetLevel(plot) -> number
--       Niveau posé par le dernier Apply (1 si aucun).
--   ShopStageService.IsBeyond(plot, inst) -> boolean
--       Une pièce de `inst` (lui compris) dépasse-t-elle le fond posé ? false sans coupe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local ShopGrowth = require(ReplicatedStorage.Shared.Config.ShopGrowth)
local SkillTree = require(ReplicatedStorage.Shared.Config.SkillTree)

-- Noms de Clément (L-096, plot_shop_builder) ; StageLevel et StageDepth : V0 proposés, absents du doc.
local TEMPLATE_NAME = "PLOT_Shop"
local STAGE_PATTERN = "^Stage_(%d+)$"
local ACCENT = "Accent"
local ACCENT_COLOR = "AccentColor"
local HIDE_FROM = "HideFromStage"
local LEVEL_ATTRIBUTE = "StageLevel"
local DEPTH_ATTRIBUTE = "StageDepth"
local SLOT_PATTERN = "^DisplaySlot_(%d+)$"
local POINT_PATTERN = "^StageUpgradePoint_(%d+)$"
local EPS = 1e-3

-- Propriétés changées pour cacher, par famille de classes (les mêmes que RayonService).
local PART_HIDDEN: { [string]: any } = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
local DECAL_HIDDEN: { [string]: any } = { Transparency = 1 }
local ENABLED_HIDDEN: { [string]: any } = { Enabled = false }
local ENABLED_CLASSES = { "SurfaceGui", "BillboardGui", "Light", "ParticleEmitter", "Beam", "Trail", "Fire", "Smoke", "Sparkles", "Highlight" }

type Saved = { [Instance]: { [string]: any } }
-- depth : fond posé (nil = entier) ; slots : z de chaque DisplaySlot_xx ; points : CFrame d'origine des StageUpgradePoint_n.
type PlotState = { level: number, saved: Saved, depth: number?, slots: { [number]: number }?, points: { [Attachment]: CFrame } }
-- Coupe d'une copie : fond posé, fond du gabarit, repère de la boutique, gabarit découpé par Clément (L-190).
type Cut = { depth: number, back: number, pivot: CFrame, rowCut: boolean }

local IS_STUDIO = RunService:IsStudio()

local ShopStageService = {}
ShopStageService.Priority = 119 -- appelé par RayonService (120) ; rien à démarrer

local states: { [Model]: PlotState } = {}
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[ShopStageService] {message}`)
	end
end

-- Gabarit Assets/Plots/PLOT_Shop, ou nil (une ligne) : la boutique garde alors ses niveaux actuels.
local function templateOf(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local plots = if assets then assets:FindFirstChild("Plots") else nil
	local found = if plots then plots:FindFirstChild(TEMPLATE_NAME) else nil
	if found == nil or not found:IsA("Model") then
		warnOnce(TEMPLATE_NAME, `{TEMPLATE_NAME} absent de ReplicatedStorage.Assets.Plots : la boutique ne grandit pas (L-096)`)
		return nil
	end
	return found :: Model
end

-- Enfants `Stage_j` d'un modèle, par numéro.
local function stagesOf(model: Instance): { [number]: Instance }
	local out: { [number]: Instance } = {}
	for _, child in model:GetChildren() do
		local digits = string.match(child.Name, STAGE_PATTERN)
		if digits then
			out[tonumber(digits) :: number] = child
		end
	end
	return out
end

local function hiddenValues(inst: Instance): { [string]: any }?
	if inst:IsA("BasePart") then
		return PART_HIDDEN
	elseif inst:IsA("Decal") then -- Texture compris
		return DECAL_HIDDEN
	end
	for _, class in ENABLED_CLASSES do
		if inst:IsA(class) then
			return ENABLED_HIDDEN
		end
	end
	return nil
end

local function hideOne(inst: Instance, saved: Saved)
	if saved[inst] then
		return
	end
	local values = hiddenValues(inst)
	if values == nil then
		return
	end
	local before: { [string]: any } = {}
	local target = inst :: any
	for property, value in values do
		before[property] = target[property]
		target[property] = value
	end
	saved[inst] = before
end

local function restoreOne(inst: Instance, before: { [string]: any })
	local target = inst :: any
	for property, value in before do
		target[property] = value
	end
end

-- Profondeur d'une pièce dans le repère `pivot` : CFrame locale, z avant, z arrière, et l'axe de la pièce (1 X,
-- 2 Y, 3 Z) aligné sur Z s'il y en a un.
local function zSpan(pivot: CFrame, part: BasePart): (CFrame, number, number, number?)
	local cf = pivot:Inverse() * part.CFrame
	local size = part.Size
	local axes = { cf.RightVector, cf.UpVector, -cf.LookVector }
	local lengths = { size.X, size.Y, size.Z }
	local half, aligned = 0, nil
	for i, axis in axes do
		half += math.abs(axis.Z) * lengths[i] / 2
		if math.abs(axis.Z) >= 1 - EPS then
			aligned = i
		end
	end
	local z = cf.Position.Z
	return cf, z - half, z + half, aligned
end

-- Coupe d'une pièce copiée au fond posé (règle de l'en-tête, valeurs de Config/ShopGrowth). false : retirée.
local function cutPart(part: BasePart, cut: Cut): boolean
	local cf, z0, z1, aligned = zSpan(cut.pivot, part)
	local depth, back = cut.depth, cut.back
	if z1 <= depth + (if cut.rowCut then ShopGrowth.RowCutTolerance else EPS) then
		return true
	end
	local nearBack = back - z1 <= ShopGrowth.BackZone
	if nearBack and z0 >= back - ShopGrowth.BackZone and z1 - z0 <= ShopGrowth.BackThickness then
		part.CFrame = cut.pivot * (cf + Vector3.new(0, 0, depth - back)) -- pièce fine du fond : elle avance avec lui
		return true
	end
	if cut.rowCut then
		-- gabarit découpé par Clément (L-190) : rien n'est raccourci, le tronçon au-delà du fond est retiré
	elseif aligned and z1 - z0 > ShopGrowth.ClipMinLength and z0 < depth then
		local newZ1 = if nearBack then z1 + depth - back else depth - ShopGrowth.InnerInset
		if newZ1 - z0 >= ShopGrowth.MinLength then
			local lengths = { part.Size.X, part.Size.Y, part.Size.Z }
			lengths[aligned] = newZ1 - z0
			part.Size = Vector3.new(lengths[1], lengths[2], lengths[3])
			part.CFrame = cut.pivot * (cf + Vector3.new(0, 0, (z0 + newZ1) / 2 - cf.Position.Z))
			return true
		end
	elseif (z0 + z1) / 2 <= depth then
		return true -- petite pièce à cheval sur le fond, centre devant : gardée
	end
	part:Destroy()
	return false
end

-- Coupe toute une copie (pas encore rangée dans la boutique). false : la copie elle-même est retirée.
local function cutCopy(copy: Instance, cut: Cut): boolean
	for _, inst in copy:GetDescendants() do
		if inst:IsA("BasePart") and inst:IsDescendantOf(copy) then
			cutPart(inst :: BasePart, cut)
		end
	end
	return if copy:IsA("BasePart") then cutPart(copy :: BasePart, cut) else true
end

-- Fond du gabarit : bord arrière le plus loin des pièces de ses Stage_j (j ≥ 2), dans son repère.
local backOf: { [Instance]: number } = {}
local function templateBack(template: Model): number
	local cached = backOf[template]
	if cached then
		return cached
	end
	local pivot = template:GetPivot()
	local back = -math.huge
	for j, stage in stagesOf(template) do
		local pieces: { Instance } = if j >= 2 then stage:GetDescendants() else {}
		for _, inst in pieces do
			if inst:IsA("BasePart") then
				local _, _, z1 = zSpan(pivot, inst :: BasePart)
				back = math.max(back, z1)
			end
		end
	end
	backOf[template] = back
	return back
end

-- z de chaque DisplaySlot_xx (1 à MaxSlots) dans le repère de la boutique (cherchés une fois).
local function slotDepths(plot: Model, state: PlotState): { [number]: number }
	local cached = state.slots
	if cached and next(cached) ~= nil then
		return cached
	end
	local pivot = plot:GetPivot()
	local out: { [number]: number } = {}
	for _, inst in plot:GetDescendants() do
		local digits = string.match(inst.Name, SLOT_PATTERN)
		local n = if digits and inst:IsA("Attachment") then tonumber(digits) else nil
		if n and n <= Balance.Display.MaxSlots then
			out[n] = pivot:PointToObjectSpace((inst :: Attachment).WorldCFrame.Position).Z
		end
	end
	state.slots = out
	return out
end

-- Fond de la boutique pour `unlocked` présentoirs débloqués, ou nil (boutique entière).
local function depthFor(plot: Model, state: PlotState, unlocked: number?, back: number): number?
	if not ShopGrowth.Enabled or unlocked == nil or unlocked ~= unlocked then
		return nil
	end
	local last, deepest = -math.huge, -math.huge
	for n, z in slotDepths(plot, state) do
		deepest = math.max(deepest, z)
		if n <= unlocked then
			last = math.max(last, z)
		end
	end
	if last == -math.huge or last >= deepest - EPS then
		return nil -- dernier rang de la boutique atteint : entière, comme avant
	end
	local depth = last + ShopGrowth.RowMargin
	local step = ShopGrowth.Step
	if step > 0 then
		depth = ShopGrowth.StepOrigin + math.ceil((depth - ShopGrowth.StepOrigin) / step - EPS) * step
	end
	return if depth < back - EPS then depth else nil
end

-- Points StageUpgradePoint_n (n ≥ 2) du fond : avancés avec le fond, rendus à leur place sans coupe.
local function placePoints(plot: Model, state: PlotState, cut: Cut?)
	for _, inst in plot:GetDescendants() do
		local digits = string.match(inst.Name, POINT_PATTERN)
		if digits == nil or (tonumber(digits) :: number) < 2 or not inst:IsA("Attachment") then
			continue
		end
		local point = inst :: Attachment
		local origin = state.points[point] or point.CFrame
		state.points[point] = origin
		local target = origin
		local parent = point.Parent
		if cut and parent and parent:IsA("BasePart") then
			local base = (parent :: BasePart).CFrame
			local here = cut.pivot:PointToObjectSpace(base * origin.Position)
			if cut.back - here.Z <= ShopGrowth.BackZone then
				local moved = cut.pivot:PointToWorldSpace(here + Vector3.new(0, 0, cut.depth - cut.back))
				target = origin + (base:PointToObjectSpace(moved) - origin.Position)
			end
		end
		if point.CFrame ~= target then
			point.CFrame = target
		end
	end
end

-- Copie de `source` (Stage_j du gabarit, ou une de ses pièces), recolorée, sans script, posée dans la boutique
-- (rangée dans `parent`, la boutique elle-même par défaut), coupée au fond posé s'il y en a un.
local function placeCopy(plot: Model, template: Model, source: Instance, parent: Instance?, cut: Cut?)
	local copy = source:Clone()
	local all = copy:GetDescendants()
	table.insert(all, copy)
	local color = plot:GetAttribute(ACCENT_COLOR)
	if typeof(color) ~= "Color3" then
		warnOnce(plot:GetFullName() .. ACCENT_COLOR, `{plot:GetFullName()} : pas d'attribut {ACCENT_COLOR} (Color3) : les copies gardent la couleur du gabarit`)
	end
	local transform = plot:GetPivot() * template:GetPivot():Inverse()
	for _, inst in all do
		if inst:IsA("LuaSourceContainer") then
			inst:Destroy() -- aucun script dans les copies (CLAUDE.md)
		elseif typeof(color) == "Color3" and inst:GetAttribute(ACCENT) and (inst:IsA("BasePart") or inst:IsA("Light")) then
			(inst :: any).Color = color
		end
	end
	if copy:IsA("Model") then
		local model = copy :: Model
		model:PivotTo(transform * model:GetPivot())
	else
		for _, inst in copy:GetDescendants() do -- Stage_j rangé dans un Folder : chaque pièce suit
			if inst:IsA("BasePart") then
				local part = inst :: BasePart
				part.CFrame = transform * part.CFrame
			end
		end
	end
	copy.Name = source.Name
	if cut and not cutCopy(copy, cut) then
		return -- pièce entière au-delà du fond
	end
	copy.Parent = parent or plot
end

-- Visuels EveryStage (voir l'en-tête) : copie à part tant que la boutique est sous le Stage_j qui les contient.
local function applyEveryStage(plot: Model, template: Model?, k: number, cut: Cut?)
	local folder = plot:FindFirstChild(SkillTree.SkillVisualsFolder)
	for name, visual in SkillTree.PlotVisuals do
		if not visual.EveryStage then
			continue
		end
		local existing = if folder then folder:FindFirstChild(name) else nil
		local source: Instance? = nil
		local fromStage = 0
		if template then
			for j, stage in stagesOf(template) do
				local found = if j >= 2 then stage:FindFirstChild(name, true) else nil
				if found and (source == nil or j < fromStage) then
					source, fromStage = found, j
				end
			end
		end
		if source == nil or k >= fromStage then
			if existing then
				existing:Destroy()
			end
		elseif existing == nil then
			if folder == nil then
				local created = Instance.new("Folder")
				created.Name = SkillTree.SkillVisualsFolder
				created.Parent = plot
				folder = created
			end
			placeCopy(plot, template :: Model, source, folder, cut)
		end
	end
end

-- HideFromStage ≤ k caché (avec les descendants), le reste rendu à ses valeurs d'origine.
local function applyHide(plot: Model, state: PlotState, k: number)
	local wanted: { [Instance]: boolean } = {}
	for _, inst in plot:GetDescendants() do
		local from = inst:GetAttribute(HIDE_FROM)
		if type(from) == "number" and from <= k and not wanted[inst] then
			wanted[inst] = true
			for _, sub in inst:GetDescendants() do
				wanted[sub] = true
			end
		end
	end
	for inst, before in state.saved do
		if not wanted[inst] then
			state.saved[inst] = nil
			if inst:IsDescendantOf(plot) then
				restoreOne(inst, before)
			end
		end
	end
	for inst in wanted do
		hideOne(inst, state.saved)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function ShopStageService.Apply(plot: Model, level: number, unlocked: number?): number
	local k = if level == level then math.max(1, math.floor(level)) else 1
	local state = states[plot]
	if state == nil then
		state = { level = 1, saved = {}, depth = nil, slots = nil, points = {} } :: PlotState
		states[plot] = state
	end
	local current = state :: PlotState
	local template = templateOf()
	local back = if template then templateBack(template) else nil
	local depth = if back and k >= 2 then depthFor(plot, current, unlocked, back) else nil
	local depthChanged = depth ~= current.depth
	for j, stage in stagesOf(plot) do
		if j >= 2 and (j > k or depthChanged) then
			stage:Destroy() -- au-dessus du niveau, ou fond changé : refait depuis le gabarit plus bas
		end
	end
	local skillFolder = if depthChanged then plot:FindFirstChild(SkillTree.SkillVisualsFolder) else nil
	local visuals: { Instance } = if skillFolder then skillFolder:GetChildren() else {}
	for _, visual in visuals do
		local rule = SkillTree.PlotVisuals[visual.Name]
		if rule and rule.EveryStage then
			visual:Destroy()
		end
	end
	local rowCut = template ~= nil and template:GetAttribute(ShopGrowth.RowCutAttribute) == true
	local cut: Cut? = if depth and back then { depth = depth, back = back, pivot = plot:GetPivot(), rowCut = rowCut } else nil
	if template then
		for j, source in stagesOf(template) do
			if j >= 2 and j <= k and plot:FindFirstChild(source.Name) == nil then
				placeCopy(plot, template, source, nil, cut)
			end
		end
	end
	applyEveryStage(plot, template, k, cut)
	applyHide(plot, current, k)
	placePoints(plot, current, cut)
	if (current.level ~= k or depthChanged) and IS_STUDIO then
		print(`[ShopStageService] {plot.Name} : boutique niveau {current.level} → {k}, fond {if depth then string.format("%.1f", depth) else "entier"}`)
	end
	current.level = k
	current.depth = depth
	plot:SetAttribute(LEVEL_ATTRIBUTE, k)
	plot:SetAttribute(DEPTH_ATTRIBUTE, depth)
	return k
end

function ShopStageService.GetLevel(plot: Model): number
	local state = states[plot]
	return if state then state.level else 1
end

function ShopStageService.IsBeyond(plot: Model, inst: Instance): boolean
	local state = states[plot]
	local depth = if state then state.depth else nil
	if depth == nil then
		return false
	end
	local pivot = plot:GetPivot()
	local parts = inst:GetDescendants()
	table.insert(parts, inst)
	for _, part in parts do
		if part:IsA("BasePart") then
			local _, _, z1 = zSpan(pivot, part :: BasePart)
			if z1 > depth + EPS then
				return true
			end
		end
	end
	return false
end

return ShopStageService
