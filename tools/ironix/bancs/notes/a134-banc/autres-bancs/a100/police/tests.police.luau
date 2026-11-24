
---------------------------------------------------------------- a100-police (L-111)
-- Suite de la mise en place du banc a54-guard (lue sur place jusqu'à « G1 lancement ») : le policier appelé par
-- un témoin, piloté par le vrai GuardService.StartDriverChase avec les champs facultatifs Label, Tired et
-- GiveUpReason ; GuardService.FindGuardModel et IsInSafeZone.
--   P1 modèle NPC_Police trouvé dans Assets/Guards ; zone safe
--   P2 poursuite trop longue (Keeps faux) : vitesse fixe, Tired, puis fondu ; nom « policier » dans la sortie
--   P3 capture d'un joueur qui ne porte rien : Catch, coup, message, rien de perdu, fondu sans Tired
--   P4 Keeps faux avant le départ : abandon sans Tired
if string.find(SOURCES["server/Services/GuardService.luau"] or "", "FindGuardModel", 1, true) == nil then
	print("\na100-police SAUTÉ : cet arbre n'a pas encore le policier des témoins (L-111)")
	summary()
	return
end

print("\n--- P1 modèle et zone safe")
local Guards = folder(Assets, "Guards")
local POLICE = makeDriver("NPC_Police", true)
local tiredAnim = new("Animation", "Tired", POLICE:FindFirstChild("Animations"))
tiredAnim.AnimationId = "rbxassetid://779"
POLICE.Parent = Guards
TRACK_LENGTH.Tired = 1.5
check(GuardService.FindGuardModel("NPC_Police") == POLICE, "P1a FindGuardModel trouve NPC_Police dans ReplicatedStorage/Assets/Guards")
check(GuardService.FindGuardModel("NPC_Nope") == nil, "P1b modèle pas livré : nil")
check(GuardService.IsInSafeZone(Vector3.new(-150, 3, 0)) == true and GuardService.IsInSafeZone(Vector3.new(50, 3, 0)) == false, "P1c IsInSafeZone (tag SafeZone)")

local BUSTED = "Busted! The police caught you."
local deadline = 0
local function policeChase(player, spawnX)
	return chaseOf(player, 0, {
		Template = POLICE,
		Name = "NPC_Police_Z1",
		Spawn = CFrame.new(spawnX, GROUND, 0),
		Zone = 1,
		SpeedMultiplier = 0,
		MinSpeed = 13.4,
		Keeps = function(_p)
			return now() < deadline
		end,
		CaughtMessage = BUSTED,
		Label = "policier",
		Tired = true,
		GiveUpReason = "poursuite trop longue",
	})
end

print("\n--- P2 poursuite trop longue")
local zed = addPlayer("Zed", Vector3.new(1060, 3, 0))
deadline = now() + 6
local tp = now()
local pm = GuardService.StartDriverChase(policeChase(zed, 1000))
check(pm ~= nil and pm.Name == "NPC_Police_Z1" and pm.Parent == activeFolder() and pm ~= POLICE, "P2a une copie du policier dans Workspace/ActiveGuards")
check(POLICE.Parent == Guards, "P2b le modèle de Clément n'est pas touché")
local zs = chaseStates(zed)
check(#zs == 1 and zs[1].args[1] == true and zs[1].args[2] == pm, "P2c ChaseState(true, policier) au joueur poursuivi (UI_Chase, MUS_Chase)")
check(GuardService.IsChased(zed) == false, "P2d IsChased (vigile de jour) reste faux")
RUNNERS[zed] = Vector3.new(1, 0, 0)
runFor(1)
local phum = pm:FindFirstChildOfClass("Humanoid")
check(near(phum.WalkSpeed, 13.4, 1e-6), `P2e vitesse fixe du vigile de la zone ({phum.WalkSpeed})`)
humOf(zed).WalkSpeed = 40
runFor(0.3)
check(near(phum.WalkSpeed, 13.4, 1e-6), "P2f elle ne suit pas la vitesse de la cible")
check(#animEvents("Run", "Play", tp) >= 1, "P2g Run jouée en poursuite")
local rec = watchFade(pm, 15)
RUNNERS[zed] = nil
check(#animEvents("Tired", "Play", tp) == 1, "P2h Keeps faux : essoufflé (Tired) comme un vigile")
check(not fullLogHas("Tired", "WARN"), "P2i Tired est à son contrat : aucun avertissement")
check(rec.fadeAt ~= nil and rec.goneAt ~= nil, "P2j puis il s'efface en fondu sur place et disparaît")
check(rec.fadeAt and rec.fadeAt - tp >= 6 + TRACK_LENGTH.Tired - 0.2, `P2k le fondu attend la fin de Tired ({rec.fadeAt and string.format("%.2f", rec.fadeAt - tp)} s)`)
check(fullLogHas("policier NPC_Police_Z1", "PRINT") and fullLogHas("poursuite trop longue", "PRINT"), "P2l « policier » et la raison dans la sortie")
zs = chaseStates(zed)
check(zs[#zs].args[1] == false, "P2m ChaseState(false) à l'abandon")

print("\n--- P3 capture d'un joueur qui ne porte rien")
local yan = addPlayer("Yan", Vector3.new(1530, 3, 0))
deadline = now() + 60
local carryCalls = #CarryService.Calls
local tc = now()
local pm2 = GuardService.StartDriverChase(policeChase(yan, 1500))
rec = watchFade(pm2, 15)
runFor(3)
check(#animEvents("Catch", "Play", tc) == 1, "P3a rattrapé : Catch jouée")
check(notified(yan, BUSTED), "P3b Notify « Busted! The police caught you. »")
check(#CarryService.Calls == carryCalls, "P3c il ne portait rien : rien de perdu")
local stuns = {}
for _, e in Stats.Log do
	if e.player == yan and e.key == "GuardStun" then
		table.insert(stuns, e)
	end
end
check(#stuns >= 2 and stuns[1].mult == 0 and stuns[#stuns].mult == nil, "P3d immobilisé puis relâché (GuardStun), comme avec un vigile")
check(#animEvents("Tired", "Play", tc) == 0, "P3e après une capture : pas de Tired")
check(rec.fadeAt ~= nil and rec.goneAt ~= nil, "P3f il s'efface après Catch")

print("\n--- P4 Keeps faux avant le départ")
local xia = addPlayer("Xia", Vector3.new(2530, 3, 0))
deadline = now() - 1
local tw = now()
local pm3 = GuardService.StartDriverChase(policeChase(xia, 2500))
rec = watchFade(pm3, 5)
check(rec.goneAt ~= nil and fullLogHas("poursuite trop longue, avant le départ", "PRINT"), "P4a abandon dès le délai de réaction")
check(#animEvents("Tired", "Play", tw) == 0, "P4b pas encore élancé : pas de Tired")

local warnings = 0
for _, line in FULL_LOG do
	if line.kind == "WARN" and string.find(string.lower(line.text), "polic", 1, true) then
		warnings += 1
		print("    " .. line.text)
	end
end
check(warnings == 0, `P5 aucun avertissement sur le policier ({warnings})`)
summary()
