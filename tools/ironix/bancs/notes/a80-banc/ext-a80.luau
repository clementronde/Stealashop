---------------------------------------------------------------- extensions a80 (vague 26)
-- Collé après stubs.luau, ext-motion.luau, ext-a60.luau et ext-a75.luau (voit leurs variables locales) :
-- classes Highlight, ParticleEmitter (Emit relevé dans EMITS), Trail, SurfaceGui ; LocalTransparencyModifier
-- des pièces ; Vector3:Lerp ; Camera:ViewportPointToRay et ScreenPointToRay (projection inverse de
-- WorldToViewportPoint) ; AncestryChanged à la destruction (comme Roblox, quand Parent passe à nil).
ISA.Highlight = ISA.Highlight or {}
PROPS.Highlight = PROPS.Highlight or { Adornee = NONE, Enabled = true, OutlineColor = Color3.new(1, 0, 0), FillTransparency = 1 }
ISA.ParticleEmitter = ISA.ParticleEmitter or {}
PROPS.ParticleEmitter = PROPS.ParticleEmitter or { Enabled = true, Rate = 0 }
ISA.Trail = ISA.Trail or {}
PROPS.Trail = PROPS.Trail or { Enabled = true }
ISA.SurfaceGui = ISA.SurfaceGui or { "LayerCollector", "GuiBase2d" }
PROPS.SurfaceGui = PROPS.SurfaceGui or { Enabled = true }
BASEPART_PROPS.LocalTransparencyModifier = 0

EMITS = {} -- { { name, count, emitter } } dans l'ordre
function Methods.Emit(self, count)
	table.insert(EMITS, { name = self.Name, count = count, emitter = self })
end

do
	local index = V3MT.__index
	V3MT.__index = function(v, k)
		if k == "Lerp" then
			return function(a, b, t)
				return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
			end
		end
		return index(v, k)
	end
end

-- Rayon de la caméra vers un point de l'écran : origine (0, 0, 0), et le point à 1 stud sur le rayon
-- est celui que WorldToViewportPoint projette à (x, y).
local function rayTo(x, y)
	local direction = v3((x - 640) / 20, (396 - y) / 20, -1)
	return { Origin = v3(0, 0, 0), Direction = direction }
end
function Methods.ViewportPointToRay(_self, x, y)
	return rayTo(x, y)
end
function Methods.ScreenPointToRay(_self, x, y)
	return rayTo(x, y + 36)
end

do
	local destroy = Methods.Destroy
	Methods.Destroy = function(self)
		local wasParented = rawget(self, "_parent") ~= nil and not rawget(self, "_destroyed")
		destroy(self)
		if wasParented then
			local signal = rawget(self, "_signals").AncestryChanged
			if signal then
				signal:Fire(self, nil)
			end
		end
	end
end
