# a412 (vague GC7, 23/11, textes du jeu) : les textes vus par le joueur ont changé (street, display, MAX LEVEL, codes,
# raccourcis, caisse « an Epic »…). Les scénarios des bancs attendent encore les anciens textes. Ce correctif du fichier
# assemblé (posé par le faux luau.exe du lanceur d'a412, comme etape.pl d'a265) remplace chaque ancien texte attendu par
# le nouveau, mot pour mot ; les sources du jeu (déjà à jour) ne contiennent plus aucun de ces textes. Arbre sans a412
# (message de la caisse d'avant) : fichier inchangé.
#   perl textes.pl <fichier assemblé>
use strict;
my ($target) = @ARGV;
local $/;
open(my $in, '<', $target) or die "a412 textes.pl : $target illisible\n";
my $t = <$in>;
close $in;
exit 0 if index($t, "--a412-textes") >= 0;
# Sources d'a412 dans le fichier ? (un des nouveaux textes) ; sinon, sources d'avant (copie d'un ancien arbre) : rien.
my @markers = (
	'CrateItem = "Exclusive Crate: you got %s %s %s!"', 'Cooldown = "Ready in %d:%02d"', 'Taken = "This display is already taken."',
	'SignMax = "MAX LEVEL"', 'AlreadyUsed = "Code already used."', 'ToReserve = "%s removed from its display: moved to your inventory"',
	'DriverCaught = "Caught by a truck driver! You lost the loot."', 'Closed = "The street is closed at night."',
	'local TOOL_STAT = "Strength %s"', 'local NODE_LEVEL_TEXT = "Lv %d/%d"', 'StandsMax = "All your displays are unlocked."',
	'Queued = "%s gave the server %s LUCK for %s! Starts after the current one."', 'ZoneComplete = "Zone %d complete! Claim %s in the Index!"',
	'Returned = "Your %s is back on its display!"', 'AntiTheft = "Put it down in your shop first: display it once UNLOCKED!"',
	'local BOX_RARITY_ATTRIBUTE = "BoxRarity"', 'Label = "×2 CASH 10 MIN"', 'damage.Text = AdvicePanel.strengthText(zone)',
);
exit 0 unless grep { index($t, $_) >= 0 } @markers;
my $before = $t;
my @pairs = (
	# présentoirs : display
	['This stand is already taken.', 'This display is already taken.'],
	['This stand is locked', 'This display is locked'],
	["This stand doesn't exist.", "This display doesn't exist."],
	['back on its stand!', 'back on its display!'],
	['"Unlock stand"', '"Unlock display"'],
	['== "Stands ', '== "Displays '],
	['moved to your reserve', 'moved to your inventory'],
	# niveaux
	['"Max level"', '"MAX LEVEL"'],
	# raccourcis
	['"Put this item down in your shop first"', '"Put it down in your shop first"'],
	['"its anti-theft starts there"', '"Put it down in your shop to secure it"'],
	# codes
	['m == "Already used"', 'm == "Code already used."'],
	['m == "Invalid code"', 'm == "Invalid code."'],
	# caisse exclusive (a297) : article a / an et rareté en DisplayName
	['return `{PREFIX} {Rarities.ById[def.Rarity].DisplayNameUpper} {def.DisplayName}!`',
		'return `Exclusive Crate: you got {if string.find(Rarities.ById[def.Rarity].DisplayName, "^[AEIOU]") then "an" else "a"} {Rarities.ById[def.Rarity].DisplayName} {def.DisplayName}!`'],
	['`Exclusive Crate: you got a {Rarities.ById[def.Rarity].DisplayNameUpper} {def.DisplayName}!`',
		'`Exclusive Crate: you got {if string.find(Rarities.ById[def.Rarity].DisplayName, "^[AEIOU]") then "an" else "a"} {Rarities.ById[def.Rarity].DisplayName} {def.DisplayName}!`'], # a285
	# roue : libellé attendu du secteur ×2 (a309)
	['"x2 CASH 10 MIN"', '"×2 CASH 10 MIN"'],
	# améliorations des présentoirs (a19)
	['New stand unlocked! (', 'New display unlocked! ('],
	['"All your stands are unlocked."', '"All your displays are unlocked."'],
	# carte d'outil de l'inventaire : Strength (a61)
	['"Power " .. Format.short(', '"Strength " .. Format.short('],
	# camion (a54, a57)
	['Caught by a truck driver! The box is lost.', 'Caught by a truck driver! You lost the loot.'],
	['The truck drivers are after your box! Run to the safe zone!', 'The truck drivers are after you! Run to the safe zone!'],
	# colis au sol sans rareté connue : « Box » (a123, Fortune Tower)
	['prompt.ObjectText == "Luxury Box"', 'prompt.ObjectText == "Box"'],
	# bandeau de zone : « Strength 1 » comme les panneaux (L-108, L-110 ; a101)
	['Advice.Damage.Text == "Damage ', 'Advice.Damage.Text == "Strength '],
	['damage == "Damage " .. Format.short', 'damage == "Strength " .. Format.short'],
);
for my $p (@pairs) {
	my ($from, $to) = @$p;
	my $i = 0;
	while (($i = index($t, $from, $i)) >= 0) {
		substr($t, $i, length($from)) = $to;
		$i += length($to);
	}
}
# formes à chiffres : panneau d'amélioration « Lv 1 → 2 », index « Zone 1 complete! », nuit « the street »
$t =~ s/"Level (\d+) > Level (\d+)"/"Lv $1 → $2"/g;
$t =~ s/Index: Zone (\d+) complete! Claim /Zone $1 complete! Claim /g;
$t =~ s/the corridor is (open|closed)/the street is $1/g;
$t =~ s/The corridor is closed at night\./The street is closed at night./g;
$t =~ s/"Level (\d+) \/ (\d+)"/"Lv $1\/$2"/g; # arbre : InfoPanel.NodeLevel (a85)
$t =~ s/gave the whole server (×\d+) LUCK for (\d+ min)! It starts after the current ×\d+\./gave the server $1 LUCK for $2! Starts after the current one./g; # a247
if ($ENV{A412_DUMP}) { # débogage : copie du fichier corrigé (A412_DUMP=<dossier>)
	my $n = 0;
	$n++ while -e "$ENV{A412_DUMP}/f$n.luau";
	if (open(my $d, '>', "$ENV{A412_DUMP}/f$n.luau")) { print $d $t; close $d; }
}
exit 0 if $t eq $before;
$t .= "\n--a412-textes\n";
open(my $out, '>', $target) or die "a412 textes.pl : $target non écrit\n";
print $out $t;
close $out;
