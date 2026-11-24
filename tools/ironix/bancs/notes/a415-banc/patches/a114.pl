# a415 : bancs dont un cas lâchait l'objet avec CarryService.Drop(joueur, nil, "Released") (l'appel de DropService,
# touche G). Ce lâcher n'existe plus et Drop a retrouvé sa forme (joueur, position) : le cas fait tomber l'objet
# comme un coup de batte (BatService), au point du sol sous le joueur (HumanoidRootPart moins 3 studs, comme le cas
# D2 du banc a127), et attend la raison « Bat » au lieu de « Released ». Fichier sans ce lâcher : rien à faire.
use strict;
use warnings;
my $file = shift;
open(my $in, '<:raw', $file) or die "lecture $file : $!";
my $text = do { local $/; <$in> };
close($in);
my $n = ($text =~ s/Carry\.Drop\((\w+), nil, "Released"\)/Carry.Drop($1, $1.Character:FindFirstChild("HumanoidRootPart").Position - Vector3.new(0, 3, 0))/g);
exit 0 unless $n;
$text =~ s/\.reason == "Released"/.reason == "Bat"/g;
$text =~ s/« Failed » \(Released\)/« Failed » (Bat)/g;
$text =~ s/"lâché \(G\) : Dropped, Released"/"tombé (batte) : Dropped, Bat"/g;
die "a415 : un \"Released\" reste dans $file\n" if $text =~ /"Released"/;
open(my $out, '>:raw', $file) or die "écriture $file : $!";
print $out $text;
close($out);
exit 0;
