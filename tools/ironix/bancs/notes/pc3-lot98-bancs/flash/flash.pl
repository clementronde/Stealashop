#!/usr/bin/perl
# lot98 (petit chef 3) : dans le fichier .luau lancé par un banc, Config/CashFlash coupé (Enabled = false) dans son bloc
# SOURCES["shared/Config/CashFlash.luau"]. Pour les bancs de l'ancien rythme de l'encaissement d'une plaque (a60, a62…),
# comme a401-banc/a401-coupe.sh pour a401 ; le nouveau rythme (L-299) est vérifié par le banc a317. Sans bloc : rien.
# Usage : perl flash.pl <fichier .luau>
use strict;
use warnings;
my ($f) = @ARGV;
open(my $fh, '<', $f) or die "lecture $f : $!";
my @lines = <$fh>;
close $fh;
my ($in, $done) = (0, 0);
for my $line (@lines) {
	if ($line =~ /^SOURCES\["([^"]+)"\] = /) {
		$in = $1 eq 'shared/Config/CashFlash.luau';
		next;
	}
	if ($in && !$done && $line =~ s/^(\tEnabled = )true,/${1}false, -- lot98 : coupé pour ce banc (flash.pl)/) {
		$done = 1;
	}
}
exit 0 unless $done;
open(my $oh, '>', $f) or die;
print $oh @lines;
close $oh;
