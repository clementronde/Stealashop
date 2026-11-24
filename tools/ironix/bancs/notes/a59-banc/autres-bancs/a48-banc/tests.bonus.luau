--!nocheck
-- Scénario « bonus » (DEV-102) : le revenu compté hors ligne = objets exposés × bonus permanents (Premium
-- +10 %, index +5 % par zone complète, gamepass ×2 Argent), sans le boost ×2 argent (temporaire, compté
-- seulement en jeu : Partie 2, section 4). Relevé en jeu, sauvegardé au départ, payé au retour.

advance(1000)
startServer()

section("boost seul : exclu")
local p = newProfile(6)
addItem(p, "a", "Z1_Donut", 1, 1, 500)
addItem(p, "b", "Z1_Banane", 2, 1, 500)
p.Boosts.Cash = 3600
local ada = join("Ada", p)
advance(Offline.SnapshotInterval + 1)
local exposed = ada:GetAttribute("ExposedIncome")
check(exposed and near(exposed, incomeOf("Z1_Donut") + incomeOf("Z1_Banane")), `exposé : {exposed} $/s`)
check(near(ada:GetAttribute("Income"), exposed * 2), "en jeu : boost ×2 argent compté (Income = exposé × 2)")
check(MonetizationService.GetTemporaryIncomeMultiplier(ada) == Monetization.CashBoost.Multiplier, "MonetizationService : part temporaire = ×2 (boost en cours)")
check(near(OfflineService.GetIncome(ada), exposed) and near(dataOf(ada).Offline.Income, exposed), "hors ligne : boost exclu (Offline.Income = exposé)")
leave(ada)

section("bonus permanents compris, boost exclu")
local q = newProfile(6)
local n = 0
for _, item in Index.ByZone[1] do
	q.Index[item.Id] = 500 -- zone 1 complète : +5 %
end
for _, id in { "Z1_Donut", "Z1_Banane", "Z1_Donut", "Z1_Banane" } do
	n += 1
	addItem(q, `i{n}`, id, n, 1, 500)
end
q.Boosts.Cash = 3600
local bea = join("Bea", q)
bea.MembershipType = Enum.MembershipType.Premium
Workspace:SetAttribute("MonetizationTest", "Bea DoubleCash")
flush()
advance(Offline.SnapshotInterval + 1)
local exposedB = bea:GetAttribute("ExposedIncome")
local permanent = exposedB * (1 + 0.1 + 0.05) * 2
check(near(bea:GetAttribute("Income"), permanent * 2), `en jeu : exposé × 1,15 × 2 (×2 Argent) × 2 (boost) = {permanent * 2} $/s ({bea:GetAttribute("Income")})`)
check(near(OfflineService.GetIncome(bea), permanent), `hors ligne : exposé × 1,15 × 2 = {permanent} $/s, sans le boost ({OfflineService.GetIncome(bea)})`)
check(near(dataOf(bea).Offline.Income, permanent), "relevé dans le profil (Offline.Income)")
local boostLeft = dataOf(bea).Boosts.Cash
leave(bea)
local saved = SAVED["Player_2"]
check(near(saved.Offline.Income, permanent) and saved.Offline.LastSeenAt == wallNow(), "sauvegardé au départ : revenu du dernier relevé, heure du départ")

section("retour : absence × revenu permanent")
alignSecond()
local leftAt = saved.Offline.LastSeenAt
away(1000)
local back = join("Bea", nil, 2)
local absence = wallNow() - leftAt
local credits = creditsOf(back)
check(#credits == 1 and near(credits[1].amount, absence * permanent), `{absence} s × {permanent} $/s = {absence * permanent} $ ({credits[1] and credits[1].amount})`)
check(near(dataOf(back).Boosts.Cash, boostLeft, 1), "le boost n'a pas coulé pendant l'absence (compté seulement en jeu)")
leave(back)

summary("scénario bonus")
