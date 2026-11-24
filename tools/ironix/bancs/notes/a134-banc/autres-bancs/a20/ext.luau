---------------------------------------------------------------- extensions a20
-- Ajouts au faux Roblox du banc a15 (stubs-a15.luau, copie inchangée), pour CosmeticService,
-- StatsService, CosmeticController et AuraShopController : types de valeurs des effets
-- (NumberRange, NumberSequence, ColorSequence), classes ParticleEmitter, PointLight, Trail, Decal,
-- ScrollingFrame, ImageLabel, ImageButton, propriétés WalkSpeed, CastShadow, LayoutOrder,
-- Attachment.Position, Workspace.CurrentCamera, signaux Died et InputBegan,
-- GetPropertyChangedSignal et FindFirstChildWhichIsA. Collé juste après stubs-a15.luau dans le
-- même fichier : il voit ses variables locales (ISA, PROPS, EVENTS, Methods, InstanceMT, NONE…).
do
	local function valueType(name, fields)
		local mt = { __type = name }
		mt.__index = mt
		return function(...)
			return setmetatable(fields(...), mt)
		end
	end
	NumberRange = {
		new = valueType("NumberRange", function(a, b)
			assert(type(a) == "number", "NumberRange.new : nombre attendu")
			return { Min = a, Max = b or a }
		end),
	}
	NumberSequenceKeypoint = {
		new = valueType("NumberSequenceKeypoint", function(t, v)
			return { Time = t, Value = v }
		end),
	}
	NumberSequence = {
		new = valueType("NumberSequence", function(a, b)
			if type(a) == "table" then
				assert(#a >= 2 and a[1].Time == 0 and a[#a].Time == 1, "NumberSequence : il faut des points en 0 et en 1")
				return { Keypoints = a }
			end
			assert(type(a) == "number", "NumberSequence.new : nombre attendu")
			return { Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } }
		end),
	}
	ColorSequenceKeypoint = {
		new = valueType("ColorSequenceKeypoint", function(t, c)
			return { Time = t, Value = c }
		end),
	}
	ColorSequence = {
		new = valueType("ColorSequence", function(a, b)
			if type(a) == "table" and a.R ~= nil then
				return { Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } }
			end
			assert(type(a) == "table", "ColorSequence.new : Color3 ou liste attendue")
			return { Keypoints = a }
		end),
	}

	ISA.ParticleEmitter = {}
	ISA.PointLight = { "Light" }
	ISA.Trail = {}
	ISA.Decal = { "FaceInstance" }
	ISA.Texture = { "Decal", "FaceInstance" }
	ISA.ScrollingFrame = { "GuiObject", "GuiBase2d" }
	ISA.ImageLabel = { "GuiLabel", "GuiObject", "GuiBase2d" }
	ISA.ImageButton = { "GuiButton", "GuiObject", "GuiBase2d" }

	PROPS.Part.CastShadow = true -- même table pour MeshPart
	PROPS.Attachment.Position = Vector3.zero -- rangée à part de CFrame : le code testé n'écrit que Position
	PROPS.Humanoid.WalkSpeed = 16
	PROPS.Humanoid.HipHeight = 2 -- R15 standard (CosmeticService, effets au sol, 2026-11-11)
	PROPS.ParticleEmitter = {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 20,
		LightEmission = 0,
		LightInfluence = 1,
		Shape = "Enum.ParticleEmitterShape.Box",
		ShapeStyle = "Enum.ParticleEmitterShapeStyle.Volume",
		ShapeInOut = "Enum.ParticleEmitterShapeInOut.Outward",
		Rotation = NumberRange.new(0, 0),
		RotSpeed = NumberRange.new(0, 0),
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Lifetime = NumberRange.new(5, 10),
		Speed = NumberRange.new(5, 5),
		Acceleration = Vector3.zero,
		Size = NumberSequence.new(1),
		Transparency = NumberSequence.new(0),
		LockedToPart = false,
		Enabled = true,
	}
	PROPS.PointLight = { Color = Color3.new(1, 1, 1), Brightness = 1, Range = 8, Shadows = false, Enabled = true }
	PROPS.Trail = {
		Attachment0 = NONE,
		Attachment1 = NONE,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new(0.5),
		WidthScale = NumberSequence.new(1),
		Lifetime = 2,
		LightEmission = 0,
		LightInfluence = 1,
		FaceCamera = false,
		Texture = "",
		Enabled = true,
	}
	PROPS.Decal = { Texture = "", Color3 = Color3.new(1, 1, 1) }
	PROPS.Texture = { Texture = "", Color3 = Color3.new(1, 1, 1) }
	for _, class in { "Frame", "TextButton", "TextLabel" } do
		PROPS[class].LayoutOrder = 0
	end
	PROPS.ScrollingFrame = { Size = UDim2.fromScale(0, 0), BackgroundTransparency = 0, Visible = true, LayoutOrder = 0 }
	PROPS.ImageLabel = { Size = UDim2.fromScale(0, 0), BackgroundTransparency = 0, Visible = true, LayoutOrder = 0, Image = "" }
	PROPS.ImageButton = { Size = UDim2.fromScale(0, 0), BackgroundTransparency = 0, Visible = true, LayoutOrder = 0, Image = "" }
	PROPS.Workspace = { CurrentCamera = NONE }
	rawget(Workspace, "_props").CurrentCamera = NONE

	EVENTS.Died = true
	EVENTS.InputBegan = true

	-- Signal d'une propriété, déclenché quand sa valeur change.
	local plainNewIndex = InstanceMT.__newindex
	InstanceMT.__newindex = function(self, key, value)
		local props = rawget(self, "_props")
		local before = props[key]
		plainNewIndex(self, key, value)
		local signals = rawget(self, "_propSignals")
		local signal = signals and signals[key]
		if signal and props[key] ~= before then
			signal:Fire()
		end
	end
	function Methods.GetPropertyChangedSignal(self, key)
		local signals = rawget(self, "_propSignals")
		if signals == nil then
			signals = {}
			rawset(self, "_propSignals", signals)
		end
		signals[key] = signals[key] or newSignal()
		return signals[key]
	end

	function Methods.FindFirstChildWhichIsA(self, class, recursive)
		local list = if recursive then Methods.GetDescendants(self) else Methods.GetChildren(self)
		for _, inst in list do
			if isA(inst, class) then
				return inst
			end
		end
		return nil
	end

	-- Caméra du client simulé (Workspace.CurrentCamera).
	function setCamera(position)
		local camera = rawget(Workspace, "_props").CurrentCamera
		if camera == NONE then
			camera = InstanceAPI.new("Camera")
			camera.Name = "Camera"
			camera.Parent = Workspace
			rawget(Workspace, "_props").CurrentCamera = camera
		end
		camera.CFrame = CFrame.new(position.X, position.Y, position.Z)
		return camera
	end
end
