---------------------------------------------------------------- montage a213 (après setup190.luau de la copie a205 d'a190)
FLY = HudCfgC.TrainGainFly
PULSE = HudCfgC.SpeedPulse
FormulasC = requireModule(ReplicatedStorage.Shared.Config.Formulas, "client")
MotionC = requireModule(MOTION_MODULE, "client")
MotionC.SetSoundPlayer(function() end)
SPEED_POPS = {} -- départs (from) des Motion.Pop sur SpeedRow, dans l'ordre

-- Joueur à Speed `speed` (trail `trail` facultatif), HUD de makeHud, vrais HudController et GainController lancés.
function startBanc(speed, trail)
	P1:SetAttribute("Cash", 100)
	P1:SetAttribute("Income", 10)
	P1:SetAttribute("Speed", speed)
	P1:SetAttribute("TrailMultiplier", trail)
	P1:SetAttribute("ShownSpeed", FormulasC.ShownSpeed(speed, trail))
	P1:SetAttribute("WalkSpeed", 16)
	P1:SetAttribute("Damage", 1)
	P1:SetAttribute("CashCollected", 0)
	local hud = makeHud()
	local Hud = requireModule(HUD_MODULE, "client")
	local Gain = requireModule(GAIN_MODULE, "client")
	taskLib.spawn(Hud.Start)
	taskLib.spawn(Gain.Start)
	step(0.1)
	local row = el(hud, "SpeedRow")
	local realPop = MotionC.Pop
	MotionC.Pop = function(object, from, info)
		if object == row then
			table.insert(SPEED_POPS, from)
		end
		return realPop(object, from, info)
	end
	return hud, Gain
end

-- Une seconde de tapis vue par le client : Speed (TrainingService) puis ShownSpeed (StatsService), comme le serveur.
function credit(speed)
	P1:SetAttribute("Speed", speed)
	P1:SetAttribute("ShownSpeed", FormulasC.ShownSpeed(speed, P1:GetAttribute("TrailMultiplier")))
end

function flyers(hud)
	return childrenNamed(hud, FLY.Name)
end
function speedText(hud)
	return el(hud, "Speed").Text
end
-- Centre du GuiObject en px de l'écran (AbsolutePosition + moitié de AbsoluteSize).
function centre(object)
	local p, s = object.AbsolutePosition, object.AbsoluteSize
	return Vector2.new(p.X + s.X / 2, p.Y + s.Y / 2)
end
function dist(a, b)
	return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2)
end
-- Premier TextLabel descendant dont le texte vaut `text`.
function labelWithText(root, text)
	for _, d in root:GetDescendants() do
		if d.ClassName == "TextLabel" and d.Text == text then
			return d
		end
	end
	return nil
end
