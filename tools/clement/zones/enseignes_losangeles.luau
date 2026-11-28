--!nocheck
-- Enseignes de Los Angeles sans « slop » (règle du chef DA : da-enseignes-sans-slop.md, 28/11 ; tableau, lignes Z4).
-- Charger d'abord tools/clement/zones/lettres_voxel.luau. À lancer en Edit, après biome_losangeles.luau (qui pose
-- lui-même les lettres HEIST en police maison et la chaussée réchauffée #7a5f45).
--   - SignPart (gardées, seul leur texte part) : JEWELRY en or #d4a72c et CLOCKS en crème #f7f3e8, police du chef DA
--     (p 0,4, modèle SignLetters sous la SignPart) ;
--   - plaques : FINE JEWELRY SINCE 1926 → picto diamant ; MASTER WATCHMAKERS SINCE 1931 → retirée ;
--   - panneaux de rue StreetSign_N et StreetSign_S (SUNSET AVE, HEIST BLVD) : modèles rangés ;
--   - boutiques : bandeaux → pictos (robe, flacon, sac, fleur, chocolat, tasse, chaussure, ciseaux, jus, burger) ;
--     panneaux du toit → planche, soleil, flèche, palmier ; enseigne verticale de l'hôtel → étoiles ;
--   - affiche Billboard_S (IT'S HEIST O'CLOCK) → image d'un sac « $ » et d'une horloge ;
--   - STUDIO B (SoundStage_S) et GRAND HOTEL (Tower_S3) : retirés ;
--   - gardés, en FredokaOne : les ★ des étoiles au sol, le 7 du studio, le H de l'héliport.
-- Textes posés par biome_losangeles.luau (dans Biome) : supprimés, le biome les refait ; les autres vont dans
-- ServerStorage/MapBackups/<date>_Enseignes_LosAngeles (attributs Path, NomOrigine).
-- Intérieurs non touchés (consigne du Chef de projet du 28/11).

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local LV = _G.LettresVoxel
assert(LV and LV.surFace and LV.motMagasin, "charger d'abord tools/clement/zones/lettres_voxel.luau")
local Z = workspace.Map.Zone_4
local SL = Z.Street_LosAngeles
local Bio = SL:FindFirstChild("Biome")
assert(Bio, "lancer d'abord biome_losangeles.luau")
local mb = game.ServerStorage.MapBackups
local bname = os.date("%Y-%m-%d") .. "_Enseignes_LosAngeles"
local bk = mb:FindFirstChild(bname)
if not bk then bk = Instance.new("Folder") bk.Name = bname bk.Parent = mb end
local rec = CHS:TryBeginRecording("Enseignes Los Angeles", { allowNoUndo = true })

local function keep(inst)
	inst:SetAttribute("Path", inst:GetFullName())
	inst:SetAttribute("NomOrigine", inst.Name)
	for _, d in inst:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
	inst.Parent = bk
end
local E = Bio:FindFirstChild("Enseignes")
if E then E:Destroy() end
E = Instance.new("Folder")
E.Name = "Enseignes"
E.Parent = Bio

local PIC = {
	COUTURE = "robe", PERFUME = "flacon", ["LEATHER GOODS"] = "sac", FLORIST = "fleur", CHOCOLATES = "chocolat",
	COFFEE = "tasse", SHOES = "chaussure", ["HAIR SALON"] = "ciseaux", ["JUICE BAR"] = "jus", DINER = "burger",
	SURF = "planche", SUNSET = "soleil", MOTEL = "fleche", BEACH = "palmier", ["IT'S HEIST O'CLOCK"] = "sac_horloge",
	["FINE JEWELRY SINCE 1926"] = "diamant", HOTEL = "etoiles", ["H O T E L"] = "etoiles",
}
local STRIP = { ["MASTER WATCHMAKERS SINCE 1931"] = true, ["STUDIO B"] = true, ["GRAND HOTEL"] = true }
local KEEP = { ["★"] = true, ["7"] = true, H = true }
local FRED = Font.fromEnum(Enum.Font.FredokaOne)

for _, n in { "StreetSign_N", "StreetSign_S" } do local m = SL.Props:FindFirstChild(n) if m then keep(m) end end
local jobs = {}
for _, g in Z:GetDescendants() do
	if g:IsA("SurfaceGui") and g.Parent:IsA("BasePart") and not g:FindFirstAncestor("Interior") and not g:FindFirstAncestor("Reserve") then
		local t = g:FindFirstChildWhichIsA("TextLabel", true)
		if t then
			local txt = t.Text:gsub("<[^>]+>", ""):gsub("\n", " "):gsub("/", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
			table.insert(jobs, { g = g, t = t, host = g.Parent, face = g.Face, text = txt })
		end
	end
end
local notes, strips, made, done = {}, 0, 0, {}
for _, j in jobs do
	local h = j.host
	local inBiome = h:IsDescendantOf(Bio)
	local function drop() if inBiome then j.g:Destroy() else keep(j.g) end strips += 1 end
	if h.Name == "SignPart" then
		local store = h.Parent
		if not done[store] then
			done[store] = true
			drop()
			local bij = store.Name:match("Bijouterie") ~= nil
			local word = bij and "JEWELRY" or "CLOCKS"
			local m, px = LV.motMagasin(store, word, Color3.fromHex(bij and "d4a72c" or "ff8c42"), { px = 0.5 }) -- CLOCKS en orange : il se perdait sur la façade claire
			table.insert(notes, word .. " à " .. tostring(px))
			made += 1
		end
	elseif KEEP[j.text] then
		j.t.FontFace = FRED
	elseif STRIP[j.text] then
		drop()
	elseif PIC[j.text] then
		drop()
		made += #LV.surFace(E, h, j.face, PIC[j.text], { marge = 0.85 })
	else
		table.insert(notes, "laissé : " .. h.Name .. " « " .. j.text .. " »")
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local np = 0 for _, d in E:GetDescendants() do if d:IsA("BasePart") then np += 1 end end
return ("Enseignes LA : %d textes ou panneaux retirés, %d enseignes et pictos (%d pièces) ; %s"):format(strips, made, np, table.concat(notes, " ; "))
