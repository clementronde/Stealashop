--!nocheck
-- Banc a286, partie « récompenses et Config » (harnais d'a266/a268) : récompense du jour refusée tant que le tuto
-- n'est pas fini (L-224 point 3, Rewards.DailyAfterTutorial), « LOCKED » et pas de pastille côté client, puis
-- donnée une fois le tuto fini ; profil sans tuto : pas bloqué. Valeurs de Config d'a286 : Fortune Tower pour 6,
-- survol des croix et des cartes (L-224 point 2), prime au complice (L-216 point 10), pièges (L-268).
local Rewards = sharedModule("Config/Rewards")
advance(1000)
startServer()
questTest("days 10")

section("tuto pas fini : jour bloqué")
local data = newProfile8()
data.Tutorial = { Step = 2, Done = false }
local ada = join("Ada", data, 91)
advance(1.5)
buildUi(ada)
startClient(ada)
advance(0.5)
click(UI.button) -- écran ouvert : paintDaily
advance(1.2)
check(Rewards.DailyAfterTutorial == true, "Rewards.DailyAfterTutorial allumé")
check(ada:GetAttribute("RewardDailyLocked") == true, "attribut RewardDailyLocked = true")
check(RewardService.GetState(ada).DailyLocked == true, "GetState : DailyLocked")
local cash = dataOf(ada).Cash
claimDaily(ada)
advance(0.2)
check(dataOf(ada).Cash == cash and dataOf(ada).Rewards.Daily.Streak == 0, "ClaimDaily refusé : rien versé, série inchangée")
check(#notifies(ada, "Finish the tutorial") == 1, "Notify TutorialFirst")
check(UI.claimLabel.Text == "LOCKED", `client : « LOCKED » ({UI.claimLabel.Text})`)
check(not UI.alert.Visible, "client : pas de pastille pour un jour bloqué")

section("tuto fini : jour donné")
dataOf(ada).Tutorial.Done = true
advance(1.2) -- publié à chaque seconde (Rewards.Tick)
check(ada:GetAttribute("RewardDailyLocked") == nil, "attribut retiré dans la seconde")
check(UI.claimLabel.Text ~= "LOCKED", `client : plus « LOCKED » ({UI.claimLabel.Text})`)
claimDaily(ada)
advance(0.2)
check(dataOf(ada).Cash > cash and dataOf(ada).Rewards.Daily.Streak == 1, `jour 1 donné ({dataOf(ada).Cash - cash} $)`)

section("tuto fini (Done = true, ancien joueur compris : TutorialService le marque au chargement) : pas bloqué")
local cy = join("Cy", newProfile8(), 92)
advance(1.5)
check(cy:GetAttribute("RewardDailyLocked") == nil, "pas d'attribut RewardDailyLocked")
local cyCash = dataOf(cy).Cash
claimDaily(cy)
advance(0.2)
check(dataOf(cy).Cash > cyCash, "jour 1 donné")

section("Config a286")
local FortuneTower = sharedModule("Config/FortuneTower")
local Zones = sharedModule("Config/Zones")
check(FortuneTower.LootCount == 6 and FortuneTower.V0Width == 18, `Fortune Tower : 6 caisses, vitre de 18 ({FortuneTower.LootCount}, {FortuneTower.V0Width})`)
check(FortuneTower.MaxHP == 3 * Zones[6].AdvisedDamage * 5 * 90 and FortuneTower.MaxHP == 2700000000, `Fortune Tower : 3 casseurs, 2.7B ({FortuneTower.MaxHP})`)
local UiMotion = sharedModule("Config/UiMotion")
check(UiMotion.Hover.CloseTo == 1.07 and UiMotion.Hover.CardTo == 1.03 and UiMotion.Hover.SizedTime == 0.133, "survol : croix 1,07, carte 1,03, 133 ms")
check(table.find(UiMotion.Hover.CloseNames, "CloseButton") ~= nil, "survol : CloseButton est une croix")
local Features = sharedModule("Config/Features")
check(Features.NewTraps == false and Features.HeistPartnerBonus == false, "NewTraps et HeistPartnerBonus coupés")
local Balance = sharedModule("Config/Balance")
check(Balance.Heist.PartnerBonusSeconds == 60 and string.find(Balance.Heist.PartnerBonusMessage, "%s", 1, true) ~= nil, "prime au complice : 60 s de revenu, message avec %s")
local Traps = sharedModule("Config/Traps")
check(#Traps.SlotLayoutNew == 4 and Traps.ById.BananaPeel ~= nil and Traps.ById.TrapDoor ~= nil, "pièges : BananaPeel, TrapDoor et SlotLayoutNew")
local Anims = sharedModule("Contract/Animations")
local found = nil
for _, a in Anims.Player do
	if a.Name == "TrapSlip" then found = a end
end
check(found ~= nil and found.Loop == false and found.Priority == "Action", "TrapSlip au contrat des animations du joueur (Action, sans boucle)")
summary("scénario a286 récompenses")
