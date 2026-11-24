-- Copie a134 (rééquilibrage v2) : la potion Speed est retirée ; la potion d'essai de ce banc est Invisibility.
-- Banc a89 (vague 28) : PotionController, les potions côté client. Le serveur est simulé par le faux Net.
local Ctl = loadController(SOURCE)
local Potions = require(ReplicatedStorage.Shared.Config.Potions)
local me = Players.LocalPlayer
local gui = me.PlayerGui
local DT = 1 / 60

-- Modèles de Clément (relevé du 2026-11-11) : Root, Glass, Liquid (Glow, Bubbles), Cork, Emblem ; Idle = SpinBob.
-- POT_Invisibility a son pivot au milieu (0,75 stud au-dessus du bas) pour vérifier la pose au sol ; POT_Strength sans
-- Idle ; POT_Money absent.
local function makePotion(name, pivotY, idle)
	local m = newInst("Model", name, POTION_FOLDER)
	if idle then m:SetAttribute("Idle", idle) end
	setp(m, "Pivot", CFrame.new(0, pivotY, 0))
	setp(m, "BoxCF", CFrame.new(0, 0.75, 0))
	setp(m, "BoxSize", Vector3.new(0.6, 1.5, 0.7))
	local root = newInst("Part", "Root", m)
	setp(root, "Anchored", true)
	newInst("MeshPart", "Glass", m)
	local liquid = newInst("MeshPart", "Liquid", m)
	newInst("PointLight", "Glow", liquid)
	newInst("ParticleEmitter", "Bubbles", liquid)
	setp(newInst("ParticleEmitter", "Off", liquid), "Enabled", false)
	newInst("Part", "Cork", m)
	newInst("Part", "Emblem", m)
	return m
end
local speedTemplate = makePotion("POT_Invisibility", 0.75, "SpinBob")
makePotion("POT_Strength", 0, nil)

Ctl.Start()

local function folder() return workspace:FindFirstChild("LocalPotions") end
local function setRoot(pos) setp(me.Character.HumanoidRootPart, "CFrame", CFrame.new(pos)) end
local function state() return Ctl.GetState() end
setRoot(Vector3.new(-500, 3, 0))
tick(DT)

-- 1. Apparition, pose au sol, SpinBob, retrait ------------------------------------------------------
NET.Client.PotionSpawned:Fire("u1", "Invisibility", Vector3.new(100, 0, 20))
local f = folder()
check("A1 dossier Workspace/LocalPotions", f ~= nil)
local m = f and f:FindFirstChild("POT_Invisibility")
check("A2 copie locale de POT_Invisibility", m ~= nil and m ~= speedTemplate)
local partsOk = m ~= nil
for _, d in (m and m:GetDescendants() or {}) do
	if d:IsA("BasePart") and not (d.Anchored == true and d.CanCollide == false and d.CanTouch == false and d.CanQuery == false) then
		partsOk = false
	end
end
check("A3 pièces ancrées, sans collision, contact ni requête", partsOk)
local expected = CFrame.new(100, 0.85, 20) * CFrame.Angles(0, 0.5, 0)
check("A4 bas de la boîte au sol, SpinBob par ItemIdleController.ModelMotion", m and nearCF(m:GetPivot(), expected), m and tostring(m:GetPivot()))
check("A5 état : 1 potion", state().Shown == 1)
check("A6 modèle de Clément intact", speedTemplate.Parent == POTION_FOLDER and nearCF(speedTemplate:GetPivot(), CFrame.new(0, 0.75, 0)))
check("A7 lumière et bulles allumées (VISUAL EFFECTS ON)", m and m.Liquid.Glow.Enabled == true and m.Liquid.Bubbles.Enabled == true and m.Liquid.Off.Enabled == false)
tick(DT, 3)
check("A8 replacée à chaque image, toujours au même endroit", m and nearCF(m:GetPivot(), expected))

NET.Client.PotionSpawned:Fire("u3", "Strength", Vector3.new(120, 0, 20))
local s = f:FindFirstChild("POT_Strength")
tick(DT)
check("A9 sans Idle : immobile, posée au sol", s and nearCF(s:GetPivot(), CFrame.new(120, 0, 20)))
NET.Client.PotionRemoved:Fire("u3")
check("A10 retirée (expirée) : détruite tout de suite, sans son", s and s.Parent == nil and #SOUNDS == 0 and state().Shown == 1)
NET.Client.PotionRemoved:Fire("inconnue")
check("A11 retrait d'un uid inconnu : rien", state().Shown == 1)

-- 2. Modèle absent, potion inconnue -------------------------------------------------------------------
local function countPrints(word)
	local n = 0
	for _, line in PRINTS do if string.find(line, word, 1, true) then n += 1 end end
	return n
end
NET.Client.PotionSpawned:Fire("u2", "Money", Vector3.new(0, 0, 0))
NET.Client.PotionSpawned:Fire("u2b", "Money", Vector3.new(0, 0, 4))
check("M1 modèle absent : une seule ligne en Studio", countPrints("POT_Money") == 1, #PRINTS)
check("M2 rien de montré", f:FindFirstChild("POT_Money") == nil and state().Shown == 1)
NET.Client.PotionSpawned:Fire("u9", "Nope", Vector3.new(0, 0, 0))
check("M3 potion inconnue : rien", state().Shown == 1)
setRoot(Vector3.new(0, 3, 0))
tick(DT, 5)
check("M4 pas de PickPotion pour une potion pas montrée", #PICKS == 0)

-- 3. Contact : une seule fois, renvoi après un délai, hauteur -----------------------------------------
setRoot(Vector3.new(110, 3, 20))
tick(DT, 5)
check("C1 à 10 studs : rien", #PICKS == 0)
setRoot(Vector3.new(102.5, 3, 20))
tick(DT)
check("C2 à portée : PickPotion(u1)", #PICKS == 1 and PICKS[1] == "u1")
tick(DT, 30)
check("C3 pas à chaque image (0,5 s plus tard : toujours 1)", #PICKS == 1, #PICKS)
tick(DT, 36)
check("C4 serveur muet : renvoyé après le délai", #PICKS == 2, #PICKS)
NET.Client.PotionSpawned:Fire("u4", "Strength", Vector3.new(200, 0, 0))
setRoot(Vector3.new(200, 10, 0))
tick(DT, 5)
check("C5 10 studs au-dessus : rien", #PICKS == 2)
setRoot(Vector3.new(102.5, 3, 20))
NET.Client.PotionRemoved:Fire("u1")
check("C6 ramassée : son UI_Success (Potion_Pick depuis a246)", (SOUNDS[1] == "UI_Success" or SOUNDS[1] == "Potion_Pick") and #SOUNDS == 1)
check("C7 petit effet : la copie reste le temps du pop", m.Parent == f and state().Popping == 1 and state().Shown == 1)
tick(0.05, 2)
check("C8 elle grossit en montant", (m:GetScale() > 1) and m:GetPivot().Position.Y > 0.85, m:GetScale())
tick(0.05, 4)
check("C9 puis disparaît", m.Parent == nil and state().Popping == 0)
local before = #PICKS
tick(DT, 120)
check("C10 plus de PickPotion après le retrait", #PICKS == before)
NET.Client.PotionRemoved:Fire("u4")

-- 4. Effets actifs à l'écran ------------------------------------------------------------------------
me:SetAttribute("Potion_Invisibility", SERVER_NOW + 102.2)
tick(0.2)
local status = gui:FindFirstChild("PotionStatus")
local function line(id) return status and status:FindFirstChild("Potion_" .. id, true) end
check("E1 V0 : ScreenGui PotionStatus", status ~= nil)
check("E2 ligne « Invisibility 1:42 »", line("Invisibility") and line("Invisibility").Text == "Invisibility 1:42", line("Invisibility") and line("Invisibility").Text)
check("E3 sans UI_HUD.Cash : à gauche au milieu, pas en haut", status and status.List.Position.Y.Scale == 0.5)
me:SetAttribute("Potion_Strength", SERVER_NOW + 30.1)
local hud = newInst("ScreenGui", "UI_HUD", gui)
local cash = newInst("TextLabel", "Cash", newInst("Frame", "Top", hud))
setp(cash, "AbsolutePosition", Vector2.new(20, 700))
setp(cash, "AbsoluteSize", Vector2.new(120, 30))
tick(0.2)
check("E4 deux effets, deux lignes", line("Strength") and line("Strength").Text == "Strength 0:30" and state().Effects == 2, line("Strength") and line("Strength").Text)
check("E5 argent en bas de l'écran : lignes juste au-dessus", status.List.AnchorPoint.Y == 1 and status.List.Position.Y.Offset == 696 and status.List.Position.X.Offset == 20)
setp(cash, "AbsolutePosition", Vector2.new(20, 100))
tick(0.2)
check("E6 argent en haut : lignes juste dessous", status.List.AnchorPoint.Y == 0 and status.List.Position.Y.Offset == 134)
SERVER_NOW += 30
tick(0.2)
check("E7 effet fini : sa ligne part, l'autre reste", line("Strength") == nil and line("Invisibility") ~= nil and state().Effects == 1)
me:SetAttribute("Potion_Invisibility", nil)
tick(0.2)
check("E8 plus d'effet : plus d'affichage", gui:FindFirstChild("PotionStatus") == nil and state().Effects == 0)
me:SetAttribute("Potion_Strength", nil)

-- Écran de Clément proposé : UI_HUD.PotionBar, Template (Icon, Timer), attribut <Id>Icon.
local bar = newInst("Frame", "PotionBar", hud)
bar:SetAttribute("InvisibilityIcon", "rbxassetid://123")
local tpl = newInst("Frame", "Template", bar)
setp(tpl, "Visible", false)
newInst("ImageLabel", "Icon", tpl)
newInst("TextLabel", "Timer", tpl)
me:SetAttribute("Potion_Invisibility", SERVER_NOW + 65)
me:SetAttribute("Potion_Money", SERVER_NOW + 30.1)
tick(0.2)
local rowSpeed = bar:FindFirstChild("Potion_Invisibility")
local rowMoney = bar:FindFirstChild("Potion_Money")
check("B1 PotionBar : une copie du Template par effet, visible", rowSpeed and rowMoney and rowSpeed.Visible == true and tpl.Visible == false)
check("B2 Icon de l'attribut InvisibilityIcon, Timer « 1:05 »", rowSpeed and rowSpeed.Icon.Image == "rbxassetid://123" and rowSpeed.Timer.Text == "1:05", rowSpeed and rowSpeed.Timer.Text)
check("B3 sans icône : le nom dans Timer", rowMoney and rowMoney.Timer.Text == "Money 0:30", rowMoney and rowMoney.Timer.Text)
check("B4 pas d'affichage V0 avec l'écran de Clément", gui:FindFirstChild("PotionStatus") == nil)
SERVER_NOW += 70
tick(0.2)
check("B5 fins : copies retirées, Template gardé", bar:FindFirstChild("Potion_Invisibility") == nil and bar:FindFirstChild("Potion_Money") == nil and bar:FindFirstChild("Template") == tpl)
me:SetAttribute("Potion_Invisibility", nil)
me:SetAttribute("Potion_Money", nil)
bar.Parent = nil

-- 5. Invisibilité --------------------------------------------------------------------------------
local p2 = newPlayer(2)
local function dress(character)
	local head = newInst("Part", "Head", character)
	newInst("Decal", "face", head)
	local acc = newInst("Accessory", "Hat", character)
	newInst("Part", "Handle", acc)
	newInst("Humanoid", "Humanoid", character)
	newInst("BillboardGui", "NameTag", head)
	newInst("ParticleEmitter", "Aura", character.HumanoidRootPart)
	newInst("Highlight", "TheftAlertHighlight", character)
	setp(newInst("Trail", "Trail", character.HumanoidRootPart), "Enabled", false)
	return head
end
local c2 = p2.Character
local head = dress(c2)
tick(0.2)
check("I0 sans potion : rien", head.LocalTransparencyModifier == 0 and state().Cloaked == 0)
p2:SetAttribute("Potion_Invisibility", SERVER_NOW + 60)
tick(0.2)
check("I1 autre joueur : pièces presque transparentes (0,85)", head.LocalTransparencyModifier == 0.85 and c2.Hat.Handle.LocalTransparencyModifier == 0.85)
check("I2 visage (décalque) aussi", head.face.LocalTransparencyModifier == 0.85)
check("I3 nom caché", c2.Humanoid.DisplayDistanceType == "HumanoidDisplayDistanceType.None" and head.NameTag.Enabled == false)
check("I4 aura éteinte, contour gardé, traînée éteinte laissée", c2.HumanoidRootPart.Aura.Enabled == false and c2.TheftAlertHighlight.Enabled == true and c2.HumanoidRootPart.Trail.Enabled == false)
check("I5 état : 1 joueur invisible, pas de voile chez moi", state().Cloaked == 1 and state().Veil == false)
check("I6 mon personnage intact", me.Character.HumanoidRootPart.LocalTransparencyModifier == 0)
local hat2 = newInst("Part", "NewHat", c2)
check("I7 accessoire ajouté pendant l'effet : caché aussi", hat2.LocalTransparencyModifier == 0.85)
SERVER_NOW += 61
tick(0.2)
check("I8 fin : pièces revenues", head.LocalTransparencyModifier == 0 and c2.Hat.Handle.LocalTransparencyModifier == 0 and hat2.LocalTransparencyModifier == 0 and head.face.LocalTransparencyModifier == 0)
check("I9 fin : nom, aura revenus, traînée toujours éteinte", c2.Humanoid.DisplayDistanceType == "HumanoidDisplayDistanceType.Viewer" and head.NameTag.Enabled == true and c2.HumanoidRootPart.Aura.Enabled == true and c2.HumanoidRootPart.Trail.Enabled == false)
check("I10 état : 0", state().Cloaked == 0)
p2:SetAttribute("Potion_Invisibility", SERVER_NOW + 60)
tick(0.2)
local c2b = newCharacter(p2, Vector3.new(0, 3, 0))
local head2 = dress(c2b)
tick(0.2)
check("I11 réapparition : nouveau personnage caché, ancien rendu", head2.LocalTransparencyModifier == 0.85 and head.LocalTransparencyModifier == 0 and state().Cloaked == 1)
removePlayer(p2)
tick(0.2)
check("I12 départ du joueur : oublié", state().Cloaked == 0)

me:SetAttribute("Potion_Invisibility", SERVER_NOW + 30)
tick(0.2)
local veil = gui:FindFirstChild("PotionVeil")
check("I13 chez moi : voile léger", veil ~= nil and veil.Enabled == true and veil.Veil.BackgroundTransparency == 0.85 and veil.DisplayOrder < 0)
check("I14 chez moi : personnage pas touché, pas compté", me.Character.HumanoidRootPart.LocalTransparencyModifier == 0 and state().Cloaked == 0 and state().Veil == true)
SERVER_NOW += 31
tick(0.2)
check("I15 fin : voile retiré", veil.Enabled == false and state().Veil == false)
me:SetAttribute("Potion_Invisibility", nil)

-- 6. VISUAL EFFECTS sur OFF -------------------------------------------------------------------------
me:SetAttribute("VfxEnabled", false)
NET.Client.PotionSpawned:Fire("u5", "Invisibility", Vector3.new(50, 0, 0))
local v = folder():FindFirstChild("POT_Invisibility")
tick(DT)
check("V1 OFF : bulles et lumière éteintes", v and v.Liquid.Glow.Enabled == false and v.Liquid.Bubbles.Enabled == false)
check("V2 OFF : le reste inchangé (montrée, SpinBob, sans collision)", v and nearCF(v:GetPivot(), CFrame.new(50, 0.85, 0) * CFrame.Angles(0, 0.5, 0)) and v.Root.CanCollide == false and state().Shown == 1)
me:SetAttribute("VfxEnabled", true)
check("V3 retour ON : rallumées à leur état d'origine", v.Liquid.Glow.Enabled == true and v.Liquid.Bubbles.Enabled == true and v.Liquid.Off.Enabled == false)
me:SetAttribute("VfxEnabled", false)
check("V4 OFF pendant qu'elle est là : éteintes", v.Liquid.Glow.Enabled == false and v.Liquid.Bubbles.Enabled == false)
check("V5 modèle de Clément jamais touché", speedTemplate.Liquid.Glow.Enabled == true and speedTemplate.Liquid.Bubbles.Enabled == true)
setRoot(Vector3.new(51, 3, 0))
tick(DT)
check("V6 OFF : contact toujours envoyé", PICKS[#PICKS] == "u5")

print(string.format("banc a89 (potions client) : %d vérification(s), %d échec(s)", CHECKS, FAILS))
