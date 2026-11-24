# a274 (vague GC2, audit a272 H1) : la fin d'achat d'un gamepass (PromptGamePassPurchaseFinished) ne donne plus rien
# toute seule : le serveur demande d'abord à Roblox (UserOwnsGamePassAsync, nouvel essai en cas d'erreur).
# Le scénario « passes » du banc a38 attendait l'ancien don immédiat sur le seul signal : ses sections « fin d'achat »
# et « acheté pendant la session » sont remplacées par les cas de la nouvelle règle (H1a à H1h).
# Appliqué par perl -0777 -i sur le fichier assemblé ; sans effet sur les autres scénarios (motif absent).
local $/;
my $s = <>;
my $new = <<'LUAU';
section("fin d'achat d'un gamepass (a274, H1 : confirmée par Roblox)")
clearRemotes = function()
	table.clear(REMOTE_LOG)
end
clearRemotes()
finishPassPurchase(bob, PASS_IDS.DoubleTraining, false)
advance(2)
check(bob:GetAttribute("PassDoubleTraining") == nil and #notifies(bob) == 0, "H1a fenêtre fermée sans achat : rien")
finishPassPurchase(bob, 123456, true)
advance(2)
check(#notifies(bob) == 0, "H1b gamepass inconnu : rien")
local before274 = #MARKET.ownsCalls
finishPassPurchase(bob, PASS_IDS.DoubleTraining, true) -- signal seul : Bob ne le possède pas chez Roblox
advance(2)
check(#MARKET.ownsCalls > before274, "H1c signal d'achat : Roblox est interrogé")
check(bob:GetAttribute("PassDoubleTraining") == nil and not MonetizationService.HasPass(bob, "DoubleTraining") and #notifies(bob) == 0, "H1c signal sans possession chez Roblox : rien donné")
check(dataOf(bob).Monetization.Passes == nil or dataOf(bob).Monetization.Passes.DoubleTraining == nil, "H1d rien écrit dans le cache du profil")
MARKET.owns[bob.UserId] = MARKET.owns[bob.UserId] or {}
MARKET.owns[bob.UserId][PASS_IDS.DoubleTraining] = true
MARKET.ownsFails[PASS_IDS.DoubleTraining] = 1 -- 1re réponse en erreur : nouvel essai
finishPassPurchase(bob, PASS_IDS.DoubleTraining, true)
check(bob:GetAttribute("PassDoubleTraining") == nil, "H1e pas donné avant la réponse de Roblox")
advance(4)
check(bob:GetAttribute("PassDoubleTraining") == true and MonetizationService.HasPass(bob, "DoubleTraining"), "H1e acheté et confirmé (après une erreur) : possédé")
check(#notifies(bob, "×2 Training unlocked!") == 1, "H1f Notify « ×2 Training unlocked! »")
check(dataOf(bob).Monetization.Passes.DoubleTraining == true, "H1f gardé dans le cache du profil")
finishPassPurchase(bob, PASS_IDS.DoubleTraining, true)
advance(2)
check(#notifies(bob, "unlocked") == 1, "H1g 2e fin d'achat du même gamepass : pas de 2e message")

section("Roblox ne répond jamais après un achat : rien donné (a274)")
MARKET.ownsFails[PASS_IDS.FastOpen] = 99
finishPassPurchase(bob, PASS_IDS.FastOpen, true)
advance(15)
check(bob:GetAttribute("PassFastOpen") == nil and not MonetizationService.HasPass(bob, "FastOpen"), "H1h toujours en erreur : pas donné")
MARKET.ownsFails[PASS_IDS.FastOpen] = 0

section("acheté pendant la session : une réponse plus ancienne ne le retire pas")
MARKET.ownsDelay = 2
local eve = join("Eve", newProfile())
advance(0.5)
MARKET.owns[eve.UserId] = { [PASS_IDS.DoubleCash] = true }
finishPassPurchase(eve, PASS_IDS.DoubleCash, true)
advance(15)
check(eve:GetAttribute("PassDoubleCash") == true and MonetizationService.HasPass(eve, "DoubleCash"), "toujours possédé après la réponse d'arrivée")
MARKET.ownsDelay = 0.1

LUAU
my $n = ($s =~ s/section\("fin d'achat d'un gamepass"\).*?(?=section\("départ et retour"\))/$new/s);
warn "a274 : section fin d achat introuvable
" if $n == 0 && $s =~ /scénario passes/;
print $s;
