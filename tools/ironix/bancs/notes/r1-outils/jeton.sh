#!/usr/bin/env bash
# r1 (2026-11-20, accord de Cantin) : limite de processeur des bancs, à la place du verrou commun .verrou-bancs.
# Prend un des N jetons de la machine (tous agents confondus), lance la commande, rend le jeton.
#   bash jeton.sh <commande> [arguments…]     (code de sortie : celui de la commande)
#   bash jeton.sh --n                        affiche N
# Jetons : dossiers F:/StealAShop/.jetons-bancs/<k>, k de 1 à N (mkdir est atomique) ; <k>/pid = PID du porteur.
# N = nombre de processeurs logiques moins 2 (au moins 1) ; R1_JETONS=<n> pour forcer, R1_JETONS_DIR=<dossier> pour
# un autre jeu de jetons. Jeton perdu (processus tué par kill -9, coupure) : repris quand son porteur n'existe plus,
# ou quand il a plus de R1_JETON_MAX_MIN minutes (12 par défaut : les lanceurs coupent un banc à 600 s).
# Ne sert qu'à des commandes bornées (timeout 600 au plus). L'ancien verrou n'est ni pris ni attendu : depuis r1 les
# bancs écrivent dans un dossier propre à leur lancement, un agent qui le prend encore ne gêne personne.
set -u
D="${R1_JETONS_DIR:-/f/StealAShop/.jetons-bancs}"
N="${R1_JETONS:-}"
if [ -z "$N" ]; then N=$(( $(nproc 2>/dev/null || echo 4) - 2 )); fi
[ "$N" -ge 1 ] 2>/dev/null || N=1
if [ "${1:-}" = "--n" ]; then echo "$N"; exit 0; fi
[ $# -ge 1 ] || { echo "r1 jeton.sh : commande manquante" >&2; exit 2; }
MAXMIN="${R1_JETON_MAX_MIN:-12}"
mkdir -p "$D" 2>/dev/null
# Dossiers de bancs lancés hors lanceur (R1_RUN vide) : ceux de plus de 2 h sont morts, on les retire.
find "${TMPDIR:-/tmp}/r1-bancs" -mindepth 1 -maxdepth 1 -mmin +120 -exec rm -rf {} + 2>/dev/null
perime() { # $1 = dossier du jeton
	local p
	[ -n "$(find "$1" -maxdepth 0 -mmin +"$MAXMIN" 2>/dev/null)" ] && return 0
	p="$(cat "$1/pid" 2>/dev/null)"
	if [ -z "$p" ]; then # pid pas encore écrit (jeton tout neuf) ou porteur tué entre mkdir et l'écriture
		[ -n "$(find "$1" -maxdepth 0 -mmin +1 2>/dev/null)" ]
		return
	fi
	! kill -0 "$p" 2>/dev/null
}
k=""
tour=0
while :; do
	for ((i = 1; i <= N; i++)); do
		if mkdir "$D/$i" 2>/dev/null; then k=$i; break 2; fi
	done
	if [ $((tour % 10)) -eq 0 ]; then
		for ((i = 1; i <= N; i++)); do
			if [ -d "$D/$i" ] && perime "$D/$i"; then rm -rf "$D/$i"; fi
		done
	fi
	tour=$((tour + 1))
	sleep 1
done
echo "$$" > "$D/$k/pid"
trap 'rm -rf "$D/$k"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
"$@"
