---------------------------------------------------------------- scénario « template » : modèle facultatif de Clément
local hud = startBanc(10, nil)
print("\n== M1. UI_HUD.TrainGainFly.Template (Amount, Icon) avec SpeedColor et SpeedIcon")
local folderUi = new("Frame", { Name = "TrainGainFly", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, hud)
local template = new("Frame", { Name = "Template", Visible = false, Size = UDim2.fromOffset(150, 40) }, folderUi)
new("TextLabel", { Name = "Amount", Text = "+0" }, template)
new("ImageLabel", { Name = "Icon", Image = "" }, template)
template:SetAttribute("SpeedColor", Color3.new(0, 1, 0))
template:SetAttribute("SpeedIcon", "rbxassetid://clement-speed")
P1:SetAttribute("TrainingMachine", "Treadmill")
credit(12)
local f = flyers(hud)[1]
check(f ~= nil and f.Parent == hud and f.Visible == true, "M1a une copie visible du modèle vole")
if f then
	local c = el(f, "Amount").TextColor3
	check(el(f, "Amount").Text == "+2 Speed/s" and c.R == 0 and c.G == 1 and c.B == 0, "M1b texte et couleur de SpeedColor")
	check(el(f, "Icon").Image == "rbxassetid://clement-speed", "M1c icône de SpeedIcon")
	check(f.AbsoluteSize.X == 150, `M1d taille de Clément gardée ({f.AbsoluteSize.X})`)
end
check(template.Visible == false and el(template, "Amount").Text == "+0" and template.Parent == folderUi, "M1e modèle intact")
step(1.3)
check(#flyers(hud) == 0 and speedText(hud) == "12", "M1f arrivé, nombre monté")
summary()
