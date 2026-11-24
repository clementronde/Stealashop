--!nocheck
-- Scénario « door » (a124) : Bob casse la porte du bot. Le bot se désancre, joue Run, court vers lui, le suit
-- sans le frapper tant qu'il reste devant la porte, le frappe dès qu'il entre (« Intruder », batte en main,
-- SwingBat et souffle), Bob est sorti et ne peut plus voler cette boutique 60 s ; le bot rentre et se ré-ancre.

startBotServer()
local PvP = sharedModule("Config/PvP")
local bobData = newProfile()
local bob = join("Bob", bobData)
giveBat(bob)
local plot, S = botArrives()

section("valeurs V0 de Config/Bot.Defense")
local D = BotConfig.Defense
check(D ~= nil and D.Enabled == true, "Config/Bot.Defense, activée")
check(D.RunSpeed == 13.4 and D.TutorialRunSpeed == 12 and D.TutorialMaxStrikes == 1, `vitesses 13,4 (vigile de zone 1) et 12 (tuto), 1 coup au tuto (trouvé {D.RunSpeed}, {D.TutorialRunSpeed})`)
check(D.SwingRange == BatConfig.Range and D.SwingCooldown == BatConfig.Cooldown, "portée et cadence de la batte")
check(D.LeashDistance == 15 and D.GiveUpTime == 10 and D.ReturnTimeout == 10 and D.HomeDistance == 2, "laisse 15 studs, 10 s, retour 10 s, 2 studs")

section("avant : avatar ancré au point d'apparition")
check(plot ~= nil and plot == SHOPS[5].model, `le bot prend la boutique 5 (trouvé {plot and plot.Name})`)
local root, humanoid = botRoot(), botHumanoid()
check(root ~= nil and root.Anchored == true, "HumanoidRootPart ancré")
local home = root.CFrame
local anims = botAvatar():FindFirstChild("Animations")
check(anims and anims:FindFirstChild("Idle") and anims:FindFirstChild("Run"), "Animations/Idle et Animations/Run gardées du script Animate")
check(anims:FindFirstChild("Run").AnimationId == "rbxassetid://50777", "Run : la course par défaut de Roblox")
check(not BotService.IsChasing(bob), "pas de poursuite")
advance(1)
check(root.Anchored and (root.Position - home.Position).Magnitude < 1e-3, "il ne bouge pas sans raison")

section("porte cassée : poursuite du casseur")
local runsBefore = animPlays("Run")
check(breakDoor(bob, plot), "Bob casse la porte du bot")
flush()
check(root.Anchored == false, "désancré à la casse")
check(rawget(root, "_networkOwner") == nil and BotService.IsChasing(bob), "possédé par le serveur, poursuit Bob")
check(animPlays("Run") == runsBefore + 1, "Run joue")
local bat = botAvatar():FindFirstChild("Bat")
check(bat ~= nil and bat:IsA("Tool") and bat:FindFirstChild("Handle") and bat.Handle.CanCollide == false, "batte TOOL_Batte en main, sans collision")
check(humanoid.WalkSpeed == 13.4 or waitFor(function() return humanoid.WalkSpeed == 13.4 end, 0.3), `WalkSpeed 13,4 (trouvé {humanoid.WalkSpeed})`)
local bounds = plot:FindFirstChild("Bounds")
check(not inBox(bounds, rootOf(bob).Position), "Bob est devant la porte, dehors")
local reached = waitFor(function()
	return (root.Position - rootOf(bob).Position).Magnitude <= 7
end, 8)
check(reached, `le bot arrive à portée de Bob (à {math.round((root.Position - rootOf(bob).Position).Magnitude)} studs)`)
advance(2)
check(#BOT_HITS == 0 and bob:GetAttribute("BatStun") == nil, "Bob devant la porte : suivi, pas frappé")
check(animPlays("SwingBat") == 0, "pas de SwingBat dans le vide")

section("Bob entre : frappé comme un intrus")
moveTo(bob, Vector3.new(S.door.X, 3, S.door.Z) - S.front * 6, S.front * -1) -- dans la boutique, à 6 studs de la porte
advance(0.1)
check(inBox(bounds, rootOf(bob).Position), "Bob est dans la boutique du bot")
local hit = waitFor(function()
	return #BOT_HITS > 0
end, 6)
check(hit and BOT_HITS[1].target == bob and BOT_HITS[1].usage == "Intruder" and BOT_HITS[1].plot == plot, `BatService.OnBotHit(boutique, Bob, « Intruder ») (trouvé {BOT_HITS[1] and BOT_HITS[1].usage})`)
check(#PLAYER_HITS == 0, "BatService.OnHit pas appelé (le bot n'est pas un Player)")
check(animPlays("SwingBat") >= 1, "SwingBat (l'animation du joueur) jouée par le bot")
check(soundCount("Play", "SwingBat_Impact") >= 1, "souffle SwingBat_Impact joué sur le bot")
advance(0.2)
check(bob:GetAttribute("BatStun") == "Stun", "Bob étourdi (attribut BatStun : son et Stunned chez les clients)")
check(not inBox(bounds, rootOf(bob).Position), "Bob est sorti de la boutique")
local left = PvPService.GetRobCooldown(bob, plot)
check(left > 58 and left <= 60, `Bob ne peut plus voler le bot pendant {PvP.KickRobCooldown} s (reste {left})`)
check(#notifies(bob, "Kicked out! You can rob this shop again in 60s.") == 1, "Notify à Bob : Kicked out!")
check(bob:GetAttribute("RobCooldown_" .. tostring(plot:GetAttribute("PlotIndex"))) ~= nil, "attribut RobCooldown_<PlotIndex> (panneau)")

section("retour et ré-ancrage")
check(waitFor(function()
	return not BotService.IsChasing(bob)
end, 1), "Bob frappé : plus poursuivi")
local back = waitFor(function()
	return root.Anchored
end, 12)
check(back, "le bot rentre et se ré-ancre")
check((root.Position - home.Position).Magnitude < 1e-3, `de nouveau à son point d'apparition (à {(root.Position - home.Position).Magnitude} studs)`)
check(botAvatar():FindFirstChild("Bat") == nil, "batte rangée")
check(animPlays("Idle") >= 2, "Idle de nouveau")
local idleTrack
for _, e in ANIM_LOG do
	if e.name == "Run" then
		idleTrack = e
	end
end
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles")
summary("scénario door")
