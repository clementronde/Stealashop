# a407 (vague GC6, 23/11) : ToolService.GetDoorHits (lu par WindowService pour les portes de boutique) ajouté au faux
# ToolService du banc (ajout pur ; 1 coup par frappe, comme avant).
s/^return ToolService$/function ToolService.GetDoorHits(_player) return 1 end -- a407 (ajout pur)\nreturn ToolService/
