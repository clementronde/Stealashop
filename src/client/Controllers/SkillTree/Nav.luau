--!strict
-- SkillTree/Nav (vague 27, L-096 point 2, client) : navigation dans l'arbre de UI_SkillTree (glisser, molette,
-- pincement, clic sur une tuile), valeurs dans Config/UiMotion.SkillTree (T.67 à T.74 de
-- docs/claude/notes/ui-motion-skilltree.md ; prototype tools/clement/skilltree_proto.luau). Module d'aide de
-- SkillTreeController, rangé dans un sous-dossier : le Loader ne le démarre pas.
--
-- Une couche NavLayer (TextButton plein écran, transparent, posé ici) est au-dessus de l'arbre et sous le
-- panneau, l'argent et Close (ZIndex UiMotion.SkillTree.NavLayerZIndex). Elle reçoit l'appui (souris ou doigt),
-- le survol et la molette ; les mouvements et les relâchés suivent UserInputService, pour qu'un glisser qui
-- passe sur le panneau ne se perde pas. L'écran a IgnoreGuiInset, mais input.Position se compare tel quel aux
-- AbsolutePosition (même repère, sous la barre du haut).
--   - Appui puis relâché à moins de DragThreshold px : clic sur la tuile sous le pointeur (test « point dans
--     l'hexagone », la plus proche si deux se touchent).
--   - Au-delà : l'arbre suit le pointeur 1 pour 1 (Tree.Position, en Offset) ; au plus PanLimit de sa taille
--     zoomée, puis il suit à Rubber (élastique) ; au relâché, il revient à la limite en SnapTime (Back Out).
--   - Molette : ±ZoomStep par cran, lissé en ZoomTime ; le point sous le pointeur y reste.
--   - Deux doigts : zoom = zoom de départ × écart des doigts / écart de départ, autour de leur milieu.
--   - Zoom de ZoomMin à ZoomMax, par un UIScale ZoomScaleName sur Tree. À l'ouverture (Nav.reset) : 1, ou
--     plus pour que les tuiles fassent au moins StartTilePx, et le déplacement repart de 0.
-- Ce qui est touché : Tree.Position (décalage ajouté à la Position de Clément, remise à l'identique au départ
-- à 0), le UIScale de zoom, et la couche NavLayer. Rien d'autre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UiMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiMotion"))
local Fx = require(script.Parent:WaitForChild("Fx"))

local M = UiMotion.SkillTree
local LAYER_NAME = "NavLayer"
local MOUSE_KEY = "mouse" -- un seul pointeur souris (l'InputObject du relâché peut être un autre objet)

export type Handlers = {
	tiles: () -> { GuiObject }, -- tuiles qu'on peut viser (hexagones)
	tap: (tile: GuiObject) -> (), -- clic sans glisser sur une tuile
	hover: (tile: GuiObject?) -> (), -- tuile sous la souris (nil : aucune)
	press: (tile: GuiObject) -> (), -- tuile enfoncée
	release: (tile: GuiObject) -> (), -- tuile relâchée (clic ou glisser)
}

export type Nav = {
	layer: TextButton,
	-- Ouverture : déplacement à 0, zoom de départ (T.72) ; renvoie la largeur d'une tuile au zoom 1 (px).
	reset: () -> number,
	-- Zoom `zoom` autour du point `point` (px de l'écran), lissé ; pour la molette, le pincement et un test.
	zoomAt: (point: Vector2, zoom: number) -> (),
	-- Décale l'arbre (borné, sans élastique) ; pour un test ou la barre de commande.
	panBy: (delta: Vector2) -> (),
	view: () -> (number, Vector2), -- zoom et décalage visés
	tileAt: (point: Vector2) -> GuiObject?,
	-- Point d'un InputObject dans le repère des AbsolutePosition de l'écran.
	pointOf: (input: InputObject) -> Vector2,
	destroy: () -> (),
}

local Nav = {}

local function count(map: { [any]: Vector2 }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

-- Les deux premiers pointeurs.
local function pair(map: { [any]: Vector2 }): (Vector2?, Vector2?)
	local a: Vector2? = nil
	local b: Vector2? = nil
	for _, point in map do
		if a == nil then
			a = point
		elseif b == nil then
			b = point
		end
	end
	return a, b
end

-- `point` est dans l'hexagone (pointe en haut) inscrit dans le cadre de `tile`.
local function inHex(point: Vector2, tile: GuiObject): boolean
	local size = tile.AbsoluteSize
	local half = size.X * 0.95 / 2
	if half <= 0 then
		return false
	end
	local center = tile.AbsolutePosition + size / 2
	local x = math.abs(point.X - center.X) / half
	local y = math.abs(point.Y - center.Y) / half
	return x <= 1 and y <= 1 - x / 2
end

function Nav.new(gui: ScreenGui, tree: GuiObject, handlers: Handlers): Nav
	local base = tree.Position -- Position de Clément
	local zoomScale = Instance.new("UIScale")
	zoomScale.Name = M.ZoomScaleName
	zoomScale.Scale = 1
	zoomScale.Parent = tree

	local layer = Instance.new("TextButton")
	layer.Name = LAYER_NAME
	layer.Text = ""
	layer.AutoButtonColor = false
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = M.NavLayerZIndex
	layer.Active = true
	layer.Parent = gui

	local zoom = 1
	local pan = Vector2.zero
	local pointers: { [any]: Vector2 } = {}
	local downPoint: Vector2? = nil
	local panStart = Vector2.zero
	local dragging = false
	local pressed: GuiObject? = nil
	local hovered: GuiObject? = nil
	local pinch: { distance: number, zoom: number }? = nil
	local connections: { RBXScriptConnection } = {}

	-- input.Position et AbsolutePosition sont dans le même repère (sous la barre du haut), même avec
	-- IgnoreGuiInset (l'écran y commence à -GetGuiInset) : rien à ajouter. Ajouter l'inset décalait le point
	-- visé de 58 px vers le bas (vu en Play le 2026-11-11 : un clic dans le bas d'une tuile ne la prenait pas).
	local function pointOf(input: InputObject): Vector2
		return Vector2.new(input.Position.X, input.Position.Y)
	end

	local function tileAt(point: Vector2): GuiObject?
		local best: GuiObject? = nil
		local bestDistance = math.huge
		for _, tile in handlers.tiles() do
			if tile.Visible and inHex(point, tile) then
				local center = tile.AbsolutePosition + tile.AbsoluteSize / 2
				local distance = (point - center).Magnitude
				if distance < bestDistance then
					best, bestDistance = tile, distance
				end
			end
		end
		return best
	end

	-- Taille de l'arbre avant le zoom (px).
	local function treeSize(): Vector2
		local scale = zoomScale.Scale
		return if scale > 0 then tree.AbsoluteSize / scale else tree.AbsoluteSize
	end

	-- Décalage borné (soft : élastique au-delà de la limite).
	local function clampPan(value: Vector2, atZoom: number, soft: boolean): Vector2
		local limit = treeSize() * atZoom * M.PanLimit
		local function axis(v: number, l: number): number
			if math.abs(v) <= l then
				return v
			end
			local excess = math.abs(v) - l
			return math.sign(v) * (l + (if soft then excess * M.Rubber else 0))
		end
		return Vector2.new(axis(value.X, limit.X), axis(value.Y, limit.Y))
	end

	local function apply(time: number?)
		local position = base + UDim2.fromOffset(pan.X, pan.Y)
		if time and time > 0 then
			local smooth = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Fx.tween(tree, smooth, { Position = position })
			Fx.tween(zoomScale, smooth, { Scale = zoom })
		else
			Fx.stop(tree, "Position")
			Fx.stop(zoomScale, "Scale")
			tree.Position = position
			zoomScale.Scale = zoom
		end
	end

	-- Point d'ancrage de Tree à l'écran (le zoom se fait autour de lui), décalage compris.
	local function anchorPoint(): Vector2
		local parent = tree.Parent
		local origin = Vector2.zero
		local size = gui.AbsoluteSize
		if parent and parent:IsA("GuiBase2d") then
			origin = (parent :: GuiBase2d).AbsolutePosition
			size = (parent :: GuiBase2d).AbsoluteSize
		end
		return origin + Vector2.new(base.X.Scale * size.X + base.X.Offset, base.Y.Scale * size.Y + base.Y.Offset) + pan
	end

	local function zoomAt(point: Vector2, wanted: number)
		local target = math.clamp(wanted, M.ZoomMin, M.ZoomMax)
		local ratio = target / zoom
		pan += (point - anchorPoint()) * (1 - ratio)
		zoom = target
		pan = clampPan(pan, zoom, false)
		apply(M.ZoomTime)
	end

	local function setHover(tile: GuiObject?)
		if tile == hovered then
			return
		end
		hovered = tile
		handlers.hover(tile)
	end

	local function releasePressed()
		local tile = pressed
		pressed = nil
		if tile then
			handlers.release(tile)
		end
	end

	local function startPinch()
		local a, b = pair(pointers)
		if a and b then
			pinch = { distance = math.max((a - b).Magnitude, 1), zoom = zoom }
		end
		releasePressed()
		dragging = true
	end

	-- Clé d'un pointeur : l'InputObject d'un doigt, MOUSE_KEY pour le clic gauche, nil pour le reste.
	local function keyOf(input: InputObject): any
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch then
			return input
		elseif kind == Enum.UserInputType.MouseButton1 then
			return MOUSE_KEY
		end
		return nil
	end

	local function onBegan(input: InputObject)
		local key = keyOf(input)
		if key == nil or not gui.Enabled then
			return
		end
		local point = pointOf(input)
		pointers[key] = point
		local n = count(pointers)
		if n == 1 then
			downPoint, panStart, dragging = point, pan, false
			local tile = tileAt(point)
			pressed = tile
			if tile then
				handlers.press(tile)
			end
		elseif n == 2 then
			startPinch()
		end
	end

	local function onMoved(input: InputObject)
		local kind = input.UserInputType
		local key: any = nil
		if kind == Enum.UserInputType.Touch then
			key = input
		elseif kind == Enum.UserInputType.MouseMovement then
			key = MOUSE_KEY
		else
			return
		end
		if not pointers[key] then
			return
		end
		local point = pointOf(input)
		pointers[key] = point
		local current = pinch
		if current and count(pointers) >= 2 then
			local a, b = pair(pointers)
			if a and b then
				zoomAt((a + b) / 2, current.zoom * (a - b).Magnitude / current.distance)
			end
			return
		end
		local start = downPoint
		if start == nil then
			return
		end
		local delta = point - start
		if not dragging and delta.Magnitude > M.DragThreshold then
			dragging = true
			releasePressed()
			setHover(nil)
		end
		if dragging then
			pan = clampPan(panStart + delta, zoom, true)
			apply(0)
		end
	end

	local function onEnded(input: InputObject)
		local key = keyOf(input)
		if key == nil or not pointers[key] then
			return
		end
		pointers[key] = nil
		local left = count(pointers)
		if left > 0 then
			-- Un doigt reste après un pincement : il reprend le glisser d'où en est l'arbre.
			pinch = nil
			local a = pair(pointers)
			downPoint, panStart = a, pan
			return
		end
		pinch = nil
		if not dragging and pressed then
			local tile = pressed :: GuiObject
			releasePressed()
			handlers.tap(tile)
		end
		releasePressed()
		if dragging then
			local target = clampPan(pan, zoom, false)
			if target ~= pan then
				pan = target
				local snap = TweenInfo.new(M.SnapTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				Fx.tween(tree, snap, { Position = base + UDim2.fromOffset(pan.X, pan.Y) })
			end
		end
		dragging, downPoint = false, nil
	end

	table.insert(connections, layer.InputBegan:Connect(onBegan))
	table.insert(connections, layer.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			zoomAt(pointOf(input), zoom * (1 + M.ZoomStep * input.Position.Z))
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and next(pointers) == nil then
			setHover(tileAt(pointOf(input)))
		end
	end))
	table.insert(connections, layer.MouseLeave:Connect(function()
		if next(pointers) == nil then
			setHover(nil)
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(onMoved))
	table.insert(connections, UserInputService.InputEnded:Connect(onEnded))

	local nav: Nav
	nav = {
		layer = layer,
		reset = function()
			table.clear(pointers)
			pinch, pressed, dragging, downPoint = nil, nil, false, nil
			setHover(nil)
			-- T.72 : tuiles d'au moins StartTilePx. Largeur d'une tuile au zoom 1, sans son propre UIScale
			-- (mesurée avant tout changement : taille, zoom et échelle de la même image).
			local width = 0
			local current = zoomScale.Scale
			for _, tile in handlers.tiles() do
				local own = tile:FindFirstChild(M.ScaleName)
				local ownScale = if own and own:IsA("UIScale") then (own :: UIScale).Scale else 1
				if ownScale > 0 and current > 0 then
					width = math.max(width, tile.AbsoluteSize.X / (ownScale * current))
				end
			end
			zoom, pan = 1, Vector2.zero
			if width > 0 and width < M.StartTilePx then
				zoom = math.clamp(M.StartTilePx / width, 1, M.ZoomMax)
			end
			apply(0)
			return width
		end,
		zoomAt = zoomAt,
		panBy = function(delta: Vector2)
			pan = clampPan(pan + delta, zoom, false)
			apply(0)
		end,
		view = function(): (number, Vector2)
			return zoom, pan
		end,
		tileAt = tileAt,
		pointOf = pointOf,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			layer:Destroy()
		end,
	}
	return nav
end

return Nav
