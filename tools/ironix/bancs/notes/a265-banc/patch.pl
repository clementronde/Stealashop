# a265 (vague 79) : corrige le fichier assemblé d'un banc (voir corrige.sh ; copie de a264-banc/patch.pl).
#   perl patch.pl <patches/<nom>.pl> <fichier assemblé>
# Le patch reçoit le texte dans $t, has(texte) et lit(de, vers, nom) : un texte introuvable arrête le banc.
use strict;
our $t;
my ($patch, $target) = @ARGV;
local $/;
open(my $in, '<', $target) or die "a265 patch.pl : $target illisible\n"; $t = <$in>; close $in;
exit 0 if index($t, "--a265-compat") >= 0;
sub has { return index($t, $_[0]) >= 0; }
sub lit {
	my ($from, $to, $label) = @_;
	my $i = index($t, $from);
	die "a265 patch.pl : texte « $label » introuvable dans $target\n" if $i < 0;
	substr($t, $i, length($from)) = $to;
}
my $before = $t;
if (-f $patch) {
	my $code = do { open(my $p, '<', $patch) or die; local $/; <$p> };
	eval $code; die "a265 patch.pl : $patch : $@" if $@;
}
exit 0 if $t eq $before;
$t = "--a265-compat\n" . $t;
open(my $out, '>', $target) or die; print $out $t; close $out;
