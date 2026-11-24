--!nocheck
-- Scénario « notify » du banc a126 (vague 38, L-135 point 2, Clément : « code », un seul message à la fois pendant le
-- tuto) : vrai NotifyController sur UI_Toast. Tuto en cours = attribut TutorialStep du Player > 0 (TutorialService).

local TOAST = buildToast(PLAYER_GUI)
buildHud(PLAYER_GUI)
startClient()
local Notify = clientModule("NotifyController")
local UiMotion = sharedModule("Config/UiMotion")
local HOLD, FADE = UiMotion.Toast.Hold, UiMotion.Toast.FadeTime

local function shownTexts()
	local out = {}
	for _, info in Notify.GetShown() do
		table.insert(out, info.Text or "?")
	end
	return table.concat(out, " | ")
end
local function pendingTexts()
	local out = {}
	for _, info in Notify.GetPending() do
		table.insert(out, `{info.Message}×{info.Count}`)
	end
	return table.concat(out, " | ")
end

section("hors tuto : rien ne change (3 messages à la fois)")
check(type(Notify.GetPending) == "function", "NotifyController.GetPending existe")
Notify.Show("Alpha", "Info")
Notify.Show("Bravo", "Info")
Notify.Show("Charlie", "Success")
flush()
check(#Notify.GetShown() == 3 and #Notify.GetPending() == 0, `3 messages affichés, aucun en attente ({shownTexts()})`)
check(#toastCopies(TOAST) == 3, "3 copies dans UI_Toast.Stack")
advance(HOLD + FADE + 0.2)
check(#Notify.GetShown() == 0 and #toastCopies(TOAST) == 0, "partis après Hold + FadeTime")

section("pendant le tuto : un seul message à la fois")
P1:SetAttribute("TutorialStep", 4)
Notify.Show("One", "Info")
Notify.Show("Two", "Warning")
Notify.Show("Three", "Info")
Notify.Show("Two", "Warning") -- même message déjà en attente : compté
flush()
check(#Notify.GetShown() == 1 and Notify.GetShown()[1].Text == "One", `un seul affiché : « One » ({shownTexts()})`)
check(#toastCopies(TOAST) == 1, "une seule copie dans Stack")
check(pendingTexts() == "Two×2 | Three×1", `en attente dans l'ordre : Two (×2), Three ({pendingTexts()})`)
Notify.Show("One", "Info") -- déjà affiché : compté, pas mis en attente
flush()
check(Notify.GetShown()[1].Text == "One ×2" and #Notify.GetPending() == 2, `répété : « One ×2 » ({shownTexts()})`)
advance(HOLD + 0.1)
check(#Notify.GetShown() == 0 and #Notify.GetPending() == 2, "One parti : Two attend la fin de l'effacement")
check(#toastCopies(TOAST) <= 1, "pendant l'effacement : au plus la copie qui s'efface")
advance(FADE + 0.1)
check(#Notify.GetShown() == 1 and Notify.GetShown()[1].Text == "Two ×2", `puis Two, avec son compte : « Two ×2 » ({shownTexts()})`)
check(#toastCopies(TOAST) == 1 and #Notify.GetPending() == 1, "toujours une seule copie, Three attend")
advance(HOLD + FADE + 0.2)
check(#Notify.GetShown() == 1 and Notify.GetShown()[1].Text == "Three", `puis Three ({shownTexts()})`)
advance(HOLD + FADE + 0.2)
check(#Notify.GetShown() == 0 and #Notify.GetPending() == 0, "tout est parti")

section("pendant le tuto : la file garde au plus 3 messages en tout")
for _, text in { "M1", "M2", "M3", "M4", "M5" } do
	Notify.Show(text, "Info")
end
flush()
check(Notify.GetShown()[1].Text == "M1" and pendingTexts() == "M4×1 | M5×1", `M1 affiché, M4 et M5 en attente, M2 et M3 tombés ({pendingTexts()})`)

section("fin du tuto : ce qui attend s'affiche tout de suite")
P1:SetAttribute("TutorialStep", 0)
advance(0.1)
check(#Notify.GetPending() == 0 and #Notify.GetShown() == 3, `M1, M4 et M5 affichés ensemble ({shownTexts()})`)
advance(HOLD + FADE + 0.2)
Notify.Show("After1", "Info")
Notify.Show("After2", "Info")
flush()
check(#Notify.GetShown() == 2 and #Notify.GetPending() == 0, "après le tuto : plusieurs messages à la fois, comme avant")

check(not logHas("[NotifyController]", "WARN", "client"), "aucun avertissement de NotifyController")
check(not logHas("ERREUR", nil, "client"), "aucune erreur")
summary("scénario notify")
