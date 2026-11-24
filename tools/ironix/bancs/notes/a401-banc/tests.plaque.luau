---------------------------------------------------------------- banc a401, 2e partie (vague GC4, 23/11) : la plaque
-- Collé après preamble.luau du banc a59 (copie a141 : faux Roblox du banc a14, buildPlot, newPlayer) ; faux TweenService
-- d'ext-plaque.luau. Vrai DisplayController : au ramassage (remote CashCollect), Plate flashe en blanc, Glow en fondu,
-- enfoncement animé (Config/Vfx.CollectPad), retour exact ; deux ramassages à la suite ne s'empilent pas.
local PadFx = requireModule(Shared.Config.Vfx, "client").CollectPad
local Net = requireModule(Shared.Net.Net, "server")
local plot1 = buildPlot(1)
local alice = newPlayer("Alice", 1)
CLIENT_PLAYER = alice
plot1:SetAttribute("OwnerUserId", 1)
alice:SetAttribute("PlotIndex", 1)
Players.LocalPlayer = alice
Workspace.CurrentCamera = new("Camera", { CFrame = CFrame.new(0, 5, 30) }, Workspace)
local DisplayController = requireModule(controllerModule, "client")
taskLib.spawn(DisplayController.Start)
step(0.1)
local plate = plot1:FindFirstChild("CollectPad_02"):FindFirstChild("Plate")
local light = plate:FindFirstChild("Glow")
local rest, size, color, brightness = plate.CFrame, plate.Size, plate.Color, light.Brightness
local depth = plate:GetAttribute("SinkDepth")
local wide = Vector3.new(size.X * PadFx.Squash, size.Y, size.Z * PadFx.Squash) -- plaque plate sur Y
local function tweensOf(instance, from)
	local list = {}
	for i = (from or 0) + 1, #A401_TWEENS do
		if A401_TWEENS[i].Instance == instance then
			table.insert(list, A401_TWEENS[i])
		end
	end
	return list
end
local function goalWith(list, key)
	for _, tween in list do
		if tween.Goal[key] ~= nil then
			return tween
		end
	end
	return nil
end
local function playing(from)
	local n = 0
	for i = (from or 0) + 1, #A401_TWEENS do
		if A401_TWEENS[i].State == "playing" then
			n += 1
		end
	end
	return n
end
local function backToRest(label)
	check(
		near(plate.CFrame.Position.Y, rest.Position.Y, 1e-9) and near(plate.CFrame.Position.X, rest.Position.X, 1e-9) and plate.Size == size and plate.Color == color,
		label .. " : position, taille et couleur d'origine"
	)
	check(light.Enabled == false and light.Brightness == brightness, label .. " : Glow éteint, Brightness d'origine")
	check(playing() == 0, label .. " : plus aucun tween en cours")
end

print("== P1. Ramassage : flash blanc, Glow en fondu, enfoncement animé, retour exact")
check(PadFx ~= nil and PadFx.Enabled == true, "P1a Config/Vfx.CollectPad allumé")
local base = #A401_TWEENS
Net.Server.CashCollect:FireAll(1, 2, 500)
step(0.01)
check(light.Enabled == true and light.Brightness == 0, `P1b Glow allumé, parti de 0 ({light.Brightness})`)
local first = tweensOf(plate, base)
local flash = goalWith(first, "Color")
local sink = goalWith(first, "CFrame")
check(#first == 2 and flash and flash.Goal.Color == PadFx.FlashColor and flash.Info.Time == PadFx.FlashIn, `P1c Plate : flash vers FlashColor en FlashIn (#{#first})`)
check(
	sink ~= nil and near(sink.Goal.CFrame.Position.Y, rest.Position.Y - depth, 1e-9) and sink.Goal.Size == wide
		and sink.Info.Time == PadFx.SinkDown and sink.Info.EasingStyle == Enum.EasingStyle.Quad,
	"P1d Plate : descente de SinkDepth en SinkDown (Quad), élargie de Squash"
)
local lightUp = tweensOf(light, base)[1]
check(lightUp and lightUp.Goal.Brightness == brightness, "P1e Glow : monte jusqu'à sa Brightness d'origine")
step(PadFx.SinkDown)
check(plate.Color == PadFx.FlashColor and light.Brightness == brightness, "P1f au plus fort : plaque blanche, Glow plein")
check(near(plate.CFrame.Position.Y, rest.Position.Y - depth, 1e-9) and plate.Size == wide, "P1g plaque enfoncée et élargie")
local after = tweensOf(plate, base + 3) -- après le flash et la descente : retour de la couleur, remontée
local up = goalWith(after, "CFrame")
check(up and up.Info.EasingStyle == Enum.EasingStyle.Back and up.Info.Time == PadFx.SinkUp and up.Goal.Size == size, "P1h remontée en Back Out (SinkUp), taille d'origine")
local back = goalWith(after, "Color")
check(back and back.Goal.Color == color and back.Info.Time == PadFx.FlashOut, "P1i couleur d'origine en FlashOut")
local lightDown = tweensOf(light, base)[2]
check(lightDown and lightDown.Goal.Brightness == 0 and lightDown.Info.Time == PadFx.FlashOut, "P1j Glow : s'éteint en fondu (FlashOut)")
step(0.6)
backToRest("P1k")

print("== P2. Deux ramassages à la suite : rien ne s'empile")
local from = #A401_TWEENS
Net.Server.CashCollect:FireAll(1, 2, 500)
step(0.03)
Net.Server.CashCollect:FireAll(1, 2, 500)
step(0.01)
local cancelled = 0
for i = from + 1, #A401_TWEENS do
	local tween = A401_TWEENS[i]
	if tween.State == "cancelled" then
		cancelled += 1
	end
end
local second = tweensOf(plate, from + 3)
local sink2 = goalWith(second, "CFrame")
check(cancelled >= 3, `P2a 1re animation annulée ({cancelled})`)
check(
	sink2 ~= nil and near(sink2.Goal.CFrame.Position.Y, rest.Position.Y - depth, 1e-9) and sink2.Goal.Size == wide,
	"P2b 2e enfoncement depuis le repos d'origine (pas deux fois SinkDepth ni deux fois Squash)"
)
local flash2 = goalWith(second, "Color")
check(flash2 and flash2.Goal.Color == PadFx.FlashColor, "P2c 2e flash")
step(0.7)
backToRest("P2d")

summary()
