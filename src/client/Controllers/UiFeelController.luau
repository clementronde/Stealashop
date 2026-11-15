--!strict
-- UiFeelController (client, liaison L-091 point 7) : les animations d'UI « qui donnent envie de
-- toucher », branchées sur tous les écrans de Clément, valeurs dans Config/UiMotion (tableau de
-- docs/claude/notes/ui-motion-skilltree.md).
--
-- Rôle :
--   - Boutons : chaque GuiButton des écrans UI_* du PlayerGui (copies de StarterGui, et ce que les
--     contrôleurs y clonent ensuite) reçoit Motion.Button : survol (Hover, calque Shade, son
--     UI_Hover), appui (Press), relâché (Release). Les boutons nommés dans UiMotion.Success.Buttons
--     (Buy, Equip, Claim, Confirm, Place, Equip Best…) font en plus Motion.Success à chaque clic,
--     comme dans le prototype de Clément (tools/clement/ui_feel_proto.luau) : le serveur peut encore
--     refuser l'achat, le bouton a déjà sauté. Laissés de côté : le Template caché d'une liste (et ce
--     qu'il contient ; ses copies, elles, sont branchées), un bouton à la racine d'un écran (Motion.Open
--     met déjà la racine à l'échelle) et un bouton aussi grand que son parent (calque de glisser).
--   - Cartes : un cadre avec un enfant HoverOutline (Index, inventaire, boutiques…) reçoit
--     Motion.HoverCard (et pas l'effet de bouton) ; ses boutons à lui (PLACE…) gardent le leur.
--   - Sons d'UI : donne à Motion le moyen de les jouer (Shared/Anim/MarkerSounds, son 2D, rien s'il
--     manque dans ReplicatedStorage/Assets/Sounds : une ligne par son, en Studio).
--   - Poursuite (ChaseController.IsChased) : ChasePulse (la transparence des bords rouges de UI_Chase,
--     ScreenEdges et Vignette.Edge, bat en sinus) et ChaseFov (champ de vision de la caméra + Add). À
--     la fin, chaque transparence reprend sa valeur d'origine et la caméra son champ de vision.
--     RunBanner (L-092 3a) : entrée 0 → 1,18 → 1 par un UIScale passager (RunBanner.ScaleName),
--     puis il bat (+5 %) et penche (± 1,5°) au rythme des bords ; à la fin, UIScale détruit et
--     Rotation d'origine remise. Motion.KeepScale l'écarte de l'échelle de Motion.Open.
--   - Arrivée en zone safe avec un colis (L-095 point 4, SafeFlash ; remote BoxSecured d'UnboxService) :
--     Heist_SafeFlash puis Heist_Escape ; champ de vision rendu d'un coup par la poursuite, + FovAdd puis
--     retour ; UI_Escape allumé : Flash de FlashFrom à 1, Banner de 0 à 1 (Back Out), Title de TitleFrom
--     à sa Rotation, BoxIcon (Image = ICON_BOX_<Rareté>, sinon ICON_BOX_<Tier>) et Subtitle l'un après l'autre ; au bout de Hold
--     s, Banner rapetisse, puis l'écran s'éteint et tout reprend la valeur de Clément. L'effet FX_Escape
--     aux pieds du joueur est à VfxController.Escape (vague 26), appelé d'ici.
--     Vague 46 (a154) : même effet pour un OBJET sorti d'un colis (remote ItemSecured d'UnboxService) :
--     BoxIcon = icône de l'objet (ICON_<ItemId>), sinon ICON_BOX_<Rareté> ; Title = SafeFlash.ItemTitle et
--     Subtitle = « <Rareté> <Nom> » le temps de l'écran, puis les textes de Clément reviennent.
--   - Révélation d'un colis ouvert sur le rayon (vague 46, ShelfOpenController, chez l'ouvreur) :
--     RevealFlash, le même flash d'UI_Escape et le même zoom, sans la bannière (Banner à l'échelle 0 par un
--     UIScale passager), sans son ni FX_Escape. Une arrivée en cours garde sa bannière (seul le flash
--     repart) ; une arrivée qui suit une révélation la remplace. La caméra repart toujours du même champ
--     de vision de base : jamais bloquée en zoom.
-- Ce qui est touché, et rien d'autre : ce que fait Motion (UIScale passagers, Shade, HoverOutline, Icon
-- des cartes, tous remis ensuite), la transparence des bords de UI_Chase et RunBanner pendant la poursuite,
-- Camera.FieldOfView, et dans UI_Escape : Enabled, Flash.BackgroundTransparency, Title.Rotation, Title.Text
-- et Subtitle.Text (remis), BoxIcon.Image. Aucun objet n'est laissé une fois l'animation finie.
--
-- API (client) :
--   UiFeelController.Escape(tier?, rarity?, itemId?)  joue l'arrivée en zone safe (aussi pour un test en Studio)
--   UiFeelController.RevealFlash()                    flash et zoom de la révélation, sans bannière
--   UiFeelController.GetEscapeState()                 { Count, Active, Escaping, Reveals, Kind } (banc)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiMotion = require(Shared:WaitForChild("Config"):WaitForChild("UiMotion"))
local Settings = require(Shared:WaitForChild("Config"):WaitForChild("Settings"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type ChaseApi = { IsChased: () -> boolean }
type Pulse = { object: Instance, property: string, base: number }

local SCREEN_PREFIX = "UI_" -- écrans de Clément (contrat 2.2)
local CHASE_SCREEN = "UI_Chase"
local TEMPLATE = "Template"

local SUCCESS: { [string]: boolean } = {}
for _, name in UiMotion.Success.Buttons do
	SUCCESS[name] = true
end
local function successSkipped(button: Instance): boolean
	for _, screen in UiMotion.Success.SkipScreens do
		if button:FindFirstAncestor(screen) ~= nil then
			return true
		end
	end
	return false
end

local PULSE = UiMotion.ChasePulse
local FOV = UiMotion.ChaseFov
local FOV_IN_INFO = TweenInfo.new(FOV.InTime, FOV.Style, FOV.Direction)
local FOV_OUT_INFO = TweenInfo.new(FOV.OutTime, FOV.Style, FOV.Direction)
local BANNER = UiMotion.RunBanner
local BANNER_IN_INFO = TweenInfo.new(BANNER.InTime, BANNER.Style, BANNER.Direction)
local BANNER_SETTLE_INFO = TweenInfo.new(BANNER.SettleTime, BANNER.Style, BANNER.Direction)

local UiFeelController = {}

local localPlayer = Players.LocalPlayer
local chase: ChaseApi? = nil
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local successWired: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local chasing = false
local chaseStartedAt = 0
local pulses: { Pulse } = {}
local fovBase: number? = nil -- champ de vision d'avant la poursuite, remis à la fin
local fovTween: Tween? = nil
-- RunBanner pendant la poursuite (L-092 3a) : son UIScale passager, sa Rotation d'origine, et
-- `beating` une fois l'entrée finie.
type Banner = { object: GuiObject, scale: UIScale?, rotation: number, tween: Tween?, beating: boolean }
local banner: Banner? = nil

-- Arrivée en zone safe (SafeFlash, L-095 point 4) : l'écran UI_Escape en cours, ses tweens, ses UIScale
-- passagers, et les valeurs de Clément à remettre (Rotation de Title, transparence de Flash).
local SAFE = UiMotion.SafeFlash
local SAFE_FLASH_INFO = TweenInfo.new(SAFE.FlashTime, SAFE.FlashStyle, Enum.EasingDirection.Out)
local SAFE_FOV_IN_INFO = TweenInfo.new(SAFE.FovInTime, SAFE.FovStyle, Enum.EasingDirection.Out)
local SAFE_FOV_OUT_INFO = TweenInfo.new(SAFE.FovOutTime, SAFE.FovStyle, Enum.EasingDirection.Out)
local SAFE_BANNER_INFO = TweenInfo.new(SAFE.BannerTime, SAFE.BannerStyle, Enum.EasingDirection.Out)
local SAFE_TITLE_INFO = TweenInfo.new(SAFE.TitleTime, SAFE.BannerStyle, Enum.EasingDirection.Out)
local SAFE_PARTS_INFO = TweenInfo.new(SAFE.PartsTime, SAFE.BannerStyle, Enum.EasingDirection.Out)
local SAFE_OUT_INFO = TweenInfo.new(SAFE.OutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
-- Révélation d'un colis ouvert sur le rayon (vague 46) : le même flash et le même zoom, sans bannière.
local REVEAL = UiMotion.RevealFlash
local REVEAL_FLASH_INFO = TweenInfo.new(REVEAL.FlashTime, REVEAL.FlashStyle, Enum.EasingDirection.Out)
local REVEAL_FOV_IN_INFO = TweenInfo.new(REVEAL.FovInTime, REVEAL.FovStyle, Enum.EasingDirection.Out)
local REVEAL_FOV_OUT_INFO = TweenInfo.new(REVEAL.FovOutTime, REVEAL.FovStyle, Enum.EasingDirection.Out)
type Escape = {
	screen: ScreenGui,
	kind: string, -- "Escape" (arrivée, avec bannière) ou "Reveal" (flash seul)
	tweens: { Tween },
	scales: { UIScale },
	rotations: { [GuiObject]: number },
	transparencies: { [GuiObject]: number },
	texts: { [TextLabel]: string },
	visibles: { [GuiObject]: boolean },
	images: { [Instance]: string }, -- vague 51 (a165) : Image de Clément sur BoxIcon, remise par resetEscape
}
local escape: Escape? = nil
local escaping = false -- champ de vision de l'arrivée en zone safe en cours
local escapes = 0
local reveals = 0
local escapeMissingSaid = false
local IS_STUDIO = RunService:IsStudio()

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

------------------------------------------------------------------------------
-- Boutons et cartes
------------------------------------------------------------------------------

-- `inst` est le Template caché d'une liste, ou dedans.
local function inTemplate(inst: Instance): boolean
	local current: Instance? = inst
	while current ~= nil and not current:IsA("LayerCollector") do
		if current.Name == TEMPLATE then
			return true
		end
		current = current.Parent
	end
	return false
end

local function fillsParent(object: GuiObject): boolean
	local size = object.Size
	return size.X.Scale >= 1 and size.Y.Scale >= 1
end

local function wire(inst: Instance)
	if inst.Parent == nil or not inst:IsA("GuiObject") or inTemplate(inst) then
		return
	end
	local object = inst :: GuiObject
	if object:FindFirstChild(UiMotion.HoverCard.Outline) ~= nil then
		Motion.HoverCard(object)
		return
	end
	if not object:IsA("GuiButton") then
		return
	end
	local parent = object.Parent
	if parent == nil or parent:IsA("LayerCollector") or fillsParent(object) then
		return
	end
	local button = object :: GuiButton
	Motion.Button(button)
	if SUCCESS[button.Name] and not successWired[button] and not successSkipped(button) then
		successWired[button] = true
		button.Activated:Connect(function()
			Motion.Success(button)
		end)
	end
end

-- Un écran de Clément : ce qu'il contient, puis ce qui y arrive (copies des contrôleurs). Le
-- branchement attend la fin de l'image : une copie renommée juste après son arrivée n'est plus
-- « Template ».
local function watchScreen(screen: Instance)
	if watched[screen] or not screen:IsA("LayerCollector") or string.sub(screen.Name, 1, #SCREEN_PREFIX) ~= SCREEN_PREFIX then
		return
	end
	watched[screen] = true
	if screen.Name == CHASE_SCREEN then
		-- RunBanner s'anime à part (L-092 3a) : Motion.Open ne le met pas à l'échelle.
		local runBanner = screen:FindFirstChild(BANNER.Name, true)
		if runBanner and runBanner:IsA("GuiObject") then
			Motion.KeepScale(runBanner)
		end
	end
	screen.DescendantAdded:Connect(function(descendant: Instance)
		task.defer(wire, descendant)
	end)
	for _, descendant in screen:GetDescendants() do
		wire(descendant)
	end
end

------------------------------------------------------------------------------
-- Poursuite : bords qui battent (ChasePulse) et champ de vision (ChaseFov)
------------------------------------------------------------------------------

local function addPulse(object: Instance, property: string)
	table.insert(pulses, { object = object, property = property, base = (object :: any)[property] })
end

local function collectPulses()
	table.clear(pulses)
	local gui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local screen = if gui then gui:FindFirstChild(CHASE_SCREEN) else nil
	if screen == nil then
		return
	end
	for _, path in PULSE.Targets do
		local target = Find.path(screen, path)
		if target and target:IsA("GuiObject") then
			if target:IsA("ImageLabel") or target:IsA("ImageButton") then
				addPulse(target, "ImageTransparency")
			else
				-- Un cadre : ses images, sinon son propre fond.
				local images = 0
				for _, child in target:GetDescendants() do
					if child:IsA("ImageLabel") or child:IsA("ImageButton") then
						addPulse(child, "ImageTransparency")
						images += 1
					end
				end
				if images == 0 then
					-- Un cadre transparent (ScreenEdges, plein écran) n'est qu'un conteneur : ce sont ses
					-- bandes (Left, Right, Bottom) qui battent, sinon tout l'écran se voile de gris.
					if (target :: GuiObject).BackgroundTransparency < 1 then
						addPulse(target, "BackgroundTransparency")
					else
						for _, child in target:GetChildren() do
							if child:IsA("GuiObject") and child.BackgroundTransparency < 1 then
								addPulse(child, "BackgroundTransparency")
							end
						end
					end
				end
			end
		end
	end
end

local function restorePulses()
	for _, pulse in pulses do
		if pulse.object.Parent ~= nil then
			(pulse.object :: any)[pulse.property] = pulse.base
		end
	end
	table.clear(pulses)
end

local function tweenFov(goal: number, info: TweenInfo, finish: (() -> ())?)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local previous = fovTween
	if previous then
		previous:Cancel()
	end
	local tween = TweenService:Create(camera, info, { FieldOfView = goal })
	fovTween = tween
	tween.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and fovTween == tween then
			fovTween = nil
			if finish then
				finish()
			end
		end
	end)
	tween:Play()
end

-- RunBanner (L-092 3a) : entrée 0 → Peak → 1 par son UIScale passager, puis battement et
-- inclinaison au rythme des bords (step). Un UIScale qui n'est pas le sien (Clément) : pas d'échelle.
local function startBanner()
	local gui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local screen = if gui then gui:FindFirstChild(CHASE_SCREEN) else nil
	local found = if screen then screen:FindFirstChild(BANNER.Name, true) else nil
	if found == nil or not found:IsA("GuiObject") then
		return
	end
	local object = found :: GuiObject
	Motion.KeepScale(object)
	local state: Banner = { object = object, scale = nil, rotation = object.Rotation, tween = nil, beating = false }
	banner = state
	if object:FindFirstChildOfClass("UIScale") ~= nil then
		state.beating = true
		return
	end
	local scale = Instance.new("UIScale")
	scale.Name = BANNER.ScaleName
	scale.Scale = 0
	scale.Parent = object
	state.scale = scale
	local enter = TweenService:Create(scale, BANNER_IN_INFO, { Scale = BANNER.Peak })
	state.tween = enter
	enter.Completed:Connect(function(playback: Enum.PlaybackState)
		if playback ~= Enum.PlaybackState.Completed or banner ~= state then
			return
		end
		local settle = TweenService:Create(scale, BANNER_SETTLE_INFO, { Scale = 1 })
		state.tween = settle
		settle.Completed:Connect(function(settled: Enum.PlaybackState)
			if settled == Enum.PlaybackState.Completed and banner == state then
				state.tween = nil
				state.beating = true
			end
		end)
		settle:Play()
	end)
	enter:Play()
end

-- Fin de la poursuite : UIScale détruit, Rotation d'origine remise.
local function stopBanner()
	local state = banner
	if state == nil then
		return
	end
	banner = nil
	local tween = state.tween
	if tween then
		tween:Cancel()
	end
	local scale = state.scale
	if scale then
		scale:Destroy()
	end
	if state.object.Parent ~= nil then
		state.object.Rotation = state.rotation
	end
end

-- Battement (+Beat quand les bords sont le plus visibles) et inclinaison (± Tilt degrés).
local function beatBanner(elapsed: number)
	local state = banner
	if state == nil or not state.beating or state.object.Parent == nil then
		return
	end
	local phase = 2 * math.pi * PULSE.Rate * elapsed
	local scale = state.scale
	if scale then
		scale.Scale = 1 + BANNER.Beat * (0.5 - 0.5 * math.sin(phase))
	end
	state.object.Rotation = state.rotation + BANNER.Tilt * math.sin(phase)
end

local function startChase()
	chaseStartedAt = os.clock()
	collectPulses()
	startBanner()
	escaping = false -- une nouvelle poursuite reprend la caméra
	local camera = Workspace.CurrentCamera
	-- VISUAL EFFECTS sur OFF (L-095, vague 24) : pas de ChaseFov, la caméra garde son champ de vision.
	if camera and not Settings.VfxReduced(localPlayer) then
		if fovBase == nil then
			fovBase = camera.FieldOfView
		end
		tweenFov((fovBase :: number) + FOV.Add, FOV_IN_INFO, nil)
	end
end

local function stopChase()
	restorePulses()
	stopBanner()
	local base = fovBase
	if base and not escaping then -- arrivée en zone safe en cours : elle rend elle-même le champ de vision
		tweenFov(base, FOV_OUT_INFO, function()
			fovBase = nil
		end)
	end
end

------------------------------------------------------------------------------
-- Arrivée en zone safe avec un colis (SafeFlash, L-095 point 4) : UI_Escape, sons, champ de vision
------------------------------------------------------------------------------

-- Champ de vision : depuis le champ de vision actuel (vague 51, plus d'à-coup vers 70), + FovAdd en FovInTime et
-- retour en FovOutTime. Vague 46 : la révélation passe ici avec ses réglages (RevealFlash) ; un 2e appel
-- pendant le 1er repart du même champ de vision de base (fovBase), et une poursuite encore en cours à la
-- fin retrouve son ChaseFov.
local function escapeFov(add: number?, inInfo: TweenInfo?, outInfo: TweenInfo?)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local base = fovBase or camera.FieldOfView
	fovBase = base
	local previous = fovTween
	if previous then
		fovTween = nil
		previous:Cancel()
	end
	-- Vague 51 (a165) : le zoom part du champ de vision actuel (poursuite, 2e colis), sans le remettre à la
	-- base d'un coup ; le retour se fait toujours vers la base.
	escaping = true
	tweenFov(base + (add or SAFE.FovAdd), inInfo or SAFE_FOV_IN_INFO, function()
		tweenFov(base, outInfo or SAFE_FOV_OUT_INFO, function()
			escaping = false
			if not chasing then
				fovBase = nil
			elseif not Settings.VfxReduced(localPlayer) then
				tweenFov(base + FOV.Add, FOV_IN_INFO, nil)
			end
		end)
	end)
end

-- Remet UI_Escape comme Clément l'a fait : UIScale passagers détruits, Rotation de Title et
-- transparence de Flash d'origine.
local function resetEscape()
	local state = escape
	escape = nil
	if state == nil then
		return
	end
	for _, tween in state.tweens do
		tween:Cancel()
	end
	for _, scale in state.scales do
		scale:Destroy()
	end
	for object, rotation in state.rotations do
		if object.Parent ~= nil then
			object.Rotation = rotation
		end
	end
	for object, transparency in state.transparencies do
		if object.Parent ~= nil then
			object.BackgroundTransparency = transparency
		end
	end
	for label, text in state.texts do
		if label.Parent ~= nil then
			label.Text = text
		end
	end
	for object, visible in state.visibles do
		if object.Parent ~= nil then
			object.Visible = visible
		end
	end
	for object, image in state.images do
		if object.Parent ~= nil then
			(object :: any).Image = image
		end
	end
end

-- Texte passager (objet ramené) : celui de Clément est gardé et remis par resetEscape.
local function escapeText(state: Escape, object: Instance?, text: string?)
	if text == nil or object == nil or not object:IsA("TextLabel") then
		return
	end
	local label = object :: TextLabel
	if state.texts[label] == nil then
		state.texts[label] = label.Text
	end
	label.Text = text
end

local function escapePlay(state: Escape, tween: Tween)
	table.insert(state.tweens, tween)
	tween:Play()
end

-- UIScale passager à `value` (rien si l'objet a déjà un UIScale, celui de Clément).
local function escapeScale(state: Escape, object: GuiObject, value: number): UIScale?
	if object:FindFirstChildOfClass("UIScale") ~= nil then
		return nil
	end
	local scale = Instance.new("UIScale")
	scale.Name = SAFE.ScaleName
	scale.Scale = value
	scale.Parent = object
	table.insert(state.scales, scale)
	return scale
end

-- Icône de BoxIcon : celle de l'objet (ICON_<ItemId>, vague 46) s'il y en a un, sinon ICON_BOX_<Rareté>
-- (L-097 point 3), sinon ICON_BOX_<Tier>.
local function boxIcon(tier: string?, rarity: string?, itemId: string?): string?
	local ok, texture = pcall(function()
		local Icons = require(Shared:WaitForChild("Contract"):WaitForChild("Icons")) :: any
		local byItem = if type(itemId) == "string" and itemId ~= "" then Icons.get(itemId) else nil
		local byRarity = if type(rarity) == "string" and rarity ~= "" then Icons.get(SAFE.BoxIconPrefix .. rarity) else nil
		local byTier = if type(tier) == "string" and tier ~= "" then Icons.get(SAFE.BoxIconPrefix .. tier) else nil
		return byItem or byRarity or byTier
	end)
	return if ok and type(texture) == "string" then texture else nil
end

-- Objet du catalogue (vague 46) : sa rareté et « <Rareté> <Nom> » (SafeFlash.ItemSubtitle) ; nil s'il est inconnu.
local function itemInfo(itemId: string?): (string?, string?)
	if type(itemId) ~= "string" or itemId == "" then
		return nil, nil
	end
	local ok, rarity, text = pcall(function(): (string?, string?)
		local Config = Shared:WaitForChild("Config")
		local Items = require(Config:WaitForChild("Items")) :: any
		local Rarities = require(Config:WaitForChild("Rarities")) :: any
		local def = Items.ById[itemId]
		if def == nil then
			return nil, nil
		end
		local rarityDef = Rarities.ById[def.Rarity]
		local rarityName = if rarityDef then rarityDef.DisplayName else def.Rarity
		return def.Rarity, string.format(SAFE.ItemSubtitle, tostring(rarityName), tostring(def.DisplayName))
	end)
	if not ok then
		return nil, nil
	end
	return rarity, text
end

local function findEscapeScreen(): ScreenGui?
	local gui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local found = if gui then gui:FindFirstChild(SAFE.Screen) else nil
	if found == nil or not found:IsA("ScreenGui") then
		if IS_STUDIO and not escapeMissingSaid then
			escapeMissingSaid = true
			print(`[UiFeel] {SAFE.Screen} absent du PlayerGui : arrivée en zone safe sans écran (sons et caméra seulement)`)
		end
		return nil
	end
	return found :: ScreenGui
end

local function newEscape(screen: ScreenGui, kind: string): Escape
	resetEscape()
	local state: Escape =
		{ screen = screen, kind = kind, tweens = {}, scales = {}, rotations = {}, transparencies = {}, texts = {}, visibles = {}, images = {} }
	escape = state
	screen.Enabled = true
	return state
end

-- Flash : de `from` à 1 ; la transparence de Clément est gardée une seule fois par écran.
local function escapeFlash(state: Escape, from: number, info: TweenInfo)
	local flash = Find.path(state.screen, "Flash")
	if flash and flash:IsA("GuiObject") then
		if state.transparencies[flash] == nil then
			state.transparencies[flash] = flash.BackgroundTransparency
		end
		flash.BackgroundTransparency = from
		escapePlay(state, TweenService:Create(flash, info, { BackgroundTransparency = 1 }))
	end
end

-- Éteint l'écran au bout de `delay` s s'il montre toujours `state`.
local function closeEscapeLater(state: Escape, delay: number)
	task.delay(delay, function()
		if escape ~= state then
			return
		end
		resetEscape()
		if state.screen.Parent ~= nil then
			state.screen.Enabled = false
		end
	end)
end

local function escapeScreen(tier: string?, rarity: string?, itemId: string?)
	local screen = findEscapeScreen()
	if screen == nil then
		return
	end
	local state = newEscape(screen, "Escape")
	escapeFlash(state, SAFE.FlashFrom, SAFE_FLASH_INFO)

	-- Objet ramené (vague 46) : Title et Subtitle passagers, remis par resetEscape.
	local itemRarity, itemText = itemInfo(itemId)
	local foundBanner = Find.path(screen, "Banner")
	local banner: GuiObject? = if foundBanner and foundBanner:IsA("GuiObject") then foundBanner :: GuiObject else nil
	local bannerScale = if banner then escapeScale(state, banner, 0) else nil
	if bannerScale then
		local scale: UIScale = bannerScale
		task.delay(SAFE.BannerDelay, function()
			if escape == state then
				escapePlay(state, TweenService:Create(scale, SAFE_BANNER_INFO, { Scale = 1 }))
			end
		end)
	end
	if banner then
		local title = Find.path(banner, "Title")
		if title and title:IsA("GuiObject") then
			state.rotations[title] = title.Rotation
			local goal = title.Rotation
			title.Rotation = SAFE.TitleFrom
			escapePlay(state, TweenService:Create(title, SAFE_TITLE_INFO, { Rotation = goal }))
		end
		if itemText then
			escapeText(state, title, SAFE.ItemTitle)
			escapeText(state, Find.path(banner, "Subtitle"), itemText)
		end
		local icon = Find.path(banner, "BoxIcon")
		local texture = boxIcon(tier, itemRarity or rarity, itemId)
		if texture and icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
			if state.images[icon] == nil then
				state.images[icon] = (icon :: any).Image
			end
			(icon :: any).Image = texture
		end
		for rank, name in SAFE.Parts do
			local part = Find.path(banner, name)
			local partScale = if part and part:IsA("GuiObject") then escapeScale(state, part :: GuiObject, 0) else nil
			if partScale then
				local scale: UIScale = partScale
				task.delay(SAFE.PartsDelay + rank * SAFE.PartsGap, function()
					if escape == state then
						escapePlay(state, TweenService:Create(scale, SAFE_PARTS_INFO, { Scale = 1 }))
					end
				end)
			end
		end
	end

	task.delay(SAFE.Hold, function()
		if escape ~= state then
			return
		end
		if bannerScale then
			escapePlay(state, TweenService:Create(bannerScale, SAFE_OUT_INFO, { Scale = 0 }))
		end
		closeEscapeLater(state, SAFE.OutTime)
	end)
end

-- L'arrivée en zone safe : sons (Heist_SafeFlash, puis Heist_Escape SoundGap s après), champ de
-- vision, écran UI_Escape (Flash, puis Banner, Title, BoxIcon, Subtitle), FX_Escape. `itemId` (vague 46,
-- remote ItemSecured) : objet ramené, son icône et son nom.
function UiFeelController.Escape(tier: string?, rarity: string?, itemId: string?)
	escapes += 1
	for rank, name in SAFE.Sounds do
		if rank == 1 then
			Motion.PlaySound(name)
		else
			task.delay((rank - 1) * SAFE.SoundGap, function()
				Motion.PlaySound(name)
			end)
		end
	end
	escapeFov()
	escapeScreen(tier, rarity, itemId)
	-- Confettis, étoiles et anneau de FX_Escape aux pieds du joueur (vague 26, VfxController).
	local vfx = sibling("VfxController")
	if vfx and type(vfx.Escape) == "function" then
		task.spawn(vfx.Escape)
	end
end

-- Révélation d'un colis ouvert (vague 46, ShelfOpenController, chez l'ouvreur) : flash d'UI_Escape et zoom,
-- sans bannière, sans son ni FX_Escape. Une arrivée en cours garde son écran : seul le flash repart.
function UiFeelController.RevealFlash()
	reveals += 1
	escapeFov(REVEAL.FovAdd, REVEAL_FOV_IN_INFO, REVEAL_FOV_OUT_INFO)
	local current = escape
	if current and current.kind == "Escape" then
		escapeFlash(current, REVEAL.FlashFrom, REVEAL_FLASH_INFO)
		return
	end
	local screen = findEscapeScreen()
	if screen == nil then
		return
	end
	local state = newEscape(screen, "Reveal")
	local banner = Find.path(screen, "Banner")
	if banner and banner:IsA("GuiObject") and escapeScale(state, banner :: GuiObject, 0) == nil then
		-- Banner a déjà un UIScale (celui de Clément) : caché le temps du flash, remis par resetEscape.
		local object = banner :: GuiObject
		state.visibles[object] = object.Visible
		object.Visible = false
	end
	escapeFlash(state, REVEAL.FlashFrom, REVEAL_FLASH_INFO)
	closeEscapeLater(state, REVEAL.FlashTime)
end

-- Arrivées en zone safe et révélations jouées depuis le démarrage, et l'écran en cours (banc, barre de commande).
function UiFeelController.GetEscapeState(): { Count: number, Active: boolean, Escaping: boolean, Reveals: number, Kind: string? }
	local current = escape
	return {
		Count = escapes,
		Active = current ~= nil,
		Escaping = escaping,
		Reveals = reveals,
		Kind = if current then current.kind else nil,
	}
end

local function step()
	local api = chase
	local now = api ~= nil and api.IsChased()
	if now ~= chasing then
		chasing = now
		if now then
			startChase()
		else
			stopChase()
		end
	end
	if not chasing then
		return
	end
	beatBanner(os.clock() - chaseStartedAt)
	if #pulses == 0 then
		return
	end
	local wave = 0.5 + 0.5 * math.sin(2 * math.pi * PULSE.Rate * (os.clock() - chaseStartedAt))
	local value = PULSE.Min + (PULSE.Max - PULSE.Min) * wave
	for _, pulse in pulses do
		if pulse.object.Parent ~= nil then
			(pulse.object :: any)[pulse.property] = value
		end
	end
end

------------------------------------------------------------------------------

function UiFeelController.Start()
	local ok, markerSounds = pcall(function()
		return require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds")) :: any
	end)
	if ok and type(markerSounds) == "table" then
		Motion.SetSoundPlayer(function(name: string)
			markerSounds.play(name, nil) -- son 2D, pour le joueur local seulement
		end)
	end
	chase = sibling("ChaseController")
	RunService.Heartbeat:Connect(step)
	-- Colis mis à l'abri en zone safe (UnboxService, remote BoxSecured) : l'arrivée en zone safe. Un
	-- arbre sans ce remote (ancien Net/Definitions) : rien.
	task.spawn(function()
		local wired = pcall(function()
			local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
			Net.Client.BoxSecured:Connect(function(tier: string, rarity: string?)
				UiFeelController.Escape(tier, rarity)
			end)
		end)
		-- Vague 46 : objet sorti d'un colis, mis à l'abri en zone safe (UnboxService, remote ItemSecured).
		pcall(function()
			local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
			Net.Client.ItemSecured:Connect(function(itemId: string)
				UiFeelController.Escape(nil, nil, itemId)
			end)
		end)
		if not wired and IS_STUDIO then
			print("[UiFeel] remote BoxSecured absent : pas d'arrivée en zone safe (UI_Escape)")
		end
	end)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(watchScreen)
	for _, child in playerGui:GetChildren() do
		watchScreen(child)
	end
end

return UiFeelController
