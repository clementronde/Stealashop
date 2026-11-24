#!/usr/bin/perl
# a262 (vague 76, corrections de Cantin du 20/11) : remet un fichier de Config comme avant ces corrections, d'après les
# commentaires « V0 proposé (Cantin, 20/11), avant : X » (prix, argent, ShelfStepUp, chances des colis) ; retire les
# listes Costs de Config/Upgrades (retour à BaseCost × Growth^n) et remet le texte du pack de départ ($50K).
#   perl avant-cantin.pl <fichier>   (réécrit le fichier, CRLF gardé)
use strict; use warnings;
my $f = shift;
open my $h, '<:raw', $f or die "$f\n"; local $/; my $t = <$h>; close $h;
my $crlf = ($t =~ /\r\n/);
$t =~ s/\r\n/\n/g;
my $V = qr/ -- V0 proposé \(Cantin, 20\/11\), avant : /;
my %R = (C => "Common", U => "Uncommon", R => "Rare", E => "Epic", L => "Legendary", M => "Mythic", S => "Secret");
my @out;
for my $line (split /\n/, $t, -1) {
	if ($line =~ /^\t\tCosts = \{[^\n]*\},$/) { next; }
	if ($line =~ /^(.*?)$V(.*)$/) {
		my ($code, $old) = ($1, $2);
		if ($code =~ /^(\s*\[\d\] = )\{/) {
			my $head = $1; my @p;
			for my $pair (split /, (?=[A-Z] )/, $old) {
				my ($k, $v) = $pair =~ /^([A-Z]) ([\d,]+)/ or die "chances : $line\n";
				$v =~ s/,/./; push @p, "$R{$k} = $v";
			}
			$line = $head . "{ " . join(", ", @p) . " },";
		} elsif ($code =~ /Prices = \{/) {
			my ($list) = $old =~ /^(\{[^}]*\})/ or die "prices : $line\n";
			($line = $code) =~ s/Prices = \{[^}]*\}/Prices = $list/;
		} elsif ($code =~ /(Price|Cash|ShelfStepUp) = [\d_.e]+,/) {
			my $key = $1; my ($v) = $old =~ /^([\d_.e]+)/ or die "valeur : $line\n";
			($line = $code) =~ s/$key = [\d_.e]+,/$key = $v,/;
		} else {
			die "ligne inconnue : $line\n";
		}
	}
	push @out, $line;
}
$t = join("\n", @out);
$t =~ s/Effect = "×2 Cash 1h \+ Hammer \+ \$2\.6K"/Effect = "×2 Cash 1h + Hammer + \$50K"/;
$t =~ s/\n/\r\n/g if $crlf;
open $h, '>:raw', "$f.tmp" or die; print $h $t; close $h; rename "$f.tmp", $f or die;
