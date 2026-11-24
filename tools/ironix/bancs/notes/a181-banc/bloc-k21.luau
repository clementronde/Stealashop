-- Bloc K21 d'a181 (vague 56, L-171), inséré dans les tests du banc a20 avant la partie L : icône de boutique des
-- traînées ICON_Trail_<Nom> (Assets/Icons), repli sur le Decal FX_Trail_<Nom>, sinon l'image du Template.
do
	local icons = ReplicatedStorage.Assets:FindFirstChild("Icons") or new("Folder", { Name = "Icons" }, ReplicatedStorage.Assets)
	new("Decal", { Name = "ICON_Trail_Vent", Texture = "rbxassetid://7007" }, icons)
	new("Decal", { Name = "FX_Trail_Poussiere", Texture = "rbxassetid://7008" }, ReplicatedStorage.Assets.FX)
	shopGui:FindFirstChild("TrailsTab", true).Activated:Fire()
	step(0.05)
	check(field(rowOf(shopGui, "Wind"), "Icon").Image == "rbxassetid://7007", "K21a (a181) Icon d'une traînée : ICON_Trail_Vent")
	check(field(rowOf(shopGui, "Dust"), "Icon").Image == "rbxassetid://7008", "K21b (a181) sans ICON_Trail_Poussiere : repli FX_Trail_Poussiere")
	check(field(rowOf(shopGui, "Turbo"), "Icon").Image == "rbxassetid://9", "K21c (a181) ni l'un ni l'autre : image du Template")
	shopGui:FindFirstChild("AurasTab", true).Activated:Fire()
	step(0.05)
end

