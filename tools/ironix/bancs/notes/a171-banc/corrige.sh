#!/usr/bin/env bash
# a171 (2026-11-15, vague 52 : couverture des bancs après a158) : lance un banc existant comme a158-banc/corrige.sh
# (patches/commun.sed, puis les patches d'a158 pour ce banc) et y ajoute les corrections d'a171, pour un scénario que a158
# avait retiré alors qu'il vérifie au passage une règle qui existe encore (inventaire, barre du bas, index, mutations…).
#   bash corrige.sh <nom> <commande du banc…>
# Corrections appliquées au fichier Luau assemblé juste avant son exécution (faux luau.exe dans un HOME passager) :
#   a158-banc/patches/commun.sed, a158-banc/patches/<nom>.sed, a158-banc/patches/<nom>.pre.luau (comme a158) ;
#   a171-banc/patches/<nom>.sed, <nom>.pre.luau, puis <nom>.<scénario>.sed et <nom>.<scénario>.pre.luau, s'ils
#   existent (scénario lu dans le nom du fichier assemblé, run.<scénario>.luau, ou dans A171_SCEN).
# Inclusions : ligne « -- a171-inclut: <fichier> » dans un .pre.luau, « # a171-inclut: <fichier> » dans un .sed
# (cherché dans a171-banc/patches, puis a158-banc/patches).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
P158="$(cd "$H/../a158-banc/patches" && pwd)"
NAME="$1"
shift
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
cat > "$T/.rokit/bin/luau.exe" <<FAUX
#!/usr/bin/env bash
f="\$(cygpath -u "\$1")"
scen="\${A171_SCEN:-\$(basename "\$f" | sed -nE 's/^run\.([A-Za-z0-9_-]+)\.luau\$/\1/p')}"
trouve() { if [ -f "$H/patches/\$1" ]; then echo "$H/patches/\$1"; else echo "$P158/\$1"; fi; }
pre() {
	local inc=""
	for i in \$(sed -nE 's/^-- a171-inclut: *([^ ]+) *\$/\1/p' "\$1"); do inc="\$inc \$(trouve \$i)"; done
	cat \$inc "\$1" "\$f" > "\$f.a171" && mv "\$f.a171" "\$f"
}
sedf() {
	for i in \$(sed -nE 's/^# a171-inclut: *([^ ]+) *\$/\1/p' "\$1"); do sed -E -i -f "\$(trouve \$i)" "\$f"; done
	sed -E -i -f "\$1" "\$f"
}
sed -E -i -f "$P158/commun.sed" "\$f"
[ -f "$P158/$NAME.sed" ] && sed -E -i -f "$P158/$NAME.sed" "\$f"
[ -f "$P158/$NAME.pre.luau" ] && { cat "$P158/$NAME.pre.luau" "\$f" > "\$f.a158" && mv "\$f.a158" "\$f"; }
for x in "$NAME" "$NAME.\$scen"; do
	[ -f "$H/patches/\$x.sed" ] && sedf "$H/patches/\$x.sed"
	[ -f "$H/patches/\$x.pre.luau" ] && pre "$H/patches/\$x.pre.luau"
done
exec "$REAL_HOME/.rokit/bin/luau.exe" "\$@"
FAUX
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
