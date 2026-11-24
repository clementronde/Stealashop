--!nocheck
-- a239 (vague 71, L-216 points 1, 4 et 7). Lu après le harnais a30 (copie a66) et la tête du banc a103.
-- ANNOUNCE_OFF (variante « off ») : Unbox.NightBoxAnnounce = false dans le fichier assemblé.
local OFF = ANNOUNCE_OFF == true

-- Deux magasins hors zone 1 (la zone 1 ne tire que des Communs, ShelfBoxes.ZoneOdds), 10 rayons chacun.
local STORE_Z4 = buildStore("STORE_Z4_Bijouterie", 4, 130, 1)
local STORE_Z5 = buildStore("STORE_Z5_GalerieDArt", 5, 130, -1)
startAll(true)
flush()
local Unbox = sharedModule("Config/Unbox")
local FRAME60 = 1 / 60

-- Valeurs forcées de random:NextNumber() de StoreHeistService : un paquet de 10 par magasin (un tirage de rareté
-- par colis, dans l'ordre Luxe, Premium ×3, Standard ×6). 0,9999 = la rareté la plus haute du type (Luxe : Secret,
-- Premium : Mythique, Standard : Épique) ; 0 = la plus basse. Zone 1 : Commun quoi qu'il arrive.
local function force(pattern, stores)
	table.clear(HEIST_FORCED)
	for _ = 1, stores do
		for _, v in pattern do
			table.insert(HEIST_FORCED, v)
		end
	end
end
local ONE = { 0.9999, 0, 0, 0, 0, 0, 0, 0, 0, 0 } -- 1 Secret par magasin des zones 4 et 5
local ALL = { 0.9999, 0.9999, 0.9999, 0.9999, 0.9999, 0.9999, 0.9999, 0.9999, 0.9999, 0.9999 } -- 1 Secret + 3 Mythiques
local alice = player("Alice", Vector3.new(0, 3, 0))
local bob = player("Bob", Vector3.new(5, 3, 0))
flush()
local function announces(since, to)
	return notifiesSince("just appeared", since, to)
end

section("N0 Config/Unbox")
check(type(Unbox.NightBoxAnnounce) == "boolean" and Unbox.NightBoxAnnounce == not OFF, `N0a interrupteur NightBoxAnnounce = {Unbox.NightBoxAnnounce}`)
check(Rarities.ById[Unbox.NightBoxMinRarity] ~= nil and Unbox.NightBoxGroupDelay >= 0, "N0b rareté minimale connue, délai ≥ 0")
check(string.find(Unbox.NightBoxText, "{rarity}", 1, true) and string.find(Unbox.NightBoxesText, "{count}", 1, true), "N0c textes avec {rarity} et {count}")

section("N1 le jour : aucune annonce, même avec des colis Secret")
do
	Workspace:SetAttribute("NightPhase", "Day")
	local t0 = now()
	force(ALL, 4)
	Heist.RefillAll()
	table.clear(HEIST_FORCED)
	advance(3)
	check(#announces(t0) == 0, `N1 aucune annonce de jour ({#announces(t0)})`)
end

if OFF then
	section("N9 interrupteur coupé : aucune annonce la nuit")
	Workspace:SetAttribute("NightPhase", "Night")
	local t0 = now()
	force(ALL, 4)
	Heist.RefillAll(true)
	advance(0.5, FRAME60)
	table.clear(HEIST_FORCED)
	advance(3)
	check(#announces(t0) == 0, "N9 NightBoxAnnounce = false : rien")
	check(not logHas("annonce de nuit", "PRINT"), "N9 rien dans la sortie")
	summary("scénario off")
	return
end

section("N2 la nuit, un magasin par image : une seule annonce groupée, à tous")
do
	Workspace:SetAttribute("NightPhase", "Night")
	local t0 = now()
	force(ONE, 4)
	Heist.RefillAll(true)
	advance(0.5, FRAME60)
	table.clear(HEIST_FORCED)
	check(#announces(t0) == 0, "N2a rien avant NightBoxGroupDelay")
	advance(1.5)
	local a, b = announces(t0, alice), announces(t0, bob)
	check(#a == 1 and #b == 1, `N2b une annonce chacun (Alice {#a}, Bob {#b})`)
	local text = a[1] and a[1].args[1] or ""
	check(string.find(text, "^2 rare boxes just appeared! Best: SECRET at ") ~= nil, `N2c texte groupé : « {text} »`)
	check(string.find(text, "Jewelry", 1, true) or string.find(text, "Art Gallery", 1, true), "N2d nom du magasin lu dans Config/Zones")
	check(a[1] and a[1].args[2] == Unbox.AnnounceKind, "N2e catégorie Announce (Unbox.AnnounceKind)")
end

section("N3 la nuit, d'un coup : 8 colis, une annonce")
do
	local t0 = now()
	force(ALL, 4)
	Heist.RefillAll()
	table.clear(HEIST_FORCED)
	advance(2)
	local a = announces(t0, alice)
	local text = a[1] and a[1].args[1] or ""
	check(#a == 1 and string.find(text, "^8 rare boxes just appeared! Best: SECRET") ~= nil, `N3 « {text} » ({#a})`)
end

section("N4 magasin ouvert : les autres tout de suite, lui à sa fermeture (deux annonces séparées)")
do
	Workspace:SetAttribute("NightPhase", "Day")
	-- vitrine de zone 4 : PV calculés pour le marteau ; dégâts multipliés par l'accroche de WindowService le temps de casser
	local hook = WindowS.GetHitDamageMultiplier
	WindowS.GetHitDamageMultiplier = function() return 1e9 end
	local opened = breakHard(alice, STORE_Z4)
	WindowS.GetHitDamageMultiplier = hook
	check(opened and Heist.IsOpen(STORE_Z4), "N4a STORE_Z4 ouvert par Alice")
	Workspace:SetAttribute("NightPhase", "Night")
	local t0 = now()
	force(ONE, 3)
	Heist.RefillAll(true)
	advance(0.5, FRAME60)
	table.clear(HEIST_FORCED)
	advance(1.5)
	local a = announces(t0, bob)
	local text = a[1] and a[1].args[1] or ""
	check(#a == 1 and text == "A SECRET box just appeared at Art Gallery!", `N4b une seule, au singulier : « {text} »`)
	local t1 = now()
	force(ALL, 1)
	for _ = 1, 60 do
		advance(0.5)
		if #announces(t1, bob) > 0 then
			break
		end
	end
	table.clear(HEIST_FORCED)
	advance(1.5)
	local late = announces(t1, bob)
	local lateText = late[1] and late[1].args[1] or ""
	check(#late == 1 and lateText == "4 rare boxes just appeared! Best: SECRET at Jewelry", `N4c à la fermeture : « {lateText} » ({#late})`)
end
check(logCount("tick :", "WARN", "server") == 0, "aucune erreur du tick")

section("M1 mutations de matière tirées (L-216 point 7)")
do
	local ItemWeight = sharedModule("ItemWeight")
	local rng = Random.new(239)
	local counts, sizes, n = {}, 0, 200000
	for _ = 1, n do
		local m = Mutations.Roll(rng)
		if m and m.Effect then
			counts[m.Effect] = (counts[m.Effect] or 0) + 1
		end
		if m and m.Size then
			sizes += 1
		end
	end
	local ok, total, parts = true, 0, {}
	for _, entry in Mutations.Effects do
		local got = (counts[entry.Id] or 0) / n * 100
		total += got
		table.insert(parts, string.format("%s %.2f %% (%.2f)", entry.Id, got, entry.Chance))
		if math.abs(got - entry.Chance) > math.max(0.1, entry.Chance * 0.1) then
			ok = false
		end
	end
	print("MESURE mutations sur " .. n .. " tirages : " .. table.concat(parts, ", ") .. string.format(" ; total %.2f %%", total))
	check(#Mutations.Effects == 7 and ok, "M1a les 7 effets sortent, à leur chance (Config/Mutations)")
	check(not ItemWeight.Enabled() or sizes == 0, `M1b avec le poids, aucune taille tirée par Roll ({sizes})`)
	local src = SOURCES["server/Services/StoreHeistService.luau"]
	check(string.find(src, "local mutation = drawMutation(itemId)", 1, true) ~= nil and string.find(src, "Effect = effect }),", 1, true) ~= nil,
		"M1c StoreHeistService : effet tiré à l'ouverture (drawShelfContent) et gardé dans la cinématique (startReveal)")
end

section("M2 premier objet exposé, calculé depuis les Config (L-216 point 1)")
do
	local Tutorial = sharedModule("Config/Tutorial")
	local Zones = sharedModule("Config/Zones")
	local Tools = sharedModule("Config/Tools")
	local Reveal = sharedModule("Config/Reveal")
	local Night = sharedModule("Config/Night")
	local walk = Formulas.WalkSpeed(0)
	local carry = Balance.Carry.StolenItemWalkSpeed
	local hp = Zones[1].WindowHP
	local regen = Balance.Window.RegenPerSecond * hp
	local fists = Tools.ById.Fists.Power
	-- Trajets (studs, V0, relevés sur les scripts de Clément, pas en Studio) : de l'entrée de sa boutique (façades en
	-- x −66, z ±29,5 ou ±88,5, hub_place_du_mall) à la vitrine de la Supérette (x 74, z ≈ 60, corridor_widen) :
	-- 150 (boutique 3) à 205 (boutique 5) ; vitrine → rayon 20.
	local cases = {
		{ name = "rapide (sait quoi faire)", store = 150, read = 0, equip = 1, hits = Balance.Hit.MaxHitsPerSecond, tier = "Standard",
			reveal = Reveal.Fallback.OpenEnd + Reveal.Fallback.GrowTime.Small + Reveal.Fallback.LandHold.Small, place = 3, take = 1, display = 2 },
		{ name = "nouveau joueur (lit les bulles)", store = 205, read = 2, equip = 2, hits = 3, tier = Tutorial.FirstBoxTier,
			reveal = Reveal.MaxSeconds.Small + Reveal.HoldMax, place = 6, take = 2, display = 4 },
	}
	for _, c in cases do
		local rows = {
			{ "1 entrée de sa boutique → vitrine", c.read + c.store / walk },
			{ "2 sortir les poings, casser " .. hp .. " PV", c.read + c.equip + hp / (c.hits * fists - regen) },
			{ "3 rayon, ouvrir (" .. c.tier .. "), cinématique", c.read + 20 / walk + Balance.Heist.BoxTiers[c.tier].GrabTime + c.reveal },
			{ "4 retour (objet sur la tête)", c.read + (c.store + 20) / carry },
			{ "5 poser au sol, antivol, reprendre, exposer", c.read + c.place + Tutorial.AntiTheftDelay + c.take + c.display },
		}
		local total = 0
		local parts = {}
		for _, row in rows do
			total += row[2]
			table.insert(parts, string.format("%s %.1f s", row[1], row[2]))
		end
		print(string.format("MESURE premier objet exposé, %s : %.0f s (%s)", c.name, total, table.concat(parts, " ; ")))
		check(total <= 90, string.format("M2 %s : %.0f s ≤ 90 s sans entraînement", c.name, total))
	end
	local slack = Balance.Heist.Duration - 20 / walk
	print(string.format("MESURE marges : marche %d, porteur %d ; chrono du braquage %d s (%.1f s pour ouvrir un colis, sinon rideau + %d s de reconstruction) ; nuit %d s, raccourcie à %d s si le couloir est vide",
		walk, carry, Balance.Heist.Duration, slack, Balance.Window.RebuildDelay, Night.NightDuration, Night.EmptyCorridorRemaining))
end

summary("scénario night")
