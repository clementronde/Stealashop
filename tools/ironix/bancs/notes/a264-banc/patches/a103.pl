# a264 (vague 78, 2026-11-20) : banc a103, scénario « caught », K5 (l'objet resté au sol revole vers son rayon). Un appui
# GrabItem pendant le vol est refusé (« objet en vol ») sans rien donner ; à la pose, l'objet est toujours sur son rayon
# (l'appui refusé n'a laissé aucun maintien qui le donnerait). Cas K5h et K5i.
if (has(q{"K5d en vol (Landed = false)")})) {
	lit(q{"K5d en vol (Landed = false)")},
		q{"K5d en vol (Landed = false)")
fireAs(A, "GrabItem", back:GetAttribute("SlotId"))
flush()
check(not Carry.IsCarrying(A) and itemAt(STORE_A, 2) == back, "K5h appui pendant le vol : refusé, rien n'est donné (a264)")}, 'K5d');
	lit(q{"K5e posé sur son ShelfSlot")},
		q{"K5e posé sur son ShelfSlot")
check(not Carry.IsCarrying(A) and itemAt(STORE_A, 2) == back, "K5i à la pose, toujours sur son rayon : l'appui refusé n'a laissé aucun maintien (a264)")}, 'K5e');
}
