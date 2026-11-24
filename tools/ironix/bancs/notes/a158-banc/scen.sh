#!/usr/bin/env bash
# a158, outil : pose la liste des scénarios (ou « RETIRE raison ») d un banc dans origines.txt.  bash scen.sh <nom> <mots…>
H="$(cd "$(dirname "$0")" && pwd)"; n="$1"; shift
awk -v n="$n" -v s="$*" '$1 == n { print $1, $2, $3, $4, $5 (s == "" ? "" : " " s); next } { print }' "$H/origines.txt" > "$H/origines.tmp" && mv "$H/origines.tmp" "$H/origines.txt"
