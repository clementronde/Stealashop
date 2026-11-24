--!nocheck
-- Scénario « screen » : l'écran UI_TheftAlert de Clément (faux écran gris au contrat 2.2 : Banner,
-- ThiefName, ItemName, Arrow dans des cadres décoratifs). Il arrive allumé de StarterGui : éteint
-- au repos ; pendant un vol, seuls Enabled, les deux textes, les visibilités et Arrow.Rotation
-- changent. Flèche : boussole vue de la caméra, à partir de la Rotation posée par Clément ; cachée
-- sans personnage. Nouvelle copie (ResetOnSpawn) reprise ; écran arrivé pendant un vol V0 : le V0
-- part. Sirène sans boucle qui finit d'elle-même.

startServer()

local adaData = victimProfile()
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
giveBat(ada)
-- Le modèle de Clément dans StarterGui (jamais touché par le code) et sa copie dans le PlayerGui.
local template = fakeScreen(StarterGui, true, 30)
local screen = fakeScreen(ada.PlayerGui, true, 30)
local sounds = folder(ASSETS, "Sounds")
make("Sound", { Name = "TheftAlert_Siren", Looped = false, SoundId = "rbxassetid://2" }, sounds)
startClient(ada)
advance(0.5)
local adaShop = shopOf(ada)

local function el(gui, name)
	return gui:FindFirstChild(name, true)
end

section("au repos")
check(screen.Enabled == false, "l'écran de Clément arrive allumé (StarterGui) : éteint au repos")
check(not state().Active, "aucune alerte")

section("vol : l'écran de Clément")
check(breakDoor(bob, adaShop), "porte d'Ada cassée par Bob")
clearLog()
-- Caméra du joueur en (−60, 10, 0), regard vers −Z (à l'horizontale).
lookFrom(Vector3.new(-60, 10, 0), Vector3.new(-60, 10, -10))
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
frame()
local s = state()
check(s.Active and not s.Fallback, "alerte sur l'écran de Clément")
check(screen.Enabled == true, "UI_TheftAlert allumé")
check(el(screen, "ThiefName").Text == "BOB" and s.ThiefName == "BOB", `ThiefName = « BOB » (trouvé {el(screen, "ThiefName").Text})`)
check(el(screen, "ItemName").Text == "SODA CAN" and s.ItemName == "SODA CAN", `ItemName = « SODA CAN » (trouvé {el(screen, "ItemName").Text})`)
check(el(screen, "Static").Text == "IS STEALING YOUR", "le texte décoratif de Clément n'est pas touché")
check(ada.PlayerGui:FindFirstChild("TheftAlertV0") == nil, "pas d'écran V0")
check(not s.Beam and CAMERA:FindFirstChild("TheftAlertArrow") == nil, "pas de Beam V0 : l'Arrow de Clément sert de flèche")
check(logHas("écran UI_TheftAlert de Clément", "PRINT", "client"), "sortie : écran de Clément branché")
check(s.Siren and soundCount("Play", "TheftAlertSiren") == 1, "sirène jouée")
check(alertHighlightOf(bob) ~= nil, "Bob surligné")

section("flèche : boussole vue de la caméra")
local arrow = el(screen, "Arrow")
local function arrowFor(position)
	moveTo(bob, position)
	frame()
	return state().ArrowRotation, arrow.Rotation
end
local angle, rotation = arrowFor(Vector3.new(-60, 3, -20))
check(near(angle, 0, 0.01) and near(rotation, 30, 0.01), `voleur devant : 0° (Rotation 30 + 0 ; trouvé {angle}, {rotation})`)
angle, rotation = arrowFor(Vector3.new(-40, 3, 0))
check(near(angle, 90, 0.01) and near(rotation, 120, 0.01), `voleur à droite : 90° (Rotation 120 ; trouvé {angle}, {rotation})`)
angle, rotation = arrowFor(Vector3.new(-80, 3, 0))
check(near(angle, -90, 0.01) and near(rotation, -60, 0.01), `voleur à gauche : −90° (Rotation −60 ; trouvé {angle}, {rotation})`)
angle, rotation = arrowFor(Vector3.new(-60, 3, 20))
check(near(math.abs(angle), 180, 0.01), `voleur derrière : 180° (trouvé {angle})`)
angle = arrowFor(Vector3.new(-45, 3, -15))
check(near(angle, 45, 0.01), `voleur devant à droite : 45° (trouvé {angle})`)
-- Caméra qui regarde vers +X : le voleur au nord (−Z) est à sa gauche.
lookFrom(Vector3.new(-60, 10, 0), Vector3.new(-50, 10, 0))
angle = arrowFor(Vector3.new(-60, 3, -20))
check(near(angle, -90, 0.01), `caméra tournée vers +X, voleur vers −Z : à gauche, −90° (trouvé {angle})`)
-- Caméra à la verticale (vue de dessus, haut de l'écran vers −Z).
CAMERA.CFrame = CFrame.lookAt(Vector3.new(-60, 60, 0), Vector3.new(-60, 0, -0.001))
angle = arrowFor(Vector3.new(-60, 3, -20))
check(near(angle, 0, 0.5), `caméra à la verticale : le haut de l'écran sert de « devant » (trouvé {angle})`)
check(arrow.Visible == true and state().Arrow, "flèche visible")
lookFrom(Vector3.new(-60, 10, 0), Vector3.new(-60, 10, -10))
-- Personnage du voleur absent (streaming) : flèche cachée, puis de retour.
local character = bob.Character
bob.Character = nil
frame()
check(arrow.Visible == false and not state().Arrow and state().Active, "personnage du voleur absent : flèche cachée, alerte gardée")
bob.Character = character
frame()
check(arrow.Visible == true and state().Arrow, "personnage revenu : flèche de nouveau visible")

section("sirène sans boucle")
local copy = SoundService:FindFirstChild("TheftAlertSiren")
check(copy ~= nil and copy.Looped == false, "copie de la sirène dans SoundService (Looped de Clément gardé)")
endSound(copy)
flush()
check(not state().Siren and copy.Parent == nil, "la sirène finit d'elle-même : copie détruite")
check(state().Active, "l'alerte continue")

section("nouvelle copie de l'écran (ResetOnSpawn)")
screen:Destroy()
local second = fakeScreen(ada.PlayerGui, true, -90) -- Clément a tourné son image dans cette version
advance(0.25)
check(second.Enabled == true, "la nouvelle copie est reprise et allumée")
check(el(second, "ThiefName").Text == "BOB" and el(second, "ItemName").Text == "SODA CAN", "et remplie")
moveTo(bob, Vector3.new(-40, 3, 0))
frame()
check(near(el(second, "Arrow").Rotation, 0, 0.01), `sa flèche part de sa propre Rotation (−90 + 90 = 0 ; trouvé {el(second, "Arrow").Rotation})`)

section("fin du vol")
kill(bob)
flush()
frame()
check(second.Enabled == false and not state().Active, "Bob meurt : écran éteint")
check(soundCount("Stop", "TheftAlertSiren") == 0, "rien à arrêter : la sirène avait fini")
check(template.Enabled == true and el(template, "ThiefName").Text == "PLAYER" and el(template, "Arrow").Rotation == 30, "le modèle de StarterGui n'est jamais touché")
spawnCharacter(bob, SHOPS[2].S.center)
advance(0.3)
check(second.Enabled == false, "toujours éteint au repos (revu tous les REFRESH_INTERVAL)")

section("écran livré pendant une alerte V0")
second:Destroy()
advance(0.25)
check(steal(cy, adaShop, 2), "Cy prend le Paquet de chips (porte encore cassée)")
frame()
local s2 = state()
check(s2.Active and s2.Fallback and s2.Beam, "plus d'écran de Clément : repli V0 (bandeau et Beam)")
check(s2.Headline == "CY IS STEALING YOUR BAG OF CHIPS!", "bandeau V0 sur Cy")
local third = fakeScreen(ada.PlayerGui, false, 0)
advance(0.25)
s2 = state()
check(not s2.Fallback and third.Enabled == true and el(third, "ThiefName").Text == "CY", "l'écran arrive : il remplace le V0 dans les REFRESH_INTERVAL s")
check(ada.PlayerGui:FindFirstChild("TheftAlertV0") == nil, "le V0 est détruit")
check(not s2.Beam and s2.Arrow, "le Beam V0 s'éteint, l'Arrow prend le relais")
runHome(cy, adaShop)
check(not state().Active and third.Enabled == false, "dépôt de Cy : alerte finie")
check(not logHas("[TheftAlertController]", "WARN"), "aucune erreur du contrôleur")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")

if VERBOSE then
	dumpLog()
end
summary("scénario screen")
