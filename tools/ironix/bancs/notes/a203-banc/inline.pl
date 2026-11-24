# a203 (vague 62) : remplace, dans le fichier assemblé d'un banc d'avant le poids, chaque require de Shared/ItemWeight
# et de Config/Weight par leurs vraies sources en ligne (expressions construites par corrige.sh, poids coupé).
#   perl inline.pl <itemweight.expr> <weight.expr> <fichier assemblé>
use strict;
my ($iwFile, $wFile, $target) = @ARGV;
local $/;
open(my $a, '<', $iwFile) or die; my $iw = <$a>; close $a;
open(my $b, '<', $wFile) or die; my $w = <$b>; close $b;
open(my $c, '<', $target) or die; my $text = <$c>; close $c;
exit 0 if index($text, "--a203-poids-en-ligne") >= 0;
$text =~ s/require\([A-Za-z_.]*ItemWeight\)/$iw/g;
$text =~ s/require\([A-Za-z_.]*:WaitForChild\("ItemWeight"\)\)/$iw/g;
$text =~ s/require\([A-Za-z_.]*Config\.Weight\)/$w/g;
$text =~ s/require\(script\.Parent\.Weight\)/$w/g;
$text =~ s/require\([A-Za-z_.]*:WaitForChild\("Weight"\)\)/$w/g;
open(my $d, '>', $target) or die; print $d $text; close $d;
