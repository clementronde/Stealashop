#!/usr/bin/perl
# Copie lot98 (petit chef 3) : dans l'arbre du banc a401 seulement, CollectFeel et CollectFeel.Text rallumés (coupés dans
# le jeu par le lot 98, L-299 étant fait par a317) et Config/CashFlash coupé : le banc vérifie a401 comme une option en
# veille, seule. Usage : perl -i rallume.pl <run.a401.luau>
use strict;
use warnings;
my ($feel, $flash, $in) = (0, 0, 0);
while (my $line = <>) {
	if ($line =~ /^SOURCES\["([^"]+)"\] = /) {
		$in = $1 eq 'shared/Config/CashFlash.luau';
	}
	$feel += ($line =~ s/Enabled = false, -- a401 : interrupteur \(false = comme avant\) ; lot98 : coupé/Enabled = true, -- a401 : interrupteur (false = comme avant) ; lot98 : coupé/);
	if ($in && $line =~ /^\tEnabled = true, -- V0/) {
		$line =~ s/Enabled = true/Enabled = false/;
		$flash++;
	}
	print $line;
}
if ($feel != 2 || $flash != 1) {
	print STDERR "rallume.pl : $feel interrupteur(s) a401, $flash CashFlash (attendu 2 et 1)\n";
}
