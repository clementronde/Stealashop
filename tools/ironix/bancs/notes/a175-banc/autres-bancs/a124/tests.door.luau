--!nocheck
-- Scénario « door », copie a175 (vague 54, Cantin 2026-11-15 : le bot ne poursuit qu à la sortie de sa boutique avec
-- l objet). Copie a149 :
-- Scénario « door », copie a149 (vague 42, Cantin 2026-11-14 : le bot ne court après un joueur qu'une fois l'objet
-- volé, « pas quand on est dans sa base ») : Bob casse la porte du bot : rien ne bouge. Bob entre sans objet : ni
-- poursuivi ni frappé. Bob prend un objet et reste : poursuivi, frappé (« Defend »), sorti, 60 s ; le bot rentre,
-- batte toujours en main (L-146 point 2), Idle de nouveau.

startBotServer()
local PvP = sharedModule("Config/PvP")
local bob = join("Bob", newProfile())
giveBat(bob)
local plot, S = botArrives()

section("valeurs V0 de Config/Bot.Defense")
local D = BotConfig.Defense
check(D ~= nil and D.Enabled == true, "Config/Bot.Defense, activée")
check(D.RunSpeed == 13.4 and D.TutorialRunSpeed == 12 and D.TutorialMaxStrikes == 1, "vitesses 13,4 et 12, 1 coup au tuto")
check(D.TutorialKickCooldown == 15, `15 s d'attente en tuto après un coup du bot (trouvé {D.TutorialKickCooldown})`)
check(D.LeashDistance == 15 and D.GiveUpTime == 10, "laisse 15 studs, abandon à 10 s")

section("avant : ancré, batte en main")
local root, humanoid = botRoot(), botHumanoid()
check(root ~= nil and root.Anchored == true, "HumanoidRootPart ancré")
local home = root.CFrame
local bat = botBat()
check(bat ~= nil and bat:IsA("Tool") and bat:FindFirstChild("Handle") and bat.Handle.CanCollide == false, "batte TOOL_Batte en main dès l'arrivée, sans collision")
local scripts = 0
for _, d in bat:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		scripts += 1
	end
end
check(scripts == 0, "aucun script dans la batte du bot")

section("porte cassée : rien")
local runsBefore = animPlays("Run")
check(breakDoor(bob, plot), "Bob casse la porte du bot")
flush()
advance(2)
check(root.Anchored and not BotService.IsChasing(bob), "le bot reste ancré, pas de poursuite")
check(animPlays("Run") == runsBefore, "pas de Run")

section("intrus sans objet : ni poursuivi ni frappé")
local bounds = plot:FindFirstChild("Bounds")
moveTo(bob, Vector3.new(S.door.X, 3, S.door.Z) - S.front * 6, S.front * -1)
advance(0.1)
check(inBox(bounds, rootOf(bob).Position), "Bob est dans la boutique du bot")
advance(4)
check(#BOT_HITS == 0 and bob:GetAttribute("BatStun") == nil, "Bob pas frappé")
check(not BotService.IsChasing(bob) and root.Anchored, "Bob pas poursuivi")
check(animPlays("SwingBat") == 0, "aucun SwingBat")

section("Bob prend un objet et reste dans la boutique : rien (a175)")
check(steal(bob, plot, 2), "Bob prend l objet du présentoir 2 et reste là")
flush()
advance(4)
check(root.Anchored and not BotService.IsChasing(bob), "4 s dans la boutique avec l objet : pas de poursuite")
check(#BOT_HITS == 0 and animPlays("SwingBat") == 0 and CarryService.IsCarrying(bob), "aucun coup, Bob garde l objet")
check(animPlays("Run") == runsBefore, "pas de Run")

section("Bob sort avec l objet : poursuivi et frappé")
exitShop(bob, S)
advance(0.2)
check(root.Anchored == false and BotService.IsChasing(bob), "désancré, poursuit Bob")
check(animPlays("Run") == runsBefore + 1, "Run joue")
check(humanoid.WalkSpeed == 13.4 or waitFor(function() return humanoid.WalkSpeed == 13.4 end, 0.3), `WalkSpeed 13,4 (trouvé {humanoid.WalkSpeed})`)
local hit = waitFor(function()
	return #BOT_HITS > 0
end, 8)
check(hit and BOT_HITS[1].target == bob and BOT_HITS[1].usage == "Defend", `coup « Defend » sur Bob (trouvé {BOT_HITS[1] and BOT_HITS[1].usage})`)
check(soundCount("Play", "SwingBat_Impact") >= 1, "souffle SwingBat_Impact")
advance(0.2)
check(not CarryService.IsCarrying(bob), "objet repris")
check(BotService.GetExposed(plot)[2] ~= nil, "revenu sur son présentoir")
local left = PvPService.GetRobCooldown(bob, plot)
check(left > 58 and left <= 60, `hors tuto : {PvP.KickRobCooldown} s sans voler le bot (reste {left})`)

section("retour : batte gardée en main")
check(waitFor(function()
	return root.Anchored
end, 12), "le bot rentre et se ré-ancre")
check((root.Position - home.Position).Magnitude < 1e-3, "à son point d'apparition")
check(botBat() ~= nil and botBat() == bat, "la même batte, toujours en main")
check(animPlays("Idle") >= 2, "Idle de nouveau")
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles")
summary("scénario door")
