# a181 (L-166 Q4) : Damage du HUD caché hors potion de force : sa visibilité peut changer.
s/\[el\(hud, "Damage"\)\] = \{ Text = true \},/[el(hud, "Damage")] = { Text = true, Visible = true },/
