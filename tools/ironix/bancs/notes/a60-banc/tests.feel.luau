---------------------------------------------------------------- scénario « feel » : le vrai UiFeelController
local H, S, C = UiMotionC.Hover, UiMotionC.Success, UiMotionC.HoverCard
local PULSE, FOV = UiMotionC.ChasePulse, UiMotionC.ChaseFov

-- Un écran de boutique comme ceux de Clément : Root > Window (BuyButton à calque Shade, CloseButton),
-- liste avec son Template caché (carte à HoverOutline, PlaceButton dedans) ; un bouton à la racine et
-- un calque de glisser plein cadre (laissés de côté).
local shop = new("ScreenGui", { Name = "UI_WeaponShop", Enabled = true }, PLAYER_GUI)
local root = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.8, 0.8) }, shop)
local buy = new("TextButton", { Name = "BuyButton", Size = UDim2.fromScale(0.2, 0.1) }, root)
local buyShade = new("Frame", { Name = "Shade", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, buy)
local close = new("TextButton", { Name = "CloseButton", Size = UDim2.fromScale(0.1, 0.1) }, root)
local list = new("Frame", { Name = "List", Size = UDim2.fromScale(1, 0.6) }, root)
local template = new("TextButton", { Name = "Template", Visible = false, Size = UDim2.fromScale(0.2, 0.4) }, list)
local tIcon = new("ImageLabel", { Name = "Icon", Position = UDim2.fromScale(0.5, 0.4), Rotation = 0 }, template)
new("Frame", { Name = "HoverOutline", Visible = false }, template)
local tPlace = new("TextButton", { Name = "PlaceButton", Size = UDim2.fromScale(0.8, 0.2) }, template)
local rootButton = new("TextButton", { Name = "Backdrop", Size = UDim2.fromScale(0.5, 0.5) }, shop)
local navLayer = new("TextButton", { Name = "NavLayer", Size = UDim2.fromScale(1, 1) }, root)
local other = new("ScreenGui", { Name = "Debug_Overlay" }, PLAYER_GUI)
local otherButton = new("TextButton", { Name = "BuyButton", Size = UDim2.fromScale(0.2, 0.1) }, new("Frame", { Name = "F" }, other))

-- UI_Chase : ScreenEdges (une image) et Vignette.Edge (un cadre avec deux images).
local chaseGui = new("ScreenGui", { Name = "UI_Chase", Enabled = false }, PLAYER_GUI)
local edges = new("ImageLabel", { Name = "ScreenEdges", ImageTransparency = 0.3, Size = UDim2.fromScale(1, 1) }, chaseGui)
local vignette = new("Frame", { Name = "Vignette", Size = UDim2.fromScale(1, 1) }, chaseGui)
local edge = new("Frame", { Name = "Edge", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, vignette)
local left = new("ImageLabel", { Name = "Left", ImageTransparency = 0.25 }, edge)
local right = new("ImageLabel", { Name = "Right", ImageTransparency = 0.25 }, edge)
local camera = Workspace.CurrentCamera
camera.FieldOfView = 70
local shopSnap = snapshot(shop)
local chaseSnap = snapshot(chaseGui)

local Chase = requireModule(CHASE_MODULE, "client")
local Feel = requireModule(FEEL_MODULE, "client")
taskLib.spawn(Feel.Start)
step(0.1)
local soundsFrom = #SOUNDS_PLAYED

print("\n== F1. Boutons des écrans")
buy.MouseEnter:Fire()
step(H.Time + 1 / 30)
check(scaleNamed(buy, H.ScaleName) ~= nil and near(buyShade.BackgroundTransparency, H.ShadeTransparency, 1e-4), "F1a BuyButton : survol branché (échelle et Shade)")
local heard = soundsSince(soundsFrom)
check(#heard == 1 and heard[1] == H.Sound, `F1b son {H.Sound} joué par MarkerSounds (Assets/Sounds) ({table.concat(heard, ", ")})`)
buy.MouseLeave:Fire()
close.MouseEnter:Fire()
step(H.Time + 1 / 30)
check(scaleNamed(close, H.ScaleName) ~= nil, "F1c CloseButton : branché")
close.MouseLeave:Fire()
tPlace.MouseEnter:Fire()
template.MouseEnter:Fire()
rootButton.MouseEnter:Fire()
navLayer.MouseEnter:Fire()
otherButton.MouseEnter:Fire()
step(0.2)
check(anyUIScale(template) == nil, "F1d le Template caché (et son PlaceButton) : pas branché")
check(countClass(rootButton, "UIScale") == 0, "F1e bouton à la racine de l'écran : laissé de côté")
check(countClass(navLayer, "UIScale") == 0, "F1f calque plein cadre : laissé de côté")
check(countClass(otherButton, "UIScale") == 0, "F1g écran qui n'est pas un UI_* : laissé de côté")
for _, b in { tPlace, template, rootButton, navLayer, otherButton } do
	b.MouseLeave:Fire()
end

print("\n== F2. Copies d'une liste : carte et bouton branchés")
local copy = template:Clone()
copy.Parent = list
copy.Name = "Card_Hammer" -- renommée juste après son arrivée, comme le font les contrôleurs
copy.Visible = true
step(1 / 30)
local icon = el(copy, "Icon")
copy.MouseEnter:Fire()
step(C.Time + 1 / 30)
check(el(copy, "HoverOutline").Visible and scaleNamed(icon, H.ScaleName) ~= nil, "F2a la carte copiée : HoverCard branché")
check(countClass(copy, "UIScale") == 0, "F2b la carte elle-même ne prend pas l'effet de bouton")
local place = el(copy, "PlaceButton")
place.MouseEnter:Fire()
step(H.Time + 1 / 30)
check(scaleNamed(place, H.ScaleName) ~= nil, "F2c son PlaceButton : branché")
place.MouseLeave:Fire()
copy.MouseLeave:Fire()
step(0.3)
check(anyUIScale(copy) == nil and el(copy, "HoverOutline").Visible == false and icon.Rotation == 0, "F2d sortie : tout revient")

print("\n== F3. Success sur les boutons d'achat")
soundsFrom = #SOUNDS_PLAYED
buy.Activated:Fire()
local s = scaleNamed(buy, H.ScaleName)
check(s ~= nil and near(s.Scale, S.From, 1e-6), "F3a BuyButton cliqué : × Success.From")
step(S.SoundDelay + 0.05)
check(table.find(soundsSince(soundsFrom), S.Sound) ~= nil, `F3b son {S.Sound}`)
close.Activated:Fire()
check(scaleNamed(close, H.ScaleName) == nil, "F3c CloseButton cliqué : pas de Success")
step(S.Time + 0.1)
check(countClass(buy, "UIScale") == 0, "F3d revenu, UIScale retiré")

print("\n== F4. Poursuite : bords qui battent, champ de vision")
Chase.chased = true
step(1 / 30)
local seenEdges, seenLeft = {}, {}
local minV, maxV = 1, 0
for _ = 1, 30 do
	step(1 / 30)
	table.insert(seenEdges, edges.ImageTransparency)
	table.insert(seenLeft, left.ImageTransparency)
	minV = math.min(minV, edges.ImageTransparency)
	maxV = math.max(maxV, edges.ImageTransparency)
end
check(minV >= PULSE.Min - 1e-6 and maxV <= PULSE.Max + 1e-6 and maxV - minV > 0.3, `F4a ScreenEdges bat entre {PULSE.Min} et {PULSE.Max} ({minV} à {maxV})`)
check(seenLeft[10] == seenEdges[10] and right.ImageTransparency == edges.ImageTransparency, "F4b Vignette.Edge (un cadre) : ses images battent avec")
check(edge.BackgroundTransparency == 1, "F4c le fond du cadre Edge n'est pas touché (il a des images)")
check(near(camera.FieldOfView, 70 + FOV.Add, 1e-4), `F4d champ de vision + {FOV.Add} ({camera.FieldOfView})`)
Chase.chased = false
step(1 / 30)
check(edges.ImageTransparency == 0.3 and left.ImageTransparency == 0.25 and right.ImageTransparency == 0.25, "F4e fin : transparences d'origine")
step(FOV.OutTime + 0.05)
check(near(camera.FieldOfView, 70, 1e-6), `F4f champ de vision revenu à 70 ({camera.FieldOfView})`)
-- Nouvelle poursuite pendant le retour : la base reste 70.
Chase.chased = true
step(0.1)
Chase.chased = false
step(0.1)
Chase.chased = true
step(FOV.InTime + 0.05)
check(near(camera.FieldOfView, 70 + FOV.Add, 1e-4), "F4g poursuites hachées : toujours 70 + Add, jamais plus")
Chase.chased = false
step(FOV.OutTime + 0.1)
check(near(camera.FieldOfView, 70, 1e-6), "F4h puis 70")

print("\n== F5. Rien n'est laissé")
step(1)
copy:Destroy()
local same, why = sameAs(shopSnap, shop)
check(same, `F5a UI_WeaponShop comme au départ ({why})`)
same, why = sameAs(chaseSnap, chaseGui)
check(same, `F5b UI_Chase comme au départ ({why})`)
check(ACTIVE_TWEENS() == 0, "F5c aucun tween en cours")

summary()
