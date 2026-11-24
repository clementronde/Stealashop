#!/usr/bin/env bash
# a158 (2026-11-14, vague 50, décision de Cantin : le colis porté fermé, payload « NPCBox », n'existe plus) :
# lance un banc existant en corrigeant ses scénarios à la volée, sans recopier toute sa chaîne de bouchons.
#   bash corrige.sh <nom> <commande du banc…>
# Le fichier Luau assemblé par le banc est corrigé juste avant d'être exécuté : un faux luau.exe, posé dans un HOME
# passager, applique les corrections puis appelle le vrai.
#   - patches/commun.sed : les colis portés des scénarios deviennent des objets sortis d'un colis (NPCItem, Luck = 1) ;
#   - patches/<nom>.sed, s'il existe : les attentes de ce banc qui changent pour une bonne raison (dites dans le fichier) ;
#   - patches/<nom>.pre.luau, s'il existe : ajouté en tête du fichier (aides remplacées ; le .sed renomme les anciennes).
# Les sources du jeu ne sont pas touchées par commun.sed (elles n'ont plus ces motifs depuis a158).
# Le lanceur de chaque banc (autres-bancs/<nom>/run.sh) n'appelle ce script que sur un arbre où a158 est fusionné ;
# avant, il lance le banc d'origine tel quel.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
shift
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "sed -E -i -f \"$H/patches/commun.sed\" \"\$f\""
	if [ -f "$H/patches/$NAME.sed" ]; then
		echo "sed -E -i -f \"$H/patches/$NAME.sed\" \"\$f\""
	fi
	if [ -f "$H/patches/$NAME.pre.luau" ]; then
		echo "cat \"$H/patches/$NAME.pre.luau\" \"\$f\" > \"\$f.a158\" && mv \"\$f.a158\" \"\$f\""
	fi
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
