--!nocheck
-- Valeurs proposées de l'économie « B/T » (a479, 25/11) : V0 à relire par Cantin, rien n'est dans le jeu.
-- Prix = revenu de référence de la zone (Reference) × minutes, arrondi à 2 chiffres (Outil/economie_bt).
-- Quatrième passe (décisions de Cantin du 25/11) : joueur moyen (1 h 30 par jour, absences payées) en zone 6 en 20 h de jeu,
-- raretés × 60, armes inchangées, découpage du tapis gardé, niveaux 21 à 25 ajoutés, hors ligne gardé (règle en zone 5).

local V = {}

-- Tapis (Config/Training, Formulas.TreadmillGain) : 6 crédits par seconde ; un crédit vaut 1 au niveau 1, × 2 par niveau.
V.Tapis = { TicksPerSecond = 6, GainPerTick = 1, GainGrowth = 2 }

-- Speed affichée demandée par zone (Config/Zones.SpeedRequired) : × 107 environ par zone jusqu'à la zone 5 ; zone 6 : 30T.
V.SpeedRequired = { 0, 15e3, 1.6e6, 170e6, 19e9, 30e12 }
-- La formule de la marche est calée sur les zones 2 à 5 (22, 28, 34, 40 comme aujourd'hui) ; la zone 6, montée avec les
-- niveaux 21 à 25 du tapis, sort de la suite régulière : sa marche au panneau vaut 49,4 au lieu de 46.
V.StatsLast = 5

-- $/s de base par rareté (Config/Rarities.Income) : échelle régulière, × 60 par rareté (décision de Cantin, 25/11),
-- arrondie : 1, 60, 3.6K, 220K, 13M, 800M, 50B. Divin : × 5 du Secret, comme aujourd'hui.
V.Income = { Common = 1, Uncommon = 60, Rare = 3.6e3, Epic = 220e3, Legendary = 13e6, Mythic = 800e6, Secret = 50e9, Divine = 250e9 }

-- Revenu de référence par zone ($/s) : sert seulement à écrire les prix.
V.Reference = { 5, 30, 1.5e3, 350e3, 35e6, 1.5e9 }

-- Puissance des armes : celle d'aujourd'hui (décision de Cantin, 25/11). ToolPower absent = Config/Tools.Power.

-- Prix : { Id, zone du revenu de référence, minutes }.
V.Tools = {
	{ "Wrench", 1, 1 },
	{ "Crowbar", 2, 1.7 },
	{ "Hammer", 3, 5 },
	{ "Sledgehammer", 4, 19 },
	{ "FireAxe", 5, 17 },
	{ "AngleGrinder", 5, 75 },
}
V.Auras = {
	{ "Shine", 1, 1 / 3 },
	{ "Fire", 2, 1 },
	{ "Storm", 3, 2 },
	{ "Poison", 3, 5 },
	{ "Tornado", 4, 19 },
	{ "Angel", 5, 9 },
	{ "Demon", 5, 35 },
	{ "Chained", 5, 75 },
}
V.Trails = {
	{ "Dust", 1, 1 / 3 },
	{ "Wind", 2, 0.7 },
	{ "Turbo", 3, 4 },
	{ "Comet", 4, 15 },
	{ "Hyperspace", 5, 55 },
}
-- Hors ligne (décision de Cantin, 25/11) : une absence complète ne doit pas payer plus que le niveau suivant du tapis.
-- AbsenceHours : absence complète comptée (4 h, 5 h avec les 2 × 30 min de l'arbre). AbsenceCentile : le prix d'un
-- niveau vaut cette absence au revenu que le joueur moyen a, à ce rang, quand il revient et que ce niveau est le
-- suivant (0,65 : deux retours sur trois). Trouvé par itération : ESSAI=tapis RATIO=0.65 bash bt.sh.
V.AbsenceHours = 5
V.AbsenceCentile = 0.65

-- Tapis : passage du niveau affiché n au niveau n + 1 (24 achats, 25 niveaux). Découpage par zone et prix du premier niveau de
-- chaque zone gardés (décision de Cantin, 25/11 : « il faut braquer une nouvelle boutique pour acheter le tapis
-- suivant ») : { zone, minutes du revenu de référence }. Niveaux 19 à 25 : { "abs", prix, revenu } = au moins une absence
-- complète du joueur moyen à ce revenu (la règle du hors ligne, là où elle ne contredit pas le découpage).
V.TreadmillCosts = {
	{ 1, 0.5 }, { 1, 1.5 }, -- niveaux 2 et 3 (zone 1)
	{ 2, 0.33 }, { 2, 0.67 }, { 2, 1.2 }, { 2, 2.2 }, { 2, 4.5 }, -- 4 à 8 (zone 2)
	{ 3, 2.5 }, { 3, 5 }, { 3, 9 }, { 3, 16 }, -- 9 à 12 (zone 3)
	{ 4, 4.5 }, { 4, 9.5 }, { 4, 20 }, { 4, 42 }, -- 13 à 16 (zone 4)
	{ 5, 4.5 }, { 5, 14 }, { "abs", 340e9, 19e6 }, { "abs", 690e9, 38e6 }, -- 17 à 20 (zone 5)
	{ "abs", 1.1e12, 58e6 }, { "abs", 1.7e12, 64e6 }, { "abs", 2.6e12, 80e6 }, { "abs", 3.9e12, 100e6 }, { "abs", 5.9e12, 115e6 }, -- 21 à 25 (zone 5, question 10)
}
-- Présentoirs (Config/Upgrades.DisplaySlots et ShopGrowth.Floor2) : 5e à 8e, l'étage, puis ses 8 places.
V.StandCosts = {
	{ 1, 1.5 }, { 1, 4 }, { 2, 0.5 }, { 2, 1 }, -- 5e à 8e présentoir
	{ 3, 1.5 }, -- l'étage
	{ 3, 2.5 }, { 3, 4 }, { 4, 4 }, { 4, 9 }, { 4, 18 }, { 5, 1 }, { 5, 2.5 }, { 5, 8.5 }, -- ses 8 places
}

return V
