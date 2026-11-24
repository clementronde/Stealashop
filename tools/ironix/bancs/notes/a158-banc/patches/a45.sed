# a158, banc a45 (retour du vigile) : le porteur est celui d un objet (NPCItem) ; attrapé dans le magasin d où il vient,
# GuardService appelle CarryService.FailNoDrop (l objet revole sur son rayon) : ajouté au faux CarryService du banc (ajout pur).
/^function CarryService\.Fail\(player, reason\) return /a function CarryService.FailNoDrop(player, reason) return CarryService.Fail(player, reason) end -- a158
