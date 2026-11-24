#!/usr/bin/env bash
# Copie des bancs hors Studio dans le dépôt (check-up a417, M3), PAS ENCORE FAITE : la copie dépasse les 20 Mo
# permis (voir le rapport de l'agent a435, lot101). Ce script dit ce qu'il faudrait copier, et le copie sur demande.
#   bash tools/ironix/bancs/copier.sh                   à blanc : taille et nombre de fichiers, par sorte
#   LANCEUR=run-all-bancs.lot101.sh bash tools/ironix/bancs/copier.sh   autre lanceur commun de départ
#   COPIER=1 bash tools/ironix/bancs/copier.sh          copie vraiment dans tools/ironix/bancs/notes/ (même arbre)
#   NOTES=/chemin bash tools/ironix/bancs/copier.sh     autre dossier des notes partagées
# Ce qui est gardé : les dossiers de premier niveau du dossier des notes que le lanceur cite, puis ceux que citent
# leurs scripts (.sh, .pl, .sed, .luau), jusqu'au point fixe ; dans ces dossiers, seulement les sources (.sh, .pl,
# .sed, .luau). Laissé dehors : fichiers assemblés run*.luau (990 Mo, refaits à chaque lancement), copies de src
# (dossiers arbres/), copies privées du lanceur (run-all-bancs*.sh dans un dossier de banc : les autres scripts ne
# les citent qu'en commentaire), sauvegardes *.avant*, sorties (.txt, .out, .errs, .norm), images et vidéos, notes .md.
# Il ne lance aucun banc et aucun luau.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
NOTES="${NOTES:-C:/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3}"
LANCEUR="${LANCEUR:-run-all-bancs.lot100.sh}"
[ -f "$NOTES/$LANCEUR" ] || { echo "lanceur introuvable : $NOTES/$LANCEUR" >&2; exit 2; }
LISTE="$(mktemp)"
trap 'rm -f "$LISTE"' EXIT
NOTES="$NOTES" LANCEUR="$LANCEUR" perl -MFile::Find -e '
	my ($N, $L) = @ENV{qw(NOTES LANCEUR)};
	opendir(my $d, $N) or die "$N : $!";
	my %top = map { $_ => 1 } grep { !/^\./ } readdir $d;
	closedir $d;
	sub garde {
		my $f = shift;
		return 0 unless $f =~ /\.(sh|pl|sed|luau)$/;
		return 0 if $f =~ m{/run[^/]*\.luau$} || $f =~ m{/arbres/} || $f =~ /\.avant/;
		return 0 if $f =~ m{^[^/]+/.*run-all-bancs[^/]*\.sh$};
		return 1;
	}
	my %vu = ($L => 1);
	my @file = ($L);
	my @garde;
	while (@file) {
		my $e = shift @file;
		my @f;
		if (-d "$N/$e") {
			find({ no_chdir => 1, wanted => sub { (my $r = $_) =~ s{^\Q$N\E/}{}; push @f, $r if -f $_ && garde($r) } }, "$N/$e");
		} elsif (-f "$N/$e") {
			@f = ($e);
		}
		for my $r (@f) {
			push @garde, $r;
			open(my $fh, "<:raw", "$N/$r") or next;
			local $/;
			my $t = <$fh>;
			close $fh;
			while ($t =~ /([A-Za-z0-9][A-Za-z0-9._-]*)/g) {
				next unless $top{$1} && !$vu{$1}++;
				push @file, $1;
			}
		}
	}
	print "$_\n" for sort @garde;
' > "$LISTE"
# Outils communs cités par les consignes mais pas forcément par le lanceur.
for f in typecheck2.sh r1-outils/reentrant.sh; do
  [ -f "$NOTES/$f" ] && ! grep -qxF "$f" "$LISTE" && echo "$f" >> "$LISTE" || true
done
( cd "$NOTES" && tr '\n' '\0' < "$LISTE" | xargs -0 md5sum ) | NOTES="$NOTES" perl -ne '
	/^(\S+)\s+\*?(.*)$/ or next;
	my $s = -s "$ENV{NOTES}/$2";
	$n++; $t += $s;
	$x += $s unless $u{$1}++;
	my ($k) = $2 =~ /\.(\w+)$/;
	$par{$k} += $s;
	END {
		printf "%d fichiers, %.1f Mo sur le disque, %.1f Mo de contenus différents (ce que git stocke, avant compression)\n", $n, $t / 1048576, $x / 1048576;
		printf "  .%-5s %.1f Mo\n", $_, $par{$_} / 1048576 for sort { $par{$b} <=> $par{$a} } keys %par;
	}'
if [ "${COPIER:-0}" = 1 ]; then
  DEST="$H/notes"
  mkdir -p "$DEST"
  ( cd "$NOTES" && tr '\n' '\0' < "$LISTE" | xargs -0 cp --parents -t "$DEST" )
  echo "copié dans $DEST"
fi
