# a319 (L-303) : SpeedBoostButton vend le gamepass DoubleSpeed (149 R$) ; plus de boost SpeedBoost dans Config/Boosts.
# Scénario « menu » du banc a190 : M1d (règle du tapis du boost) et M5 (« x2 » montré sur le tapis, 29, « Soon »)
# remplacés : au dépôt (boutique coupée, Id 0) le bouton reste caché, prix 149, clic sans effet. Sans effet ailleurs.
local $/;
my $s = <>;
$s =~ s/check\(Menu\.GetShown\(\)\.SpeedBoost == true, "M1d[^\n]*\n/check(Menu.GetShown().SpeedBoost == nil, "M1d a319 : plus de boost SpeedBoost (gamepass DoubleSpeed)")\n/;
my $m5 = <<'LUAU';
print("\n== M5. a319 : x2 SPEED = gamepass DoubleSpeed (boutique coupée, Id 0 : jamais montré) ; zZz inchangé")
local speed = el(hud, "SpeedBoostButton")
local sleep = el(hud, "SleepButton")
check(not speed.Visible and not sleep.Visible, "M5a les deux cachés au branchement (hub, hors tapis)")
check(el(speed, "Amount").Text == "149" and el(sleep, "Amount").Text == "79", `M5b prix du gamepass et de Config/Boosts ({el(speed, "Amount").Text}, {el(sleep, "Amount").Text})`)
P1:SetAttribute("TrainingMachine", "Treadmill")
step(0.2)
check(not speed.Visible and not sleep.Visible, "M5c sur le tapis : x2 SPEED reste caché (boutique coupée, Id 0)")
local before = #Notify.shown
click(speed)
local last = Notify.shown[#Notify.shown]
check(#Notify.shown == before, "M5d clic : rien (ni « Soon » ni achat)")
P1:SetAttribute("TrainingMachine", nil)
step(0.2)
check(not speed.Visible, "M5e descendu du tapis : caché")

LUAU
my $n = ($s =~ s/print\("\n== M5\. .*?(?=print\("\n== M6\.)/$m5/s);
warn "a319 : section M5 introuvable\n" if $n == 0 && $s =~ /scénario « menu »/;
print $s;
