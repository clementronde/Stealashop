-- BB_VanGauge : jauge du fourgon blindé V2, variante C « Rebours » choisie par Clément le 28/11 (L-489) ; chef UI.
-- À lancer en Edit. Copie ServerStorage/Previews/UI_VanGauge/VanGauge_C_Rebours dans ReplicatedStorage/Assets/UI sous
-- le nom BB_VanGauge (l'ancienne est rangée dans ServerStorage/MapBackups/2026-11-28_BB_VanGauge_gris, pas supprimée).
-- La variante est faite des pièces validées de BB_ArmoredVanHP (Title or et TitleShadow, Bar sombre, Fill or, Studs,
-- Shine, BarShadow), contours #040435. Noms lus par le code (Config/ArmoredVan.V2, ArmoredVanService.attachGauge) :
-- Title, Bar/Fill, ProgressText, Steps/Step_1 à Step_6 avec Current et Done. En plus, hors contrat : TitleShadow (vide
-- tant que le code n'y écrit pas) et Steps/Step_n/StepLabel (« 6 » à « 1 », la zone du palier, fixe).
-- Sans script. À relancer sans risque : remplace BB_VanGauge par une copie neuve de la variante.

local UIF = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("UI")
local SS = game:GetService("ServerStorage")
local src = SS:WaitForChild("Previews"):WaitForChild("UI_VanGauge"):WaitForChild("VanGauge_C_Rebours")

local mb = SS:WaitForChild("MapBackups")
local backup = mb:FindFirstChild("2026-11-28_BB_VanGauge_gris") or Instance.new("Folder")
backup.Name = "2026-11-28_BB_VanGauge_gris"
backup.Parent = mb
local old = UIF:FindFirstChild("BB_VanGauge")
if old then
	if backup:FindFirstChild("BB_VanGauge") then
		old:Destroy() -- une sauvegarde existe déjà : la copie en place n'est que la variante posée avant
	else
		old.Parent = backup
	end
end

local g = src:Clone()
g.Name = "BB_VanGauge"
g.AlwaysOnTop = true
g.StudsOffset = Vector3.new(0, 5, 0) -- au-dessus du toit du fourgon
g:SetAttribute("Version", "C Rebours, choisie par Clément le 28/11 (L-489)")
g.TitleShadow.Text = "" -- l'ombre suit Title quand le code y écrit aussi
for i = 1, 6 do
	local step = g.Steps["Step_" .. i]
	step.Done.Visible = false
	step.Current.Visible = false
end
g.Bar.Fill.Size = UDim2.fromScale(0, 1)

-- Le code remplit Bar/Fill et ProgressText avec les dégâts du palier (« 1.2K / 5K », ArmoredVanService.attachGauge) :
-- le temps restant va dans un TextLabel Timer neuf, sous le titre (nom proposé à Cantin, facultatif).
local function place(o, y, h)
	o.Position = UDim2.new(o.Position.X.Scale, 0, y, 0)
	o.Size = UDim2.new(o.Size.X.Scale, 0, h, 0)
end
place(g.Title, 0, 0.36)
place(g.TitleShadow, 0.03, 0.36)
local timer = g.Bar.ProgressText:Clone()
timer.Name = "Timer"
timer.Text = "NEXT ZONE IN 14s"
timer.AnchorPoint = Vector2.new(0.5, 0)
timer.Position = UDim2.fromScale(0.5, 0.37)
timer.Size = UDim2.fromScale(0.9, 0.13)
timer.ZIndex = 2
timer.Parent = g
place(g.BarShadow, 0.55, 0.26)
place(g.Bar, 0.52, 0.26)
g.Bar.ProgressText.Text = "1.2K / 5K"
place(g.Steps, 0.81, 0.18)
g.Parent = UIF
