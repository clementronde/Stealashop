#!/usr/bin/env perl
# Analyse de tools/ironix/orphelins.sh (check-up a417, P4). Lit sur l'entrée la sortie de extraire.luau,
# puis cherche chaque nom dans le code de src/ (commentaires retirés). Recherche par mots : c'est un tri,
# pas une preuve ; chaque ligne sortie se vérifie à la main avant de retirer quoi que ce soit.
#   perl analyse.pl <racine du dépôt> [fichier des tags de la map] < extraction
use strict;
use warnings;
use File::Find;

my ($root, $carte) = @ARGV;
my $src = "$root/src";

# Code de chaque fichier, sans commentaires (approché : `--` hors d'une chaîne entre guillemets).
my %code;
find({ no_chdir => 1, wanted => sub {
	return unless /\.luau$/;
	open(my $fh, '<:raw', $_) or die "$_ : $!";
	local $/;
	my $t = <$fh>;
	close $fh;
	$t =~ s/\r//g;
	$t =~ s/--\[(=*)\[.*?\]\1\]//gs;
	my @lignes;
	for my $l (split /\n/, $t) {
		my ($avant, $q) = ('', 0);
		while ($l =~ /\G(.*?)(--|"|`)/gc) {
			$avant .= $1;
			if ($2 eq '--' && !$q) { pos($l) = length($l); $l = $avant; last; }
			$q = !$q if $2 ne '--';
			$avant .= $2;
		}
		push @lignes, $l;
	}
	(my $rel = $File::Find::name) =~ s{^\Q$src\E/}{};
	$code{$rel} = join("\n", @lignes);
} }, $src);

my (@remotes, @features, @tags, %config, @erreurs);
while (my $l = <STDIN>) {
	$l =~ s/\r?\n$//;
	my @c = split /\t/, $l;
	next unless @c;
	if ($c[0] eq 'REMOTE') { push @remotes, [$c[1], $c[2]]; }
	elsif ($c[0] eq 'FEATURE') { push @features, $c[1]; }
	elsif ($c[0] eq 'TAG') { push @tags, $c[1]; }
	elsif ($c[0] eq 'CONFIG') { push @{ $config{$c[1]} }, $c[2]; }
	elsif ($c[0] eq 'ERREUR') { push @erreurs, $c[1]; }
}

my @fichiers = sort keys %code;
sub cherche { # cherche(regex, filtre de fichier) : fichiers dont le code contient la regex
	my ($re, $filtre) = @_;
	return grep { $filtre->($_) && $code{$_} =~ $re } @fichiers;
}
my $total = 0;
sub section {
	my ($titre, @lignes) = @_;
	$total += @lignes;
	printf "## %s : %d\n", $titre, scalar @lignes;
	print "- $_\n" for @lignes;
	print "\n";
}

print "# Orphelins de src/ (tools/ironix/orphelins.sh)\n\n";
print "Recherche par mots dans le code sans commentaires : un tri à vérifier à la main, pas une preuve.\n\n";
print "- extraction : $_\n" for @erreurs;
print "\n" if @erreurs;

# 1. Remotes : émetteur et écouteur (Net.Client.<Nom> côté client, Net.Server.<Nom> côté serveur).
my $hors_def = sub { $_[0] ne 'shared/Net/Definitions.luau' };
my (@sans_emetteur, @sans_ecouteur);
for my $r (@remotes) {
	my ($nom, $sens) = @$r;
	# Net.Client.X / client.X (alias local) / quelque chose.X:Fire, :FireAll ou :Connect, du bon côté.
	my $re = qr/\b(?:[Cc]lient|[Ss]erver)\.\Q$nom\E\b|\.\Q$nom\E\s*:\s*(?:Fire|FireAll|Connect)\b/;
	my @client = cherche($re, sub { $_[0] =~ m{^client/} });
	my @serveur = cherche($re, sub { $_[0] =~ m{^server/} });
	my @texte = cherche(qr/"\Q$nom\E"/, $hors_def);
	my $indirect = @texte ? " (nom écrit en texte dans : " . join(', ', @texte) . ")" : '';
	my ($emet, $ecoute) = $sens eq 'ClientToServer' ? (\@client, \@serveur) : (\@serveur, \@client);
	push @sans_emetteur, "$nom ($sens)$indirect" unless @$emet;
	push @sans_ecouteur, "$nom ($sens)$indirect" unless @$ecoute;
}
section("Remotes sans émetteur", @sans_emetteur);
section("Remotes sans écouteur", @sans_ecouteur);

# 2. Interrupteurs jamais lus (Features.<Nom>, ou "<Nom>" en texte), hors de Config/Features.
my @morts = grep {
	my $f = $_;
	!cherche(qr/\bFeatures(?:\s*::\s*any\s*\))?\.\Q$f\E\b|"\Q$f\E"/, sub { $_[0] ne 'shared/Config/Features.luau' });
} @features;
section("Interrupteurs jamais lus", @morts);

# 3. Clés de Config jamais lues : la clé n'apparaît dans aucun fichier (autre que le module) qui nomme le module.
my @cles;
for my $m (sort keys %config) {
	my @lecteurs = grep { $_ ne "shared/Config/$m.luau" && $code{$_} =~ /\b\Q$m\E\b/ } @fichiers;
	for my $k (sort @{ $config{$m} }) {
		my ($haut, $bas) = split /\./, $k, 2;
		my @avec = grep { $code{$_} =~ /\b\Q$haut\E\b/ } @lecteurs;
		@avec = grep { $code{$_} =~ /\b\Q$bas\E\b/ } @avec if defined $bas;
		push @cles, "$m.$k" unless @avec;
	}
}
section("Clés de Config jamais lues (hors de leur module)", @cles);

# 4. Tags : noms lus ou posés par le code (constantes *TAG* / *Tag* = "X", appels de CollectionService avec un texte).
my (%lus, %poses);
for my $f (@fichiers) {
	my $c = $code{$f};
	my %const;
	while ($c =~ /\b([A-Za-z_]*(?:TAG|Tag)[A-Za-z_0-9]*)\s*=\s*"([A-Za-z_][A-Za-z_0-9]*)"/g) {
		$const{$1} = $2;
		$lus{$2}{$f} = 1;
	}
	while ($c =~ /\b(GetTagged|HasTag|AddTag|RemoveTag|GetInstanceAddedSignal|GetInstanceRemovedSignal)\(\s*(?:[^,()]*,\s*)?("([A-Za-z_][A-Za-z_0-9]*)"|[A-Za-z_][A-Za-z_0-9.]*)\s*\)/g) {
		my ($appel, $arg, $lit) = ($1, $2, $3);
		my $nom = defined $lit ? $lit : $const{ (split /\./, $arg)[-1] };
		next unless defined $nom;
		$lus{$nom}{$f} = 1;
		$poses{$nom} = 1 if $appel eq 'AddTag';
	}
}
my %contrat = map { $_ => 1 } @tags;
my (@carte_code, @code_seul);
for my $t (sort keys %lus) {
	next if $contrat{$t};
	my $ou = join(', ', sort keys %{ $lus{$t} });
	if ($poses{$t}) { push @code_seul, "$t ($ou)"; } else { push @carte_code, "$t ($ou)"; }
}
section("Tags lus par le code, jamais posés par lui, absents de Contract/Tags (donc attendus dans la map)", @carte_code);
print "Pour info, tags posés par le code lui-même (hors contrat, normal) : ", join(', ', map { (split / /)[0] } @code_seul), "\n\n";

if (defined $carte && length $carte) {
	open(my $fh, '<', $carte) or die "$carte : $!";
	my @carte = grep { length } map { s/\s+//gr } <$fh>;
	close $fh;
	my %vus;
	section("Tags de la map ($carte) absents de Contract/Tags",
		grep { !$contrat{$_} && !$vus{$_}++ } @carte);
}

printf "Total : %d ligne(s) à regarder.\n", $total;
