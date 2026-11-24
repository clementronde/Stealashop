--!nocheck
-- a254 (vague 73, L-240 point 3). Lu après le harnais a30 (copie a66) et la tête du banc a103 (comme a239).
-- ANNOUNCE_OFF (variante « off ») : Config/Announce.Enabled = false dans le fichier assemblé.
local OFF = ANNOUNCE_OFF == true

local STORE_Z4 = buildStore("STORE_Z4_Bijouterie", 4, 130, 1)
local STORE_Z5 = buildStore("STORE_Z5_GalerieDArt", 5, 130, -1)
startAll(true)
flush()
local Settings = sharedModule("Config/Announce")
local Announce = sharedModule("Announce")
local ItemsCfg = sharedModule("Config/Items")
local FRAME60 = 1 / 60
local function force(pattern, stores)
	table.clear(HEIST_FORCED)
	for _ = 1, stores do
		for _, v in pattern do
			table.insert(HEIST_FORCED, v)
		end
	end
end
-- Par magasin : Luxe, Premium ×3, Standard ×6. 0,9999 = la plus haute rareté du type (Luxe : Secret, Premium : Mythique,
-- Standard : Épique) ; 0 = la plus basse.
local ONE = { 0.9999, 0, 0, 0, 0, 0, 0, 0, 0, 0 } -- 1 Secret par magasin
local MYTHIC = { 0, 0.9999, 0, 0, 0, 0, 0, 0, 0, 0 } -- 1 Mythique par magasin
local LOW = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
local alice = player("Alice", Vector3.new(0, 3, 0))
local bob = player("Bob", Vector3.new(5, 3, 0))
local cara = player("Cara", Vector3.new(-5, 3, 0))
flush()
local function sent(since, to)
	return remotes("Announce", function(e)
		return e.t >= since and (to == nil or e.to == to)
	end)
end
local function notes(since, to, pattern)
	return remotes("Notify", function(e)
		return e.t >= since and (to == nil or e.to == to) and string.find(e.args[1], pattern, 1, true) ~= nil
	end)
end

section("A0 Config/Announce")
check(Settings.Enabled == not OFF, `A0a interrupteur Enabled = {tostring(Settings.Enabled)}`)
check(Rarities.ById[Settings.DayBoxMinRarity] ~= nil and Rarities.ById[Settings.StealMinRarity] ~= nil, "A0b raretés connues")
check(Settings.Hold > 0 and Settings.Gap >= 0 and Settings.MaxQueue >= 1, "A0c Hold, Gap, MaxQueue")
check(Announce.strip('A <font color="#FFC21A">LEGENDARY</font> box') == "A LEGENDARY box", "A0d strip")
local tag = Announce.rarityText(Rarities.ById.Legendary)
check(tag == '<font color="#FFC21A">LEGENDARY</font>', `A0e couleur : {tag}`)

section("A1 la nuit : colis Secret, une annonce groupée")
do
	Workspace:SetAttribute("NightPhase", "Night")
	local t0 = now()
	force(ONE, 4)
	Heist.RefillAll(true)
	advance(0.5, FRAME60)
	table.clear(HEIST_FORCED)
	advance(1.5)
	if OFF then
		check(#sent(t0) == 0, "A1 coupé : aucun Announce")
		local n = notes(t0, alice, "rare boxes just appeared")
		check(#n == 1 and n[1].args[2] == "Announce", `A1 coupé : Notify comme avant ({#n})`)
	else
		local a = sent(t0, alice)
		check(#a == 1 and #sent(t0, bob) == 1 and #notes(t0, alice, "just appeared") == 0, `A1a une annonce chacun, pas de Notify ({#a})`)
		local e = a[1]
		local msg = if e then e.args[1] else ""
		local detail = if e then e.args[2] else ""
		local icon = if e then e.args[3] else ""
		local plain = if e then e.args[4] else ""
		check(string.find(plain, "^2 rare boxes just appeared! Best: SECRET at ") ~= nil, `A1b texte sans balises : « {plain} »`)
		check(string.find(msg, '<font color="#FF3B3B">SECRET</font>', 1, true) ~= nil, `A1c rareté en couleur : « {msg} »`)
		check(string.find(detail, "until dawn", 1, true) ~= nil and string.find(detail, "^Zone [45]") ~= nil, `A1d detail : « {detail} »`)
		check(icon == "ICON_BOX_Secret", `A1e icône : {icon}`)
		check(#plain <= 200 and #msg <= 400, "A1f longueurs du remote")
	end
end

section("A2 le jour : Mythique et plus seulement")
do
	Workspace:SetAttribute("NightPhase", "Day")
	local t0 = now()
	force(LOW, 4)
	Heist.RefillAll()
	table.clear(HEIST_FORCED)
	advance(3)
	check(#sent(t0) == 0 and #notes(t0, alice, "just appeared") == 0, "A2a colis ordinaires : rien")
	local t1 = now()
	force(MYTHIC, 4)
	Heist.RefillAll()
	table.clear(HEIST_FORCED)
	advance(3)
	if OFF then
		check(#sent(t1) == 0 and #notes(t1, alice, "just appeared") == 0, "A2b coupé : rien de jour (comme avant)")
	else
		local a = sent(t1, alice)
		local plain = if a[1] then a[1].args[4] else ""
		local detail = if a[1] then a[1].args[2] else ""
		check(#a == 1 and string.find(plain, "Best: MYTHIC", 1, true) ~= nil, `A2b une annonce de jour : « {plain} » ({#a})`)
		check(string.find(detail, "be quick", 1, true) ~= nil, `A2c detail de jour : « {detail} »`)
	end
end

section("A3 vol entre joueurs (Shared/Announce.steal)")
do
	local legendary, common
	for _, item in ItemsCfg.List do
		if item.Rarity == "Legendary" and legendary == nil then
			legendary = item
		end
		if item.Rarity == "Common" and common == nil then
			common = item
		end
	end
	local t0 = now()
	Announce.steal(alice, bob, common.Id, "+$10/s")
	check(#sent(t0) == 0, "A3a objet Commun : rien")
	Announce.steal(alice, bob, legendary.Id, "+$1.25M/s")
	advance(0.1)
	local toCara, toAlice, toBob = sent(t0, cara), sent(t0, alice), sent(t0, bob)
	if OFF then
		check(#sent(t0) == 0 and #notes(t0, cara, "stole") == 0, "A3 coupé : rien")
	else
		local plain = if toCara[1] then toCara[1].args[4] else ""
		check(#toCara == 1 and #toAlice == 0 and #toBob == 0, `A3b aux autres seulement (Cara {#toCara}, Alice {#toAlice}, Bob {#toBob})`)
		check(plain == `Alice stole a LEGENDARY {legendary.DisplayName} from Bob!`, `A3c « {plain} »`)
		check(toCara[1] ~= nil and toCara[1].args[2] == "+$1.25M/s" and toCara[1].args[3] == "ICON_" .. legendary.Id, "A3d detail = revenu, icône de l'objet")
	end
end

section("A4 chance du serveur (Shared/Announce.serverLuck)")
do
	local t0 = now()
	Announce.serverLuck(alice, 8, 15, nil, "UI_Icon_DP_ServerLuck8", "Alice gave the whole server ×8 LUCK for 15 min!")
	Announce.serverLuck(bob, 2, 15, 8, nil, "Bob gave the whole server ×2 LUCK for 15 min! It starts after the current ×8.")
	advance(0.1)
	if OFF then
		local n = notes(t0, cara, "gave the whole server")
		check(#n == 2 and n[1].args[1] == "Alice gave the whole server ×8 LUCK for 15 min!" and n[1].args[2] == "Announce", "A4 coupé : Notify d'avant, mot pour mot")
	else
		local a = sent(t0, alice)
		check(#a == 2, `A4a à tous, l'acheteur compris ({#a})`)
		local first, second = a[1], a[2]
		check(first ~= nil and first.args[4] == "Alice gave the whole server ×8 LUCK for 15 min!", "A4b texte de repli = texte d'avant")
		check(first ~= nil and string.find(first.args[1], "×8 LUCK</font>!", 1, true) ~= nil and first.args[2] == "Rarer boxes for everyone · 15 min",
			`A4c « {first and first.args[1]} » / « {first and first.args[2]} »`)
		check(first ~= nil and first.args[3] == "UI_Icon_DP_ServerLuck8|UI_Icon_DP_Luck3", "A4d icône du produit puis repli")
		check(second ~= nil and second.args[2] == "Starts after the current ×8 · 15 min" and second.args[3] == "UI_Icon_DP_Luck3", "A4e en file : detail et icône")
	end
end
check(logCount("tick :", "WARN", "server") == 0, "aucune erreur du tick")
summary(if OFF then "scénario off" else "scénario night")
