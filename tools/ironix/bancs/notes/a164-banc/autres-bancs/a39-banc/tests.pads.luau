--!nocheck
-- Scénario « pads » : les plaques ShopPad des comptoirs du hub (ShopPadController) avec les vrais
-- WeaponShopController, AuraShopController et RobuxShopController (vitrine). Une ouverture par montée
-- (il faut descendre puis remonter), fermeture des boutiques d'armes et d'auras à distance de la
-- plaque, boutique Robux ouverte partout, hauteur, plaque tournée (cylindre couché), plaque posée plus
-- tard, retirée puis revenue (streaming), comptoir rangé dans l'inbox, ShopPad qui n'est pas une pièce,
-- invites « Shop » gardées.

local HUD = buildHud(PLAYER_GUI)
local ROBUX = buildRobuxShopGui(PLAYER_GUI)
local WEAPON = buildWeaponShop(PLAYER_GUI)
local AURA = buildAuraShop(PLAYER_GUI)
local weaponStall, weaponCounter, weaponPad = makeStall("ENV_Hub_WeaponStall", "WeaponShop", WEAPON_PIVOT, true)
local auraStall, auraCounter = makeStall("ENV_Hub_AuraStall", "AuraShop", AURA_PIVOT, false) -- plaque posée plus tard
local robuxStall, _, robuxPad = makeStall("ENV_Hub_RobuxStall", "RobuxShop", ROBUX_PIVOT, true)
P1:SetAttribute("Cash", 6400)
startClient()

local function step(position, dt)
	moveTo(position)
	advance(dt or 0.1)
end

section("branchement")
-- a95 (vague 29) : ShopPadController cherche aussi PawnShopController, absent de cet arbre : seul cet avertissement est permis.
local otherShopPadWarn = false
for _, line in LOG do
	if line.side == "client" and line.kind == "WARN" and string.find(line.text, "[ShopPad]", 1, true) and not string.find(line.text, "PawnShopController", 1, true) then
		otherShopPadWarn = true
	end
end
check(not otherShopPadWarn, "les trois contrôleurs de boutique ont leur API Open : aucun avertissement")
check(WEAPON.Enabled == false and AURA.Enabled == false and ROBUX.Enabled == false, "écrans fermés au départ")
check(weaponCounter:FindFirstChild("WeaponShopPrompt") ~= nil and auraCounter:FindFirstChild("AuraShopPrompt") ~= nil, "invites « Shop » des comptoirs gardées")

section("boutique d'armes : une ouverture par montée")
local spot = onPadSpot(WEAPON_PIVOT)
step(spot)
check(WEAPON.Enabled == true, "monter sur la plaque ouvre UI_WeaponShop")
click(WEAPON.Window.CloseButton)
check(WEAPON.Enabled == false, "CloseButton le ferme")
step(spot, 1)
step(spot + Vector3.new(0.5, 0, 0.5), 0.5)
check(WEAPON.Enabled == false, "rester (ou bouger) sur la plaque ne le rouvre pas")
step(spot + Vector3.new(6, 0, 0))
check(WEAPON.Enabled == false, "descendre de la plaque : toujours fermé")
step(spot)
check(WEAPON.Enabled == true, "y remonter le rouvre")

section("boutique d'armes : fermeture à distance de la plaque")
step(spot + Vector3.new(0, 0, 13))
check(WEAPON.Enabled == true, "à 13 studs de la plaque : ouvert (fermeture au-delà de 14)")
step(spot + Vector3.new(0, 0, 15))
check(WEAPON.Enabled == false, "à 15 studs : fermé")

section("hauteur")
step(spot + Vector3.new(0, 8, 0))
check(WEAPON.Enabled == false, "8 studs au-dessus de la plaque (en plein saut) : pas sur la plaque")
step(spot + Vector3.new(0, 1, 0))
check(WEAPON.Enabled == true, "redescendu (4 studs au-dessus de la plaque) : ouvert")
step(spot + Vector3.new(4.4, 0, 0))
check(WEAPON.Enabled == true, "au bord de la plaque (4,4 studs du centre, marge de 0,5) : toujours dessus")
click(WEAPON.Window.CloseButton)
step(spot + Vector3.new(4.6, 0, 0))
step(spot + Vector3.new(4.4, 0, 0))
check(WEAPON.Enabled == true, "sorti à 4,6 studs puis revenu à 4,4 : rouvert")
click(WEAPON.Window.CloseButton)

section("boutique d'auras : plaque posée plus tard")
local auraSpot = onPadSpot(AURA_PIVOT)
step(auraSpot)
check(AURA.Enabled == false, "comptoir sans plaque : rien")
local auraPad = makePad(auraStall, Vector3.new(AURA_PIVOT.X, 0.1, AURA_PIVOT.Z + 6))
step(auraSpot)
check(AURA.Enabled == true, "plaque posée : le joueur dessus ouvre UI_AuraShop")
step(auraSpot + Vector3.new(0, 0, 15))
check(AURA.Enabled == true, "à 15 studs de la plaque : ouvert (fermeture au-delà de 16)")
step(auraSpot + Vector3.new(0, 0, 17))
check(AURA.Enabled == false, "à 17 studs : fermé")

section("plaque retirée puis revenue (streaming)")
auraPad.Parent = nil
step(auraSpot)
check(AURA.Enabled == false, "plaque retirée : rien")
step(auraSpot + Vector3.new(0, 0, 20))
auraPad.Parent = auraStall
step(auraSpot)
check(AURA.Enabled == true, "plaque revenue : rouvre")
step(FAR_SPOT)

section("boutique Robux (vitrine) : ouverte partout")
local robuxSpot = onPadSpot(ROBUX_PIVOT)
step(robuxSpot)
check(ROBUX.Enabled == true and #cardsOf(ROBUX) == 5, "la plaque ouvre UI_RobuxShop en vitrine (5 gamepasses)")
step(FAR_SPOT, 1)
check(ROBUX.Enabled == true, "s'éloigner ne la ferme pas")
click(hudButton(HUD, "RobuxShopButton"))
check(ROBUX.Enabled == false, "le bouton du HUD la referme")
step(robuxSpot)
check(ROBUX.Enabled == true, "remonter sur la plaque la rouvre")
step(robuxSpot + Vector3.new(0, 0, 1), 0.5)
check(ROBUX.Enabled == true and #cardsOf(ROBUX) == 5, "rester sur la plaque, écran ouvert : rien ne change")
click(ROBUX.Root.Window.CloseButton)
check(#MARKET.prompts == 0, "aucune fenêtre d'achat")

section("plaque tournée : cylindre couché, comptoir pivoté")
step(FAR_SPOT)
-- Cylindre couché (axe X vertical), comme une plaque ronde ; comptoir tourné de 90° sur Y.
weaponPad.Size = Vector3.new(0.2, 6, 6)
weaponPad.CFrame = CFrame.new(spot.X, 0.1, spot.Z) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90))
step(spot)
check(WEAPON.Enabled == true, "plaque ronde (cylindre couché, tourné) : debout dessus, ouvert")
click(WEAPON.Window.CloseButton)
step(spot + Vector3.new(0, 0, 3.8))
step(spot + Vector3.new(0, 0, 2.9))
check(WEAPON.Enabled == true, "sorti puis revenu dans l'emprise : rouvert")
click(WEAPON.Window.CloseButton)
step(spot + Vector3.new(0, 0, 4))
check(WEAPON.Enabled == false, "hors de l'emprise (4 studs du centre, rayon 3 + 0,5) : rien")
weaponPad.Size = Vector3.new(8, 0.2, 6)
weaponPad.CFrame = CFrame.new(spot.X, 0.1, spot.Z)

section("comptoir rangé dans l'inbox : ignoré")
local inbox = folder(Workspace, "_INBOX_CLEMENT")
local inboxPivot = Vector3.new(200, 3.95, 0)
makeStall("ENV_Hub_WeaponStall_v2", "WeaponShop", inboxPivot, true, inbox)
step(onPadSpot(inboxPivot))
check(WEAPON.Enabled == false, "la plaque d'un comptoir de l'inbox n'ouvre rien")

section("ShopPad qui n'est pas une pièce")
local otherPivot = Vector3.new(-200, 3.95, 0)
local other = makeStall("ENV_Test_Stall", "AuraShop", otherPivot, false)
local fake = make("Model", { Name = "ShopPad" }, other)
make("Part", { Name = "Plate", Anchored = true, CFrame = CFrame.new(otherPivot.X, 0.1, otherPivot.Z + 6), Size = Vector3.new(8, 0.2, 6) }, fake)
flush()
step(onPadSpot(otherPivot))
check(AURA.Enabled == false, "ShopPad en Model : ignoré")
check(logHas("ENV_Test_Stall.ShopPad n'est pas une pièce (BasePart) : ignorée", "WARN", "client"), "un avertissement dans la sortie (Studio)")
check(logCount("n'est pas une pièce (BasePart)", "WARN", "client") == 1, "une seule fois")

section("comptoir retiré du tag")
step(FAR_SPOT)
CollectionService:RemoveTag(weaponStall, "WeaponShop")
step(spot)
check(WEAPON.Enabled == false, "comptoir qui n'est plus taggé WeaponShop : sa plaque n'ouvre plus rien")
addTag(weaponStall, "WeaponShop")
step(FAR_SPOT)
step(spot)
check(WEAPON.Enabled == true, "taggé de nouveau : sa plaque rouvre l'écran")

section("sans personnage")
click(WEAPON.Window.CloseButton)
local character = P1.Character
P1.Character = nil
advance(0.2)
check(WEAPON.Enabled == false, "sans personnage : rien")
P1.Character = character
step(spot)
check(WEAPON.Enabled == true, "un personnage qui réapparaît sur la plaque compte comme une montée")

summary("scénario pads")
