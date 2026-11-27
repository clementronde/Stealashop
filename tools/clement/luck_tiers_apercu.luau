-- Aperçu des paliers de chance (chef UI, 27/11) : à lancer en Play, côté Client. Rien n'est enregistré : tout meurt
-- à l'arrêt du Play. Montre ce que le code ferait avec Assets/UI/LuckTiers (c'est une maquette du code de Cantin,
-- pas le code du jeu).
--   _G.LuckPlanche(adornee)  : les 13 paliers (v2) côte à côte au-dessus d'une pièce (un vrai colis)
--   _G.LuckClimb(adornee)    : un compteur qui monte de ×1 jusqu'à target (×1,03 par tic, ×1,25 au-delà de ×1K),
--                              avec le rebond Pop à chaque changement de palier
--   _G.LuckClear()           : retire les aperçus
-- screen_capture ne montre pas les billboards AlwaysOnTop : coupé sur les copies.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UI = RS.Assets.UI
local TIERS = UI.LuckTiers
local BASE_SIZE = UI.BB_ShelfOpen.Size

local folder = workspace:FindFirstChild("_PREVIEW_LUCK_CLAUDE") or Instance.new("Folder")
folder.Name = "_PREVIEW_LUCK_CLAUDE"
folder.Parent = workspace
local live = {} -- [board] = { tier, t0 }

-- v2 (27/11) : 13 paliers Tier_01 à Tier_13, triés par MinLuck
local function sortedTiers()
	local list = TIERS:GetChildren()
	table.sort(list, function(a, b)
		return a:GetAttribute("MinLuck") < b:GetAttribute("MinLuck")
	end)
	return list
end

local function tierFor(luck)
	local best
	for _, t in sortedTiers() do
		if luck + 1e-6 >= t:GetAttribute("MinLuck") then
			best = t
		end
	end
	return best
end

-- grands nombres : ×9.99, ×99.9, ×999, puis ×1.5K, ×250M, ×3.2T (format proposé à Cantin)
local SUFFIX = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
local function short(n)
	for _, s in SUFFIX do
		if n >= s[1] then
			local v = n / s[1]
			return (if v < 100 then string.format("%.1f", v):gsub("%.0$", "") else string.format("%d", math.floor(v))) .. s[2]
		end
	end
	return if n < 10 then string.format("%.2f", n) elseif n < 100 then string.format("%.1f", n) else string.format("%d", math.floor(n))
end
_G.LuckShort = short

local function scaleOf(obj, name)
	local s = obj:FindFirstChild(name)
	if not s then
		s = Instance.new("UIScale")
		s.Name = name
		s.Parent = obj
	end
	return s
end

local function apply(board, tier)
	local row = board.Row
	local label = row.Luck
	local icon = row.LuckIcon
	label.TextColor3 = tier:GetAttribute("LabelColor")
	local old = label:FindFirstChild("TextGradient")
	if old then
		old:Destroy()
	end
	tier.TextGradient:Clone().Parent = label
	local stroke = label:FindFirstChildOfClass("UIStroke")
	stroke.Color = tier:GetAttribute("StrokeColor")
	stroke.Thickness = tier:GetAttribute("StrokeThickness")
	local k = tier:GetAttribute("TextScale")
	board.Size = UDim2.fromOffset(BASE_SIZE.X.Offset * k * 1.15, BASE_SIZE.Y.Offset * k * 1.5)
	scaleOf(row, "TierScale").Scale = k
	scaleOf(icon, "IconScale").Scale = tier:GetAttribute("IconScale") -- en plus de TierScale
	for _, n in { "Halo", "Rays" } do
		local img = icon:FindFirstChild(n)
		local on = tier:GetAttribute(n == "Halo" and "IconHalo" or "IconRays")
		img.Visible = on
		local g = img:FindFirstChild("HaloGradient")
		if g then
			g:Destroy()
		end
		local hg = tier:FindFirstChild("HaloGradient")
		if on and hg then
			hg:Clone().Parent = img
		end
	end
	live[board] = { tier = tier, t0 = os.clock() }
end

-- éclat du chef VFX (Assets/FX/FX_LuckTier_<BurstLevel>, même forme que FX_Unbox_Reveal) au-dessus de l'adornee
local function burst(adornee, level)
	local fx = level > 0 and RS.Assets:FindFirstChild("FX") and RS.Assets.FX:FindFirstChild("FX_LuckTier_" .. level)
	if not fx or not adornee then
		return
	end
	local copy = fx:Clone()
	copy:PivotTo(CFrame.new(adornee.Position + Vector3.new(0, 1.5, 0)))
	copy.Parent = folder
	for _, e in copy:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			e:Emit(e:GetAttribute("EmitCount") or 20)
		end
	end
	task.delay(copy:GetAttribute("Duration") or 1.2, function()
		copy:Destroy()
	end)
end

local function pop(board, tier)
	burst(board.Adornee, tier:GetAttribute("BurstLevel") or 0)
	local s = scaleOf(board.Row, "PopScale")
	s.Scale = tier:GetAttribute("Pop")
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- mouvements (ce que le code jouerait d'après Motion et MotionPeriod)
RunService:BindToRenderStep("LuckPreviewMotion", Enum.RenderPriority.Last.Value, function()
	for board, st in live do
		if not board.Parent then
			live[board] = nil
			continue
		end
		local tier = st.tier
		local motion = tier:GetAttribute("Motion")
		local period = math.max(tier:GetAttribute("MotionPeriod"), 0.1)
		local t = (os.clock() - st.t0) / period
		local g = board.Row.Luck:FindFirstChild("TextGradient")
		if g and motion == "Shine" then
			g.Offset = Vector2.new(0, 0)
			local p = (t % 1)
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(math.clamp(p - 0.08, 0.001, 0.997), 0),
				NumberSequenceKeypoint.new(math.clamp(p, 0.002, 0.998), 0.45),
				NumberSequenceKeypoint.new(math.clamp(p + 0.08, 0.003, 0.999), 0),
				NumberSequenceKeypoint.new(1, 0),
			})
		elseif g and motion == "Spin" then
			g.Rotation = (t * 360) % 360
		elseif motion == "Pulse" then
			scaleOf(board.Row.Luck, "PulseScale").Scale = 1 + 0.06 * math.sin(t * math.pi * 2)
		end
		local rays = board.Row.LuckIcon:FindFirstChild("Rays")
		if rays and rays.Visible then
			rays.Rotation = (os.clock() * 40) % 360
		end
	end
end)

local function newBoard(adornee, offset)
	local b = UI.BB_ShelfOpen:Clone()
	b.AlwaysOnTop = false
	b.Adornee = adornee
	b.StudsOffsetWorldSpace = offset
	b.Parent = folder
	return b
end

_G.LuckClear = function()
	folder:ClearAllChildren()
	table.clear(live)
end

_G.LuckPlanche = function(adornee, right, up, spacing)
	_G.LuckClear()
	right = right or Vector3.xAxis
	up = up or 3
	spacing = spacing or 4.2
	for i, tier in sortedTiers() do
		local b = newBoard(adornee, right * ((i - 7) * spacing) + Vector3.new(0, up + ((i % 2 == 0) and 1.4 or 0), 0))
		b.Row.Luck.Text = "×" .. short(tier:GetAttribute("MinLuck")) .. " LUCK"
		apply(b, tier)
	end
end

_G.LuckClimb = function(adornee, up, target)
	_G.LuckClear()
	target = target or 10
	local b = newBoard(adornee, Vector3.new(0, up or 3, 0))
	local luck = 1
	local current = tierFor(luck)
	b.Row.Luck.Text = "×" .. short(1) .. " LUCK"
	apply(b, current)
	task.spawn(function()
		local step = if target > 1000 then 1.25 else 1.03 -- grands nombres : on monte plus vite
		local n = math.ceil(math.log(target) / math.log(step))
		local wait0 = 0.09
		for i = 1, n do
			luck = math.min(step ^ i, target)
			b.Row.Luck.Text = "×" .. short(luck) .. " LUCK"
			local icon = b.Row.LuckIcon
			icon.Rotation = (i % 2 == 0) and 8 or -8
			local tier = tierFor(luck)
			if tier ~= current then
				current = tier
				apply(b, tier)
				pop(b, tier)
			end
			task.wait(math.max(0.02, wait0 * (1 - i / n) ^ 1.5))
		end
		b.Row.LuckIcon.Rotation = 0
	end)
	return b
end
