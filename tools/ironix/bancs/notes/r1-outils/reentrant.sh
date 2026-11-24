#!/usr/bin/env bash
# r1 (2026-11-20, accord de Cantin) : rend les bancs réentrants. Transformation mécanique et idempotente (une 2e passe
# ne change rien) de tous les *.sh d'un dossier de bancs :
#  1. Banc : une ligne « OUT="$H/<fichier>" » (aussi $ME, $ME151, et out="$here/…") écrivait le fichier assemblé dans
#     le dossier partagé du banc ; deux lancements en même temps s'écrasaient. Elle devient, sur la même ligne (aucune
#     ligne décalée) : un dossier propre au processus, R1_D, créé une fois par script sous $R1_RUN (dossier du
#     lancement, hérité du lanceur, supprimé par lui à la fin), ou sous ${TMPDIR:-/tmp}/r1-bancs pour un banc lancé
#     seul (jeton.sh retire ceux de plus de 2 h) ; puis OUT="$R1_D/<fichier>", même nom de fichier.
#  2. Lanceur (fichier qui contient la ligne de lancement des bancs « ( timeout 600 bash "$script" … ) & ») :
#     OUTDIR exporté en R1_RUN, chaque banc passe par r1-outils/jeton.sh (au plus N bancs sur la machine, tous agents
#     confondus), JOBS vaut N par défaut au lieu de 4.
# Les fichiers modifiés sont réécrits dans un fichier neuf puis renommés, droits gardés. Corps des heredocs ignoré.
#   bash reentrant.sh [dossier des bancs]     (défaut : le dossier parent de r1-outils)
#   DRY=1 bash reentrant.sh …                 liste ce qui changerait, sans rien écrire
# Sortie : une ligne par fichier modifié (« banc (n) » = n lignes OUT, « lanceur (n) »), puis le total.
set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
[ -d "$ROOT" ] || { echo "r1 reentrant.sh : $ROOT introuvable" >&2; exit 2; }
read -r -d '' P <<'PERL'
use strict;
use warnings;
my @files = do { local $/ = "\0"; map { chomp; $_ } <STDIN> };
my $dry = ($ENV{DRY} // '') eq '1';
my ($nb_files, $nb_lines, $nb_launch) = (0, 0, 0);
my $RD = ': "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; ';
my $JOB = '( timeout 600 bash "$script" "$arg" > "$OUTDIR/$i.out" 2>&1 ) &';
my $JOB2 = '( bash "$H/r1-outils/jeton.sh" timeout 600 bash "$script" "$arg" > "$OUTDIR/$i.out" 2>&1 ) & # r1 : jeton de processeur';
for my $f (@files) {
	open(my $in, '<:raw', $f) or die "r1 : $f illisible\n";
	my @lines = <$in>;
	close $in;
	my $launcher = grep { index($_, $JOB) >= 0 } @lines;
	my ($n, $l, $heredoc) = (0, 0, undef);
	for my $line (@lines) {
		my ($body, $eol) = $line =~ /^(.*?)(\r?\n?)$/s;
		if (defined $heredoc) { $heredoc = undef if $body =~ /^\t*\Q$heredoc\E\s*$/; next; }
		if ($body =~ /^(\s*)(OUT|out)="\$\{?(H|ME|ME151|here)\}?\/([^"]*)"(.*)$/) {
			my ($ind, $var, $file, $rest) = ($1, $2, $4, $5);
			my $mk = '';
			if ($file =~ m{^(.*)/[^/]*$}) { $mk = "; mkdir -p \"\$R1_D/$1\""; }
			$body = "$ind$RD$var=\"\$R1_D/$file\"$mk$rest";
			$n++;
		} elsif ($launcher) {
			if (index($body, $JOB) >= 0) {
				$body =~ s/\Q$JOB\E/$JOB2/; $l++;
			} elsif ($body =~ /^OUTDIR="\$\(mktemp -d\)"\s*$/) {
				$body .= '; export R1_RUN="$OUTDIR" # r1 : dossier du lancement, hérité par les bancs'; $l++;
			} elsif ($body eq 'JOBS="${JOBS:-4}"') {
				$body = 'JOBS="${JOBS:-$(bash "$H/r1-outils/jeton.sh" --n)}" # r1 : autant de bancs que de jetons'; $l++;
			}
		}
		if ($body !~ /^\s*#/ && $body =~ /(?<!<)<<(?!<)-?\s*(['"]?)([A-Za-z_][A-Za-z_0-9]*)\1/) { $heredoc = $2; }
		$line = $body . $eol;
	}
	next unless $n || $l;
	$nb_files++; $nb_lines += $n; $nb_launch++ if $l;
	printf "%s %s%s\n", ($l ? "lanceur ($l)" : "banc ($n)"), $f, ($n && $l ? " + banc ($n)" : "");
	next if $dry;
	my $mode = (stat $f)[2] & 07777;
	open(my $out, '>:raw', "$f.r1-neuf") or die "r1 : $f.r1-neuf : $!\n";
	print $out @lines;
	close $out or die "r1 : $f.r1-neuf : $!\n";
	chmod $mode, "$f.r1-neuf";
	rename("$f.r1-neuf", $f) or die "r1 : $f : $!\n";
}
print "r1 : $nb_files fichier(s) modifié(s) : $nb_lines ligne(s) OUT de banc, $nb_launch lanceur(s)" . ($dry ? " (DRY, rien écrit)" : "") . "\n";
PERL
find "$ROOT" -name '*.sh' -type f -not -path '*/r1-outils/*' -print0 | sort -z | perl -e "$P"
