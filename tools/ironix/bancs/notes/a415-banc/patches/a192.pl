# a415 : banc a192, scénario client, cas M2 et M3. Depuis le retrait du lâcher volontaire, HeistFeel.ChaseMask.KeepHud
# ne garde plus que HeistTimer : DropButton n'est plus gardé, et son cadre BottomRow est caché en entier, comme le
# reste du HUD (OtherButton, dedans, n'est plus caché un par un). Fichier sans la section M (scénario server) : rien
# à faire. Cas attendus mais introuvables : échec (banc changé depuis).
use strict;
use warnings;
my $file = shift;
open(my $in, '<:raw', $file) or die "lecture $file : $!";
my $text = do { local $/; <$in> };
close($in);
exit 0 unless $text =~ /section\("M\. HUD masqué pendant la poursuite"\)/;
my @pairs = (
	[
		'check(rail.Visible == false and cashLabel.Visible == false and other.Visible == false, "M2 LeftRail, Cash et le reste du HUD cachés")',
		'check(rail.Visible == false and cashLabel.Visible == false and bottom.Visible == false, "M2 LeftRail, Cash et le reste du HUD cachés (BottomRow entier, a415)")',
	],
	[
		'check(timer.Visible == true and drop.Visible == true and bottom.Visible == true, "M3 HeistTimer, DropButton (et son cadre) gardés")',
		'check(timer.Visible == true, "M3 HeistTimer gardé (a415 : DropButton ne l\'est plus)")',
	],
);
for my $pair (@pairs) {
	my ($old, $new) = @$pair;
	my $at = index($text, $old);
	if ($at < 0) { print STDERR "a415 : cas introuvable dans $file : $old\n"; exit 1; }
	substr($text, $at, length($old)) = $new;
}
open(my $out, '>:raw', $file) or die "écriture $file : $!";
print $out $text;
close($out);
exit 0;
