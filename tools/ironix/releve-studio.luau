--!nocheck
-- Relevé Studio pour les briefs des agents (Ironix, 2026-11-11) : l'arbre d'un ou plusieurs objets, avec
-- classe, texte, attributs, tags et ce qui est caché. Les agents n'ont pas Studio : on colle ce relevé dans
-- agents/waveNN-studio.md au lieu de réécrire un script à chaque vague.
-- Usage (MCP Studio, execute_luau, mode Edit ou Server) : coller ce fichier, puis changer CIBLES et PROFONDEUR.
-- Lecture seule : ne crée, ne déplace et ne modifie rien.

local CIBLES = { -- chemins depuis game, séparés par des points
	"StarterGui.UI_HUD",
	"ReplicatedStorage.Assets.UI.BB_Gain",
}
local PROFONDEUR = 4 -- niveaux sous chaque cible
local MAX_FRERES = 2 -- au-delà, les enfants de même nom sont résumés (« … (autres X) »)

local CollectionService = game:GetService("CollectionService")
local lignes = {}

local function trouver(chemin: string): Instance?
	local courant: Instance? = game
	for morceau in string.gmatch(chemin, "[^%.]+") do
		courant = courant and courant:FindFirstChild(morceau)
	end
	return courant
end

local function decrire(o: Instance): string
	local s = `{o.Name} [{o.ClassName}]`
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
		s ..= ` "{string.sub((o :: any).Text, 1, 40)}"`
	end
	if o:IsA("GuiObject") and not o.Visible then
		s ..= " (caché)"
	elseif o:IsA("LayerCollector") and not (o :: any).Enabled then
		s ..= " (Enabled=false)"
	end
	local attributs = {}
	for k, v in o:GetAttributes() do
		table.insert(attributs, `{k}={tostring(v)}`)
	end
	if #attributs > 0 then
		table.sort(attributs)
		s ..= " {" .. table.concat(attributs, ", ") .. "}"
	end
	local tags = CollectionService:GetTags(o)
	if #tags > 0 then
		s ..= " #" .. table.concat(tags, " #")
	end
	return s
end

local function parcourir(o: Instance, niveau: number)
	table.insert(lignes, string.rep("  ", niveau) .. decrire(o))
	if niveau >= PROFONDEUR then
		return
	end
	local vus = {}
	for _, enfant in o:GetChildren() do
		-- Les UIListLayout, UICorner… sont du style : on les saute, sauf les grilles (le code les lit).
		if enfant:IsA("UIComponent") and not enfant:IsA("UIGridStyleLayout") then
			continue
		end
		vus[enfant.Name] = (vus[enfant.Name] or 0) + 1
		if vus[enfant.Name] <= MAX_FRERES then
			parcourir(enfant, niveau + 1)
		elseif vus[enfant.Name] == MAX_FRERES + 1 then
			table.insert(lignes, string.rep("  ", niveau + 1) .. `… (autres {enfant.Name})`)
		end
	end
end

for _, chemin in CIBLES do
	local cible = trouver(chemin)
	if cible then
		table.insert(lignes, `== {chemin}`)
		parcourir(cible, 0)
	else
		table.insert(lignes, `== {chemin} : absent`)
	end
end
return table.concat(lignes, "\n")
