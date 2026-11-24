--!nocheck
---------------------------------------------------------------- scénario « nav » : NavLayer, clic, glisser, zoom
start85({
	Cash = 1_000_000,
	Skill_ShopLevel = 1,
	Skill_GlassThickness = 2,
	Skill_GlassRegen = 0,
	Skill_Cameras = 0,
	Skill_Bodyguards = 0,
	Skill_PotionLuck = 0,
	Skill_Curtain = 0,
	Skill_DoorGuard = 0,
	Skill_PotionTime = 0,
	Skill_Traps = 0,
	Skill_Safe = 0,
})
local base = TREE.Position
SKILL.Open()
step(1.6)
local nav = SKILL.GetNav()
local function view()
	local state = SKILL.GetState()
	return state.Zoom, state.Pan
end

section("N1. Couche NavLayer posée par le code (T.74)")
local navLayer = layer()
check(navLayer and navLayer.ClassName == "TextButton" and navLayer.Text == "" and navLayer.BackgroundTransparency == 1, "N1a NavLayer : TextButton transparent sans texte")
check(navLayer.Size.X.Scale == 1 and navLayer.Size.Y.Scale == 1 and navLayer.Active == true and navLayer.ZIndex == ST.NavLayerZIndex, `N1b plein écran, Active, ZIndex {ST.NavLayerZIndex}`)
check(navLayer.ZIndex > TREE.ZIndex and navLayer.ZIndex < GUI.InfoPanel.ZIndex and navLayer.ZIndex < GUI.CloseButton.ZIndex, "N1c au-dessus de Tree, sous le panneau et Close")
local zoom, pan = view()
check(zoom == 1 and pan.X == 0 and pan.Y == 0 and zoomScale() and zoomScale().Scale == 1, "N1d ouverture sur PC (tuiles de 150 px) : zoom 1, décalage 0 (T.72)")
check(fxScale(TREE) == nil and scaleNamed(TREE, UiMotionC.ScaleName) == nil, "N1e Tree : seulement son UIScale de zoom (Motion.Open ne le met pas à l'échelle)")

section("N2. Clic sur une tuile (test « point dans l'hexagone », GetGuiInset)")
local glass = tile("Tile_Glass")
local c = centerOf(glass)
check(math.abs(c.X - 618) < 0.01 and math.abs(c.Y - 360) < 0.01, "N2a Glass au centre (618, 360) (montage du banc)")
local point = nav.pointOf({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(618, 360, 0) })
check(point.X == 618 and point.Y == 360, "N2b input.Position tel quel = repère des AbsolutePosition (IgnoreGuiInset : rien à ajouter, mesuré en Play)")
mouseDown(c.X, c.Y)
step(0.1)
check(math.abs(fxScale(glass).Scale - ST.TilePress) < 0.01, `N2c appui : la tuile s'enfonce (× {ST.TilePress})`)
mouseUp(c.X, c.Y)
step(0.3)
check(SKILL.GetState().Selected == "Tile_Glass" and panelEl("NodeName").Text == "GLASS", "N2d relâché sans bouger : Glass choisie")
check(math.abs(fxScale(glass).Scale - 1) < 0.01, "N2e la tuile revient à 1")
local glow = TREE.SelectionGlow
check(glow.Position == glass.Position, "N2f SelectionGlow posé sous la tuile choisie (T.55)")
tapAt(centerOf(tile("Tile_Next1")))
check(SKILL.GetState().Selected == "Tile_Glass", "N2g clic sur une tuile Locked : rien")
tapAt(centerOf(tile("RootTile")))
check(SKILL.GetState().Selected == "Tile_Glass", "N2h clic sur RootTile : rien")
tapAt(Vector2.new(380, 60))
check(SKILL.GetState().Selected == "Tile_Glass", "N2i clic dans le vide : rien")
-- Coin bas gauche du cadre de Tile_Next4 (bord de l'arbre, aucune voisine là), hors de l'hexagone : aucune tuile.
local regen = tile("Tile_GlassRegen")
local edge = tile("Tile_Next4")
local corner = edge.AbsolutePosition + Vector2.new(4, edge.AbsoluteSize.Y - 4)
check(nav.tileAt(corner) == nil and nav.tileAt(centerOf(edge)) == edge and nav.tileAt(centerOf(regen)) == regen, "N2j coin du cadre hors de l'hexagone : aucune tuile ; centre : la tuile")

section("N3. Survol (T.30)")
mouseMove(centerOf(regen).X, centerOf(regen).Y)
step(0.15)
check(math.abs(fxScale(regen).Scale - ST.TileHover) < 0.01, `N3a tuile survolée × {ST.TileHover}`)
mouseMove(380, 60)
step(0.15)
check(math.abs(fxScale(regen).Scale - 1) < 0.01, "N3b souris partie : retour à 1")

section("N4. Glisser (T.67, T.68)")
mouseDown(900, 600)
mouseMove(903, 600)
step(1 / 30)
zoom, pan = view()
check(pan.X == 0 and pan.Y == 0, "N4a 3 px : pas encore un glisser")
mouseMove(950, 620)
step(1 / 30)
zoom, pan = view()
check(pan.X == 50 and pan.Y == 20 and TREE.Position == base + UDim2.fromOffset(50, 20), "N4b l'arbre suit le pointeur 1 pour 1 (+50, +20)")
mouseUp(950, 620)
step(0.5)
zoom, pan = view()
check(pan.X == 50 and TREE.Position == base + UDim2.fromOffset(50, 20), "N4c relâché dans la limite : il reste")
-- Un glisser qui part d'une tuile ne la choisit pas.
local cam = centerOf(tile("Tile_Cameras"))
mouseDown(cam.X, cam.Y)
mouseMove(cam.X + 40, cam.Y)
mouseUp(cam.X + 40, cam.Y)
step(0.3)
check(SKILL.GetState().Selected == "Tile_Glass", "N4d glisser depuis une tuile : pas de clic")
nav.panBy(Vector2.new(-90, -20))
zoom, pan = view()
check(pan.X == 0 and pan.Y == 0, "N4e panBy : retour à 0")
local limit = TREE_W * ST.PanLimit
mouseDown(700, 360)
mouseMove(1700, 360)
step(1 / 30)
zoom, pan = view()
local rubber = limit + (1000 - limit) * ST.Rubber
check(math.abs(pan.X - rubber) < 1e-6, `N4f 1000 px : au-delà de la limite ({limit} px), il suit à {ST.Rubber} ({string.format("%.0f", pan.X)} px)`)
mouseUp(1700, 360)
zoom, pan = view()
check(pan.X == limit, "N4g relâché : retour à la limite")
step(ST.SnapTime + 0.1)
check(math.abs(TREE.Position.X.Offset - (base.X.Offset + limit)) < 1e-6, `N4h Tree revient à +{limit} px en {ST.SnapTime} s (Back Out)`)
nav.panBy(Vector2.new(-limit, 0))

section("N5. Molette (T.69, T.71)")
local regenCenter = centerOf(regen)
wheel(regenCenter.X, regenCenter.Y, 1)
zoom, pan = view()
check(math.abs(zoom - (1 + ST.ZoomStep)) < 1e-6, `N5a un cran : zoom × {1 + ST.ZoomStep}`)
step(ST.ZoomTime + 0.1)
local after = centerOf(regen)
check((after - regenCenter).Magnitude < 0.5, `N5b le point sous le pointeur y reste (écart {string.format("%.2f", (after - regenCenter).Magnitude)} px)`)
check(math.abs(regen.AbsoluteSize.X - TILE_PX * zoom) < 0.5, "N5c la tuile grandit avec le zoom")
for _ = 1, 20 do
	wheel(640, 360, 1)
end
zoom = view()
check(zoom == ST.ZoomMax, `N5d borné à {ST.ZoomMax}`)
for _ = 1, 30 do
	wheel(640, 360, -1)
end
zoom = view()
check(zoom == ST.ZoomMin, `N5e borné à {ST.ZoomMin}`)
step(0.3)

section("N6. Pincement (T.70)")
SKILL.Close()
step(0.5)
SKILL.Open()
step(1.6)
zoom, pan = view()
check(zoom == 1 and pan.X == 0, "N6a réouverture : zoom 1, décalage 0")
local a, b = touch(600, 360), touch(700, 360)
touchDown(a)
touchDown(b)
touchMove(b, 750, 360)
zoom = view()
check(math.abs(zoom - 1.5) < 1e-6, "N6b doigts de 100 à 150 px : zoom × 1,5")
touchMove(b, 1100, 360)
zoom = view()
check(zoom == ST.ZoomMax, "N6c écart de 500 px : borné à 1,8")
touchUp(b)
touchMove(a, 640, 360)
local _, panAfter = view()
check(panAfter.X ~= 0 or panAfter.Y ~= 0, "N6d le doigt qui reste glisse l'arbre")
touchUp(a)
step(0.5)
check(SKILL.GetState().Selected == "Tile_Glass", "N6e pas de clic après un pincement")

section("N7. Zoom à l'ouverture sur petit écran (T.72)")
SKILL.Close()
step(0.5)
SCREEN_SIZE = Vector2.new(667, 375)
SKILL.Open()
local tilePx = TILE_PX * 667 / 1280
zoom, pan = view()
check(math.abs(zoom - ST.StartTilePx / tilePx) < 1e-3 and pan.X == 0 and pan.Y == 0, `N7a tuiles de {string.format("%.1f", tilePx)} px : zoom {string.format("%.2f", zoom)} pour {ST.StartTilePx} px`)
step(1.6)
check(math.abs(tile("Tile_Glass").AbsoluteSize.X - ST.StartTilePx) < 0.5, "N7b une tuile fait 100 px à l'écran")

summary()
