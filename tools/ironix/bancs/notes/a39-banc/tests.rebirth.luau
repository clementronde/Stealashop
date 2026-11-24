--!nocheck
-- Scénario « rebirth » : Config/Rebirths (valeurs du tableau de la Partie 2, 3.2) et l'écran UI_Rebirth
-- de Clément en aperçu (RebirthController) : rempli avec la 1re renaissance, ouvert et fermé par le
-- bouton du HUD et CloseButton, l'argent qui suit l'attribut Cash, le bouton qui reste Disabled,
-- « Coming soon », aucun style touché, écran recréé rebranché, écran absent.

local HUD = buildHud(PLAYER_GUI)
local REBIRTH = buildRebirth(PLAYER_GUI)
P1:SetAttribute("Cash", 6400)
local snap = snapshot(REBIRTH)
startClient()

local function el(path)
	return rebirthEl(REBIRTH, path)
end

section("Config/Rebirths : le tableau du doc")
local expected = {
	{ 10e3, "Z1_PotDeNouilles", "Rare", 1, "Aura « Renaissance »", 20 },
	{ 100e3, "Z2_VoitureTelecommandee", "Rare", 2, "+1 coffre-fort", 45 },
	{ 1e6, "Z2_RobotJouet", "Epic", 2, "+25 % de gains d'entraînement", 75 },
	{ 10e6, "Z3_ConsolePortable", "Epic", 3, "Trail « Renaissance »", 120 },
	{ 100e6, "Z4_DiamantBrut", "Epic", 4, "Marteau-piqueur débloqué", 180 },
	{ 1e9, "Z4_Couronne", "Legendary", 4, "+25 % de gains d'entraînement", 300 },
	{ 10e9, "Z5_MasqueAncien", "Legendary", 5, "Bélier débloqué", 480 },
	{ 100e9, "Z6_CoffreDeDiamants", "Legendary", 6, "2e agent de sécurité", 720 },
	{ 1e12, "Z5_Meteorite", "Mythic", 5, "Aura « Légende »", 1080 },
	{ 10e12, "Z6_CleDuCoffreUltime", "Mythic", 6, "Titre affiché au-dessus de la tête", nil },
}
check(#Rebirths.Tiers == 10, "10 lignes (la 10e = « 10 et suivantes »)")
for level, row in expected do
	local tier = Rebirths.Tiers[level]
	local item = Items.ById[row[2]]
	check(
		tier.Level == level and tier.Cash == row[1] and tier.ItemId == row[2] and tier.Rarity == row[3] and tier.Zone == row[4] and tier.Reward == row[5] and tier.PlayTimeMinutes == row[6],
		`renaissance {level} : {Format.money(row[1])}, {row[2]} ({row[3]}, zone {row[4]}), {row[5]}`
	)
	check(item ~= nil and item.Rarity == row[3] and item.Zone == row[4], `{row[2]} : même rareté et même zone dans Config/Items`)
	check(type(tier.RewardText) == "string" and tier.RewardText ~= "", `renaissance {level} : texte affiché « {tier.RewardText} »`)
end
check(Rebirths.Tiers[1].RewardText == "Rebirth Aura", "renaissance 1 : « Rebirth Aura », le texte de la maquette de Clément")
check(Rebirths.IncomeBonus == 0.5 and Rebirths.CashGrowth == 10, "+50 % de revenus par renaissance, ×10 au-delà")
check(Rebirths.Get(1) == Rebirths.Tiers[1] and Rebirths.Get(10) == Rebirths.Tiers[10], "Get(1), Get(10) : les lignes du tableau")
local eleventh = Rebirths.Get(11)
check(eleventh ~= nil and eleventh.Level == 11 and eleventh.Cash == 100e12 and eleventh.ItemId == "Z6_CleDuCoffreUltime", "Get(11) : ×10 de la 10e (100 T$), Clé du coffre ultime")
check(Rebirths.Get(13).Cash == 10e15, "Get(13) : ×10 à chaque fois")
check(Rebirths.Get(0) == nil and Rebirths.Get(-1) == nil and Rebirths.Get(1.5) == nil and Rebirths.Get(0 / 0) == nil and Rebirths.Get(math.huge) == nil, "Get : nil pour 0, -1, 1.5, NaN, l'infini")
check(table.isfrozen(Rebirths) and table.isfrozen(Rebirths.Tiers) and table.isfrozen(Rebirths.Tiers[3]) and table.isfrozen(eleventh), "tout est gelé (DeepFreeze), même une ligne au-delà du tableau")
check(not pcall(function()
	Rebirths.Tiers[1].Cash = 1
end), "écrire une valeur lève une erreur")

section("écran rempli au branchement, fermé")
check(REBIRTH.Enabled == false, "fermé au départ")
check(el("Level").Text == "Level 0 → 1", `Level : {el("Level").Text}`)
check(el("CashRequirement.CashAmount").Text == "$10K", `CashAmount : {el("CashRequirement.CashAmount").Text}`)
check(el("CashRequirement.CashLabel").Text == "$6.4K / $10K", `CashLabel : {el("CashRequirement.CashLabel").Text}`)
local fill = el("CashBar.Fill")
check(near(fill.Size.X.Scale, 0.64) and fill.Size.X.Offset == 2 and fill.Size.Y.Scale == 1 and fill.Size.Y.Offset == -4, `Fill à 64 %, Offset et hauteur de Clément gardés ({tostring(fill.Size)})`)
check(el("ItemRequirement.ItemName").Text == "INSTANT NOODLES", "ItemName : INSTANT NOODLES (en capitales, comme l'exemple)")
check(el("ItemRequirement.Rarity").Text == "RARE", "Rarity : RARE")
check(el("ItemRequirement.Rarity").TextColor3 == REBIRTH_RARITY_COLOR, "couleur de Rarity : celle de Clément")
check(el("ItemRequirement.Icon").Image == NOODLES_ICON, "Icon : ICON_Z1_PotDeNouilles (Assets/Icons)")
check(el("ItemRequirement.Status").Text == "Not owned yet", "Status : texte de Clément gardé (le client ne sait pas si le joueur a l'objet)")
check(el("ItemRequirement.Lock").Visible == true, "Lock pas touché")
check(el("GainList.Row2.RowLabel").Text == "Rebirth Aura", "GainList : la récompense du palier (Rebirth Aura)")
check(el("GainList.Row1.RowLabel").Text == "+50% income forever" and el("GainList.Row3.RowLabel").Text == '"Rebirth 1" title', "les autres lignes de GainList gardées")
check(el("LoseList.Row1.RowLabel").Text == "Cash" and el("KeepList.Row4.RowLabel").Text == "Robux purchases", "colonnes Lose et Keep gardées")
check(el("ConfirmButton.Disabled").Visible == true and el("ConfirmButton.Ready").Visible == false and el("ConfirmButton.Confirm").Visible == false, "ConfirmButton : Disabled seul visible")
check(el("Hint").Text == "Coming soon", `Hint : {el("Hint").Text}`)

section("ouverture et fermeture")
local button = hudButton(HUD, "RebirthButton")
check(button.Visible == true, "bouton Rebirth du HUD visible")
click(button)
check(REBIRTH.Enabled == true, "le bouton du HUD ouvre l'écran")
click(button)
check(REBIRTH.Enabled == false, "un 2e appui le ferme")
click(button)
click(el("CloseButton"))
check(REBIRTH.Enabled == false, "CloseButton le ferme")

section("l'argent suit l'attribut Cash")
click(button)
P1:SetAttribute("Cash", 12000)
flush()
check(el("CashRequirement.CashLabel").Text == "$12K / $10K" and near(fill.Size.X.Scale, 1), "12 000 $ : « $12K / $10K », barre pleine (au plus 1)")
P1:SetAttribute("Cash", 2500)
flush()
check(el("CashRequirement.CashLabel").Text == "$2.5K / $10K" and near(fill.Size.X.Scale, 0.25), "2 500 $ : barre au quart")
P1:SetAttribute("Cash", nil)
flush()
check(el("CashRequirement.CashLabel").Text == "… / $10K" and near(fill.Size.X.Scale, 0), "argent pas encore posé : « … », barre vide")
P1:SetAttribute("Cash", 6400)
flush()

section("ConfirmButton : rien")
local calls = #SERVER_CALLS
click(el("ConfirmButton"))
click(el("ConfirmButton"))
check(el("ConfirmButton.Disabled").Visible == true and el("ConfirmButton.Ready").Visible == false and el("ConfirmButton.Confirm").Visible == false, "deux appuis : toujours Disabled")
check(#SERVER_CALLS == calls, "aucun envoi au serveur")
check(REBIRTH.Enabled == true, "l'écran reste ouvert")

section("aucun style touché")
local allowed = {
	[REBIRTH] = { Enabled = true },
	[fill] = { Size = true },
	[el("CashRequirement.CashLabel")] = { Text = true },
	[el("ItemRequirement.Icon")] = { Image = true },
	[el("Hint")] = { Text = true },
}
local changes = diffSnapshot(snap, REBIRTH, allowed)
check(#changes == 0, `seuls Enabled, les textes de CashLabel et de Hint, l'image de Icon et la largeur de Fill ont changé ({table.concat(changes, " ; ")})`)
check(fill.BackgroundColor3 == Color3.fromRGB(47, 224, 143) and el("ItemRequirement.Icon").ImageColor3 == Color3.fromRGB(80, 80, 80), "couleurs de Fill et de Icon (grisée) : celles de Clément")
check(REBIRTH:FindFirstChildWhichIsA("UIScale", true) == nil, "aucun UIScale laissé par Motion")

section("écran recréé (ResetOnSpawn)")
REBIRTH:Destroy()
flush()
local again = buildRebirth(PLAYER_GUI)
flush()
check(again.Enabled == false and rebirthEl(again, "Hint").Text == "Coming soon" and rebirthEl(again, "Level").Text == "Level 0 → 1", "nouvel écran rebranché : rempli, fermé")
click(button)
check(again.Enabled == true, "le bouton du HUD ouvre le nouvel écran")
click(button)
check(again.Enabled == false, "et le referme")

section("écran absent")
again:Destroy()
flush()
clearLog()
click(button)
check(logHas("[Rebirth] écran UI_Rebirth absent de PlayerGui", "PRINT", "client"), "une ligne dans la sortie (Studio), aucune erreur")

section("textes de l'exemple en minuscules : écrits tels quels")
local lower = buildRebirth(PLAYER_GUI)
flush()
local name = rebirthEl(lower, "ItemRequirement.ItemName")
name.Text = "Instant noodles"
rebirthEl(lower, "ItemRequirement.Rarity").Text = "Rare item"
click(button)
check(name.Text == "Instant Noodles" and rebirthEl(lower, "ItemRequirement.Rarity").Text == "Rare", "Instant Noodles, Rare")

summary("scénario rebirth")
