#!/usr/bin/env bash
# a262 : crée a262-banc/autres-bancs/<nom>/run.sh qui lance <lanceur d'avant> par a262-banc/corrige.sh.
#   bash mk.sh <nom> <lanceur d'avant, chemin sous $H>
H="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="$1"; OLD="$2"
mkdir -p "$H/a262-banc/autres-bancs/$NAME"
cat > "$H/a262-banc/autres-bancs/$NAME/run.sh.new" <<EOS
#!/usr/bin/env bash
# a262 (vague 76, 2026-11-19) : banc $NAME d'avant la vague 76 ($OLD), corrigé à la volée par a262-banc/corrige.sh
# (attribut Tier rendu d'après BoxRarity, puis a262-banc/patches/$NAME.pl s'il existe). Arbre sans la vague 76 : tel quel.
S="\$(cd "\$(dirname "\$0")/../../.." && pwd)"
exec bash "\$S/a262-banc/corrige.sh" "$NAME" "\$S/$OLD" "\$@"
EOS
mv "$H/a262-banc/autres-bancs/$NAME/run.sh.new" "$H/a262-banc/autres-bancs/$NAME/run.sh"
