--!nocheck
-- Scénario « rebirthlive » (a164, vague 51) : renaissance ouverte par le serveur (attribut Rebirths du Player,
-- RebirthService) : Status suit RebirthItemOwned, KeepList.Row1 = « Your 3 best items », confirmation en 2 temps
-- (Disabled → Ready → Confirm → envoi Rebirth(n+1)), retour à Ready après CONFIRM_WINDOW, l'écran se ferme et
-- passe au palier suivant quand Rebirths monte. Le serveur n'est pas lancé : seul l'envoi est contrôlé.

local HUD = buildHud(PLAYER_GUI)
local REBIRTH = buildRebirth(PLAYER_GUI)
P1:SetAttribute("Cash", 5e9)
startClient()

local function el(path)
	return rebirthEl(REBIRTH, path)
end
local function shown()
	local list = {}
	for _, state in { "Disabled", "Ready", "Confirm" } do
		if el("ConfirmButton." .. state).Visible then
			table.insert(list, state)
		end
	end
	return table.concat(list, ",")
end
local function rebirthCalls()
	local list = {}
	for _, call in SERVER_CALLS do
		if call.name == "Rebirth" then
			table.insert(list, call)
		end
	end
	return list
end

section("sans attribut Rebirths : l'aperçu")
local button = hudButton(HUD, "RebirthButton")
click(button)
check(el("Hint").Text == "Coming soon" and shown() == "Disabled", "aperçu : Coming soon, Disabled")
click(el("ConfirmButton"))
click(el("ConfirmButton"))
check(#rebirthCalls() == 0, "aperçu : aucun envoi")

section("renaissance ouverte, il manque l'argent et l'objet")
P1:SetAttribute("RebirthItemOwned", false)
P1:SetAttribute("Rebirths", 0)
flush()
check(el("Level").Text == "Level 0 → 1", `Level : {el("Level").Text}`)
check(shown() == "Disabled" and el("Hint").Text == "Get the cash and the item first", `Disabled, indication ({el("Hint").Text})`)
check(el("ItemRequirement.Status").Text == "Not owned yet", "Status : texte de Clément")
check(el("KeepList.Row1.RowLabel").Text == "Your 3 best items", "KeepList.Row1 : les 3 qui rapportent le plus")
click(el("ConfirmButton"))
click(el("ConfirmButton"))
check(#rebirthCalls() == 0, "Disabled : aucun envoi")

section("l'objet, pas l'argent")
P1:SetAttribute("RebirthItemOwned", true)
flush()
check(el("ItemRequirement.Status").Text == "Owned!" and shown() == "Disabled", "Status « Owned! », toujours Disabled")

section("l'argent et l'objet : Ready, puis Confirm, puis envoi")
P1:SetAttribute("Cash", 21e9)
flush()
check(shown() == "Ready" and el("Hint").Text == "Tap twice to confirm", `Ready, texte de Clément ({el("Hint").Text})`)
click(el("ConfirmButton"))
check(shown() == "Confirm" and el("Hint").Text == "Tap again to rebirth" and #rebirthCalls() == 0, "1er appui : Confirm, rien d'envoyé")
advance(5)
check(shown() == "Ready", "sans 2e appui en 4 s : retour à Ready")
click(el("ConfirmButton"))
click(el("ConfirmButton"))
local calls = rebirthCalls()
check(#calls == 1 and calls[1].args[1] == 1 and calls[1].args.n == 1, `2e appui : Rebirth(1) envoyé une fois ({#calls})`)
check(shown() == "Ready", "après l'envoi : Ready (le serveur décide)")

section("l'objet perdu en route : Disabled, Status de Clément")
P1:SetAttribute("RebirthItemOwned", false)
flush()
check(shown() == "Disabled" and el("ItemRequirement.Status").Text == "Not owned yet", "Disabled, « Not owned yet »")
P1:SetAttribute("RebirthItemOwned", true)
flush()

section("renaissance faite : l'écran se ferme, palier suivant")
check(REBIRTH.Enabled == true, "écran ouvert")
P1:SetAttribute("Cash", 0)
P1:SetAttribute("RebirthItemOwned", false)
P1:SetAttribute("Rebirths", 1)
flush()
advance(1)
check(REBIRTH.Enabled == false, "Rebirths monte : l'écran se ferme")
check(el("Level").Text == "Level 1 → 2" and el("ItemRequirement.ItemName").Text == "GOLDEN THRONE" and el("CashRequirement.CashAmount").Text == "$500B", `palier 2 : {el("Level").Text}, {el("ItemRequirement.ItemName").Text}, {el("CashRequirement.CashAmount").Text}`)
check(el("GainList.Row2.RowLabel").Text == "+1 Safe" and shown() == "Disabled", "récompense « +1 Safe », Disabled")

section("renaissance coupée en cours de partie (attribut retiré) : l'aperçu revient")
P1:SetAttribute("Rebirths", nil)
P1:SetAttribute("RebirthItemOwned", nil)
flush()
click(button)
check(el("Level").Text == "Level 0 → 1" and el("Hint").Text == "Coming soon" and shown() == "Disabled", "aperçu : Level 0 → 1, Coming soon, Disabled")

summary("scénario rebirthlive")
