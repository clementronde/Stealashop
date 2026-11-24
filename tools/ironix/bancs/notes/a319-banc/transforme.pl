# a319 : transforme le fichier Luau assemblé par un banc existant (a38 côté serveur, a190 côté client) juste avant
# son exécution. Variables : A319_PART = server | client ; A319_V = variante (on, zero, off) ; A319_DIR = ce dossier.
#   server : scénario « passes » → pre.server.on.luau avant le setup d'a38, tests.server.on.luau à la place de ses
#            tests ; scénario « receipts » → tests.server.zero.luau (Id de DoubleSpeed laissé à 0) ; « prod » : rien
#            (sortie 1 ligne, 0 vérification).
#   client : scénario « menu » d'a190 → pre.client.<V>.luau juste après les sources, tests.client.luau à la place.
local $/;
my $f = shift;
open my $in, '<', $f or die "a319 : $f illisible";
my $s = <$in>;
close $in;
my $dir = $ENV{A319_DIR};
my $part = $ENV{A319_PART} // '';
my $v = $ENV{A319_V} // 'on';
sub slurp { my $p = "$dir/$_[0]"; open my $h, '<', $p or die "a319 : $p absent"; local $/; my $c = <$h>; close $h; $c =~ s/\r//g; return $c; }
my $ok = 0;
if ($part eq 'server') {
	if ($s =~ /summary\("scénario passes"\)/) {
		my $pre = slurp('pre.server.on.luau');
		$ok += ($s =~ s/(--!nocheck\n-- Mise en place commune des scénarios du banc a38)/$pre\n$1/);
		my $t = slurp('tests.server.on.luau');
		$ok += ($s =~ s/-- Scénario « passes ».*\z/$t/s);
		$ok = ($ok == 2);
	} elsif ($s =~ /summary\("scénario receipts"\)/) {
		my $t = slurp('tests.server.zero.luau');
		$ok = ($s =~ s/-- Scénario « receipts ».*\z/$t/s);
	} else {
		$s = "print(\"scénario pas lancé par a319 : 0 vérification(s), 0 échec(s)\")\n";
		$ok = 1;
	}
} elsif ($part eq 'client') {
	my $pre = slurp("pre.client.$v.luau");
	my $i = rindex($s, "]==========]\n");
	if ($i >= 0) {
		substr($s, $i + length("]==========]\n"), 0) = $pre . "\n";
		my $t = slurp('tests.client.luau');
		$ok = ($s =~ s/-{20,} scénario « menu ».*\z/$t/s);
	}
}
if (!$ok) { $s = "print(\"a319 : transformation impossible ($part $v) : 0 vérification(s), 1 échec(s)\")\nprint(\"scénario a319 : 0 vérification(s), 1 échec(s)\")\n"; }
open my $out, '>', $f or die;
print $out $s;
close $out;
