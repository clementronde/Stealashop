-- Aura et objet porté au-dessus de la tête : pistes A + B choisies par Clément (28/11), chef VFX et son.
-- À coller en Edit. Relançable (les valeurs d'origine sont gardées en attributs Orig* sur chaque émetteur et
-- chaque lumière, et on repart toujours d'elles). Sauvegarde avant le premier passage :
-- ServerStorage/MapBackups/2026-11-28_Auras_AvantAB. Aucun script, aucun nom changé.
-- Captures montrées à Clément : StealAShop-Art/Captures/2026-11-27_VFX/03_Aura_*_pistes.jpg.
--   B (sans code) : sur le haut du corps (pièces Torso, Arm, Hand, Head), ZOffset −2 (l'objet porté, au-dessus de la
--     tête, passe devant l'aura) et LightEmission 0,4 au plus ; toutes les lumières des auras à Brightness 0,5 et
--     Range 6 au plus (elles ne teintent plus l'objet).
--   A (avec le code de Cantin) : attribut CarryMode sur les Attachments, lu pendant le port (attribut Carrying du
--     personnage) : « Off » = éteint pendant le port (mains levées collées à l'objet, et ce qui passe au-dessus de
--     la tête), « Dim » = débit et lumière à 30 % pendant le port. Sans attribut : rien ne change.
local SS = game:GetService("ServerStorage")
local folder = game.ReplicatedStorage.Assets.FX:FindFirstChild("Auras")
assert(folder, "Assets/FX/Auras absent")

-- mêmes listes que les captures montrées à Clément (tools/clement/capture_aura_port.luau)
local OFF = { "Poing", "Arcs", "Couronne", "ColonneHaut", "Ciel", "HaloGlow", "Eye", "Tete", "Shine" }
local DIM = { "Coeur", "Lumiere", "Dos", "RisingAura", "Flames", "Foyer", "Colonne", "Orbite", "Filament", "Wing", "Rise" }
local function has(name: string, list: { string }): boolean
	for _, k in list do if name:find(k) then return true end end
	return false
end
local function upperBody(part: Instance?): boolean
	if not part then return false end
	local n = part.Name
	return n:find("Torso") ~= nil or n:find("Arm") ~= nil or n:find("Hand") ~= nil or n == "Head"
end

-- sauvegarde, une seule fois
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-28_Auras_AvantAB") then
	local b = folder:Clone()
	b.Name = "2026-11-28_Auras_AvantAB"
	b.Parent = backups
end

local report = {}
for _, model in folder:GetChildren() do
	local nOff, nDim, nB, nLight = 0, 0, 0, 0
	for _, at in model:GetDescendants() do
		if at:IsA("Attachment") then
			-- piste A : l'attribut que lira le code
			local mode = if has(at.Name, OFF) then "Off" elseif has(at.Name, DIM) then "Dim" else nil
			-- les arcs des jambes (Eclair) ne touchent pas l'objet porté : on les garde
			if at.Name == "Arcs" and at.Parent and at.Parent.Name:find("Leg") then mode = nil end
			at:SetAttribute("CarryMode", mode)
			if mode == "Off" then nOff += 1 elseif mode == "Dim" then nDim += 1 end
			-- piste B : en jeu, l'Attachment va sur la pièce du corps du même nom que son parent ici
			local upper = upperBody(at.Parent)
			for _, e in at:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					if e:GetAttribute("OrigZOffset") == nil then
						e:SetAttribute("OrigZOffset", e.ZOffset)
						e:SetAttribute("OrigLightEmission", e.LightEmission)
					end
					if upper then
						e.ZOffset = math.min(e:GetAttribute("OrigZOffset") :: number, -2)
						e.LightEmission = math.min(e:GetAttribute("OrigLightEmission") :: number, 0.4)
						nB += 1
					else
						e.ZOffset = e:GetAttribute("OrigZOffset") :: number
						e.LightEmission = e:GetAttribute("OrigLightEmission") :: number
					end
				end
			end
		end
	end
	for _, l in model:GetDescendants() do
		if l:IsA("Light") then
			if l:GetAttribute("OrigBrightness") == nil then l:SetAttribute("OrigBrightness", l.Brightness) end
			l.Brightness = math.min(l:GetAttribute("OrigBrightness") :: number, 0.5)
			if l:IsA("PointLight") then
				if l:GetAttribute("OrigRange") == nil then l:SetAttribute("OrigRange", l.Range) end
				l.Range = math.min(l:GetAttribute("OrigRange") :: number, 6)
			end
			nLight += 1
		end
	end
	table.insert(report, string.format("%s : %d Off, %d Dim, %d émetteurs du haut en B, %d lumières baissées", model.Name, nOff, nDim, nB, nLight))
end
return table.concat(report, "\n")
