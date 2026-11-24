---------------------------------------------------------------- scénario « touch » (L-092 3g) : un bouton ne reste jamais grossi
local Motion = requireModule(MOTION_MODULE, "client")
Motion.SetSoundPlayer(function() end)
local Hv, R = UiMotionC.Hover, UiMotionC.Release

-- Faux InputObject : UserInputType, UserInputState et son signal de changement.
local function input(kind)
	local changed = newSignal()
	local obj = { UserInputType = kind, UserInputState = Enum.UserInputState.Begin }
	function obj:GetPropertyChangedSignal(prop)
		assert(prop == "UserInputState", prop)
		return changed
	end
	function obj:finish(state)
		self.UserInputState = state or Enum.UserInputState.End
		changed:Fire()
	end
	return obj
end

local gui = new("ScreenGui", { Name = "UI_Test" }, PLAYER_GUI)
local root = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, gui)
local buy = new("TextButton", { Name = "BuyButton", Size = UDim2.fromScale(0.3, 0.1) }, root)
local shade = new("Frame", { Name = "Shade", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, buy)
local snap = snapshot(gui)
Motion.Button(buy)

print("\n== X1. Toucher : appui puis doigt levé, sans MouseLeave")
local touch = input(Enum.UserInputType.Touch)
buy.MouseEnter:Fire() -- Roblox l'envoie aussi au toucher
buy.InputBegan:Fire(touch)
buy.MouseButton1Down:Fire()
step(0.2)
check(scaleNamed(buy, Hv.ScaleName) ~= nil, "X1a pendant l'appui : le bouton est animé")
buy.MouseButton1Up:Fire()
touch:finish()
step(R.Time + Hv.Time + 0.1)
check(countClass(buy, "UIScale") == 0, "X1b doigt levé : retour à 1, UIScale retiré")
check(shade.BackgroundTransparency == 1, "X1c Shade remis à sa transparence d'origine")

print("\n== X2. Toucher fini par InputEnded seul")
touch = input(Enum.UserInputType.Touch)
buy.MouseEnter:Fire()
buy.InputBegan:Fire(touch)
step(Hv.Time + 0.05)
check(scaleNamed(buy, Hv.ScaleName) ~= nil, "X2a survol simulé par le toucher : grossi")
buy.InputEnded:Fire(touch)
step(R.Time + 0.1)
check(countClass(buy, "UIScale") == 0 and shade.BackgroundTransparency == 1, "X2b InputEnded : retour à 1")

print("\n== X3. Toucher annulé (glissé hors du bouton)")
touch = input(Enum.UserInputType.Touch)
buy.MouseEnter:Fire()
buy.InputBegan:Fire(touch)
buy.MouseButton1Down:Fire()
step(0.1)
touch:finish(Enum.UserInputState.Cancel)
step(R.Time + 0.1)
check(countClass(buy, "UIScale") == 0 and shade.BackgroundTransparency == 1, "X3a annulé : retour à 1")

print("\n== X4. Souris : le survol reste tant que la souris est dessus")
local click = input(Enum.UserInputType.MouseButton1)
buy.MouseEnter:Fire()
buy.InputBegan:Fire(click)
buy.MouseButton1Down:Fire()
step(0.1)
buy.MouseButton1Up:Fire()
click:finish()
buy.InputEnded:Fire(click)
step(R.Time + 0.1)
local s = scaleNamed(buy, Hv.ScaleName)
check(s ~= nil and near(s.Scale, Hv.To, 1e-4), "X4a clic de souris : retour au survol, pas à 1")
buy.MouseLeave:Fire()
step(Hv.Time + 0.1)
check(countClass(buy, "UIScale") == 0, "X4b souris sortie : retour à 1")

local same, why = sameAs(snap, gui)
check(same, `X5 UI_Test comme au départ ({why})`)
summary()
