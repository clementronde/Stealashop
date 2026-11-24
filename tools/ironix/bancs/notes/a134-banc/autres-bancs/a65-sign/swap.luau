
---------------------------------------------------------------- S (a65)
-- a65 (vague 22, L-093 point 3) : MachineVariantService remplace le modèle Treadmill de la parcelle
-- (ancien retiré, copie taggée posée au même endroit dans la même image) : le panneau suit le nouvel
-- UpgradePoint, chez le propriétaire comme chez les autres, et reste cliquable.
print("\nS échange du tapis (variante)")
do
	local old = plot1:FindFirstChild("Treadmill")
	local variant = new("Model", "Treadmill", nil)
	local frame = part("Frame", variant, CFrame.new(10, 1.5, -18), Vector3.new(5, 3, 9))
	local newPoint = new("Attachment", "UpgradePoint", frame)
	newPoint.CFrame = CFrame.new(5, -1.5, 0) * AWAY
	addTag(variant, "Treadmill")
	variant.Parent = plot1
	old.Parent = nil
	advance(0.1)
	check(signAt(newPoint) ~= nil, "panneau posé au nouvel UpgradePoint")
	check(signAt(treadPoint) == nil, "plus de panneau à l'ancien point")
	check(#allSigns() == 4 and #aliceGui:GetChildren() == 2, `a134 : toujours 4 panneaux et 2 SignGui chez Alice ({#allSigns()}, {#aliceGui:GetChildren()})`)
	local before = #BUY_LOG
	click(signAt(newPoint))
	check(#BUY_LOG == before + 1 and BUY_LOG[#BUY_LOG] == "Treadmill", "clic sur le nouveau panneau → BuyItem(\"Treadmill\")")
	-- Retour au tapis de base (départ, niveau 0) : le panneau revient à son point d'origine.
	old.Parent = plot1
	variant:Destroy()
	advance(0.1)
	check(signAt(treadPoint) ~= nil and signAt(newPoint) == nil and #allSigns() == 4, "retour au tapis de base : panneau à son point d'origine")
end

summary()
