---------------------------------------------------------------- a177 : porte d'une boutique (vitre Model)
-- Scénario « glass » (a177, vague 55, Cantin 2026-11-15 : « la vitrine est opaque ») : la porte d'une boutique est un
-- Model (PlotDoor/Window, vantaux Leaf_L et Leaf_R : un Glass entre deux montants chromés, comme PLOT_Shop). Les
-- montants sont créés AVANT le verre (chez le client, l'ordre suit le streaming). Un coup : le verre creusé prend le
-- verre de Glass (transparent), seules les vitres sont cachées, les montants restent ; la casse : éclats et sons.
-- Mise en place : début des scénarios du banc a16 (copie a134), jusqu'au démarrage, lu par run.sh.
print("\n== a177 : porte d'une boutique, vitre Model à montants")
local P = CFrame.new(-40, 0, 40)
local plot = new("Model", { Name = "PLOT_Shop_07" })
plot.WorldPivot = P
local doorModel = new("Model", { Name = "PlotDoor" }, plot)
local win = new("Model", { Name = "Window" }, doorModel)
local glasses, stiles = {}, {}
local CHROME = Color3.fromRGB(200, 200, 210)
for _, spec in { { "Leaf_L", -9 }, { "Leaf_R", 0 } } do
	local leaf = new("Model", { Name = spec[1] }, win)
	local x0 = spec[2]
	table.insert(stiles, new("Part", { Name = "Stile_A", Size = Vector3.new(0.3, 10.5, 0.6), CFrame = P * CFrame.new(x0 + 0.15, 5.85, 0), Material = Enum.Material.SmoothPlastic, Transparency = 0, Color = CHROME }, leaf))
	table.insert(glasses, new("Part", { Name = "Glass", Size = Vector3.new(8.4, 9.9, 0.6), CFrame = P * CFrame.new(x0 + 4.5, 5.85, 0), Material = Enum.Material.Glass, Transparency = 0.55, Color = GLASS }, leaf))
	table.insert(stiles, new("Part", { Name = "Stile_B", Size = Vector3.new(0.3, 10.5, 0.6), CFrame = P * CFrame.new(x0 + 8.85, 5.85, 0), Material = Enum.Material.SmoothPlastic, Transparency = 0, Color = CHROME }, leaf))
end
win.WorldPivot = P * CFrame.new(0, 0.6, 0)
local plotFractured = fracturedM("WindowFractured", 36, Vector3.new(0.24, 3.86, 0), P * CFrame.new(0, 0.5, 0), 1)
plotFractured.Parent = doorModel
new("Part", { Name = "Bounds", Size = Vector3.new(20, 10, 22), CFrame = P * CFrame.new(0, 5, 12), Transparency = 1, CanCollide = false, CanQuery = false }, plot)
plot:SetAttribute("PlotIndex", 7)
plot.Parent = map
addTag(plot, "PlayerPlot")

local WS = requireModule(MODULES["server/Services/WindowService.luau"], "server")
WS.Init()
taskLib.spawn(WS.Start)
local WC = requireModule(MODULES["client/Controllers/WindowController.luau"], "client")
local SC = requireModule(MODULES["client/Controllers/ShatterController.luau"], "client")
local HC = requireModule(MODULES["client/Controllers/HitController.luau"], "client")
requireModule(MODULES["client/Controllers/AnimationController.luau"], "client")
WC.Init()
taskLib.spawn(WC.Start)
taskLib.spawn(SC.Start)
taskLib.spawn(HC.Start)
step(0.5)
local ID = "Plot_7"
check(win:GetAttribute("WindowId") == ID, "porte enregistrée par WindowService (Plot_7)")
check(WC.GetWindow(ID) == win, "WindowController la connaît")

print("\n== un coup : verre creusé transparent, montants visibles")
local point = glasses[1].Position + Vector3.new(0, 0, -0.3)
FAKE_REMOTES.WindowHit.clientSignal:Fire(ID, point, OTHER)
step(0.15)
local pieces = carved(ID)
check(#pieces >= 1, `verre creusé posé ({#pieces} morceau(x))`)
local allGlass = #pieces > 0
for _, piece in pieces do
	if piece.Material ~= Enum.Material.Glass or math.abs(piece.Transparency - 0.55) > 1e-6 then
		allGlass = false
	end
end
check(allGlass, `verre creusé en matériau Glass, Transparency 0,55 (trouvé {pieces[1] and tostring(pieces[1].Material)}, {pieces[1] and pieces[1].Transparency})`)
check(glasses[1].LocalTransparencyModifier == 1 and glasses[2].LocalTransparencyModifier == 1, "les deux vitres cachées en local")
local framesShown = true
for _, stile in stiles do
	if stile.LocalTransparencyModifier ~= 0 then
		framesShown = false
	end
end
check(framesShown, "les montants restent visibles (cadre)")
local wide = 0
for _, piece in pieces do
	wide = math.max(wide, piece.Size.X)
end
check(wide <= 17.4 + 1e-3, `verre creusé à la largeur des vitres (17,4), pas du cadre (18) : {string.format("%.2f", wide)}`)
local chips = named("GlassCube")
check(#chips > 0 and chips[1].Color ~= CHROME, "mini-éclats couleur de verre, pas de chrome")

print("\n== la casse : éclats et sons")
local t0 = now()
win:SetAttribute("Broken", true)
FAKE_REMOTES.WindowBroken.clientSignal:Fire(ID, point)
step(0.6)
check(#carved(ID) == 0, "le verre creusé disparaît à la casse")
check(#shardsInFx() > 0, `éclats lancés ({#shardsInFx()})`)
check(soundCount("Glass_BreakThud", t0) >= 1 and soundCount("Glass_BreakShatter", t0) >= 1, "sons de la casse (Thud, Shatter)")
step(6)
check(soundCount("Glass_BreakDebris", t0) >= 1, "son des débris")

print("\n== sortie")
local warns = warnings()
for _, line in warns do
	print("    " .. line)
end
check(#warns == 0, "aucun avertissement")
summary()
