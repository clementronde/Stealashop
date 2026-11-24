# a262 (vague 76) : corrige le fichier assemblé d'un banc d'avant la vague 76 (voir corrige.sh).
#   perl patch.pl <patches/<nom>.pl, lu s'il existe> <fichier assemblé>
# Le fichier de patch reçoit le texte dans $t et la fonction rep(motif, remplacement, nom[, toutes]) : un motif qui
# ne trouve rien arrête le banc (le patch ne s'applique plus : à revoir).
use strict;
our $t;
my ($patch, $target) = @ARGV;
local $/;
open(my $in, '<', $target) or die "a262 patch.pl : $target illisible\n"; $t = <$in>; close $in;
exit 0 if index($t, "--a262-compat") >= 0;
sub rep {
	my ($p, $to, $label, $all) = @_;
	my $c = $all ? ($t =~ s/$p/$to/gs) : ($t =~ s/$p/$to/s);
	die "a262 patch.pl : motif « $label » introuvable dans $target\n" unless $c;
	return $c;
}
# Remplacement littéral (pas de motif) : la première occurrence, ou toutes avec $all ; introuvable : arrêt.
sub lit {
	my ($from, $to, $label, $all) = @_;
	my $n = 0;
	my $at = 0;
	while ((my $i = index($t, $from, $at)) >= 0) {
		substr($t, $i, length($from)) = $to;
		$at = $i + length($to);
		$n++;
		last unless $all;
	}
	die "a262 patch.pl : texte « $label » introuvable dans $target\n" unless $n;
	return $n;
}
# Le fichier assemblé contient-il ce texte ? (un banc lance souvent plusieurs fichiers : chaque patch ne vise que le sien)
sub has { return index($t, $_[0]) >= 0; }
# Applique aussi patches/<nom>.pl (patch partagé entre copies d'un même banc).
sub inc {
	my $file = $patch;
	$file =~ s/[^\/\\]+\.pl$/$_[0].pl/;
	my $code = do { open(my $p, '<', $file) or die "a262 patch.pl : $file illisible\n"; local $/; <$p> };
	eval $code; die "a262 patch.pl : $file : $@" if $@;
}
# Lectures de l'attribut Tier par le banc (aucune dans src depuis la vague 76).
$t =~ s/((?:[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*|\[[^\[\]]*\])*)(?:\([^()]*\))?):GetAttribute\("Tier"\)/A262_TIER($1)/g;
if (-f $patch) {
	my $code = do { open(my $p, '<', $patch) or die; local $/; <$p> };
	eval $code; die "a262 patch.pl : $patch : $@" if $@;
}
my $prelude = <<'LUAU';
--a262-compat
A262_TIER = function(m: any): string?
	if m == nil then
		return nil
	end
	local tier = m:GetAttribute("Tier")
	if tier ~= nil then
		return tier
	end
	local rarity = m:GetAttribute("BoxRarity")
	if rarity == nil then
		return nil
	elseif rarity == "Common" or rarity == "Uncommon" then
		return "Standard"
	elseif rarity == "Rare" or rarity == "Epic" then
		return "Premium"
	end
	return "Luxe"
end
LUAU
$t = $prelude . $t;
open(my $out, '>', $target) or die; print $out $t; close $out;
