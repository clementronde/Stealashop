--!nocheck
-- I. Bouton Invite (InviteController, L-057) : UI_HUD.SocialRow.InviteButton ouvre l'invitation de
-- Roblox (CanSendGameInviteAsync puis PromptGameInvite, dans des pcall, sans bloquer l'écran) ;
-- avec et sans permission, erreurs de Roblox, double clic, écran recréé ; aucun bonus, rien vers le
-- serveur, RewardsButton pas branché.

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-113, 3, 0))
local hud = copyHud(alice) -- Roblox copie UI_HUD de StarterGui dans le PlayerGui
startClient(alice)

local function button(gui)
	return gui:FindFirstChild("InviteButton", true)
end
local function click(gui)
	button(gui).Activated:Fire()
end
local function calls()
	return #SOCIAL.canSendCalls, #SOCIAL.promptCalls
end

section("I. Permis : l'invitation de Roblox s'ouvre")
click(hud)
flush()
local asked, prompted = calls()
check(asked == 1 and SOCIAL.canSendCalls[1].player == alice, "I1 un clic : CanSendGameInviteAsync(joueur local)")
check(prompted == 1 and SOCIAL.promptCalls[1].player == alice, "I2 … puis PromptGameInvite(joueur local)")
check(#SERVER_CALLS == 0, "I3 rien n'est envoyé au serveur (aucun bonus)")

section("I'. Roblox répond lentement : l'écran ne se bloque pas, un double clic ne compte qu'une fois")
SOCIAL.canSendDelay = 1
local before = now()
click(hud)
check(now() == before, "I4 le clic rend la main tout de suite (réponse attendue dans une autre tâche)")
local asked2, prompted2 = calls()
check(asked2 == 2 and prompted2 == 1, "I5 la demande est partie, l'invitation pas encore")
click(hud)
click(hud)
advance(1.2)
local asked3, prompted3 = calls()
check(asked3 == 2 and prompted3 == 2, `I6 deux clics de plus pendant l'attente : ignorés ({asked3} demandes, {prompted3} invitations)`)
SOCIAL.canSendDelay = 0

section("I''. Pas permis par Roblox")
clearLog()
SOCIAL.canSend = false
click(hud)
flush()
local asked4, prompted4 = calls()
check(asked4 == 3 and prompted4 == 2, "I7 CanSendGameInviteAsync = false : pas d'invitation")
check(logHas("Roblox ne permet pas d'inviter depuis ce compte", "PRINT", "client"), "I8 une ligne en Studio")
SOCIAL.canSend = true

section("I'''. Erreurs de Roblox, dans les pcall")
clearLog()
local fails = FAILS
SOCIAL.canSendError = "HTTP 503 (Service Unavailable)"
click(hud)
flush()
local asked5, prompted5 = calls()
check(FAILS == fails and asked5 == 4 and prompted5 == 2, "I9 CanSendGameInviteAsync en erreur : pas d'erreur, pas d'invitation")
check(logHas("CanSendGameInviteAsync : HTTP 503", "WARN", "client"), "I10 un avertissement en Studio")
SOCIAL.canSendError = nil
SOCIAL.promptError = "PromptGameInvite failed"
click(hud)
flush()
check(FAILS == fails and logHas("PromptGameInvite : PromptGameInvite failed", "WARN", "client"), "I11 PromptGameInvite en erreur : un avertissement, pas d'erreur")
SOCIAL.promptError = nil
click(hud)
flush()
local asked6, prompted6 = calls()
check(asked6 == 6 and prompted6 == 4, "I12 après une erreur, le bouton marche toujours")

section("I''''. Écran recréé à la réapparition (ResetOnSpawn)")
local old = hud
hud = copyHud(alice)
flush()
check(isDestroyed(old) and hud ~= old, "I13 nouvelle copie de UI_HUD")
click(hud)
flush()
local asked7, prompted7 = calls()
check(asked7 == 7 and prompted7 == 5, "I14 le bouton de la nouvelle copie est branché")
check(button(hud).Activated:ConnectionCount() == 1, "I15 une seule connexion sur le bouton (pas de double branchement)")
local rewards = hud:FindFirstChild("RewardsButton", true)
check(rewards.Activated:ConnectionCount() == 0, "I16 RewardsButton n'est pas branché")
local inviteLabel = hud:FindFirstChild("InviteLabel", true)
check(inviteLabel.Text == "INVITE" and button(hud).Visible == true and rewards.Visible == true, "I17 ni texte ni visibilité touchés")
check(#SERVER_CALLS == 0, "I18 toujours rien vers le serveur")

section("I'''''. InviteButton absent ou pas un bouton")
clearLog()
local broken = make("ScreenGui", { Name = "UI_HUD" })
local row = make("Frame", { Name = "SocialRow" }, broken)
make("Frame", { Name = "InviteButton" }, row)
hud:Destroy()
broken.Parent = alice.PlayerGui
flush()
check(logHas("UI_HUD.InviteButton n'est pas un bouton (Frame) : le bouton Invite ne fait rien (L-057)", "WARN", "client"), "I19 un Frame : une ligne en Studio")
broken:Destroy()
local empty = make("ScreenGui", { Name = "UI_HUD" }, alice.PlayerGui)
flush()
check(logHas("UI_HUD.InviteButton introuvable : le bouton Invite ne fait rien (L-057)", "WARN", "client"), "I20 absent : une ligne en Studio")
check(FAILS == fails, "I21 aucune erreur")

summary("scénario invite")
