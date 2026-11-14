#!/usr/bin/env bash
# Sommaire de la liaison (docs/Liaison-Code-Visuel.md) : une ligne par demande ouverte, sans le détail.
# À lancer en début de session au lieu de lire tout le fichier (240 Ko), puis lire seulement les lignes
# utiles : grep '^| L-0NN ' docs/Liaison-Code-Visuel.md
#   bash tools/liaison-sommaire.sh            toutes les lignes ouvertes
#   bash tools/liaison-sommaire.sh Clément    seulement celles pour Clément (ou Ironix)
# Colonnes : ID, Pour, Statut (URGENT en premier), Quoi (coupé à 110 caractères).
# Puis les tests à faire (lignes « - T-0NN | Qui, comment | Sujet : … » de la section « Tests à faire »).
set -eu
cd "$(dirname "$0")/.."
tr -d '\r' < docs/Liaison-Code-Visuel.md | awk -F' [|] ' -v who="${1:-}" '
/^\| L-[0-9]+ / {
	id = substr($1, 3); pour = $2; quoi = $3; st = $NF; sub(/ \|$/, "", st)
	if (who != "" && index(pour, who) == 0) next
	statut = st; sub(/ .*/, "", statut)
	if (st ~ /^À vérifier/) statut = "À vérifier"; else if (st ~ /^À faire/) statut = "À faire"; else if (st ~ /^En cours/) statut = "En cours"
	urgent = (index($0, "URGENT") > 0) ? "URGENT " : ""
	if (length(quoi) > 110) quoi = substr(quoi, 1, 107) "..."
	printf "%s | %-7s | %s%-10s | %s\n", id, pour, urgent, statut, quoi
}
/^- T-[0-9]+ [|] / {
	qui = $2; sujet = $3; for (k = 4; k <= NF; k++) sujet = sujet " | " $k
	if (who != "" && index(qui, who) == 0) next
	if (length(sujet) > 100) sujet = substr(sujet, 1, 97) "..."
	tests[++nt] = sprintf("%s | %-17s | %s", substr($1, 3), qui, sujet)
}
END {
	if (nt == 0) exit
	printf "\nTests à faire (%d), section « Tests à faire » de la liaison ; un test passé est retiré tout de suite :\n", nt
	for (k = 1; k <= nt; k++) print tests[k]
}'
