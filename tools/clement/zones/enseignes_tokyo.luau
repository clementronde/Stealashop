--!nocheck
-- Enseignes de Tokyo sans « slop » (règle du chef DA : da-enseignes-sans-slop.md, 28/11 ; tableau, lignes Z3).
-- Charger d'abord tools/clement/zones/lettres_voxel.luau (police maison et pictos). À lancer en Edit, après
-- biome_tokyo.luau (il pose ses pièces dans Street_Tokyo/Biome/Enseignes).
--   - SignPart (gardées, seul leur texte part) : TECH (Électronique) et GAMES (Jeux vidéo) en Neon voxel, devant les
--     SignBorder et sous l'écran de façade, à la plus grande taille sans contact ;
--   - écrans de façade et publicités : mire de couleurs (Électronique), vaisseau et cœur-pièce en pixels (Jeux vidéo) ;
--   - norens et enseignes verticales des magasins : picto éclair (Électronique) ou manette (Jeux vidéo) ;
--   - rue : mots épelés à la verticale et enseignes remplacés par des pictos (Neon sur les enseignes, sans contour ni
--     répétition sur le tissu : nobori, norens, plaque du torii) : SAKURA → fleur de cerisier, TOKYO → lanterne,
--     ARCADE/GAME → manette, CAMERA → appareil photo, MANGA/ANIME/COMICS → livre, SUSHI → sushi, RAMEN/NOODLES → bol,
--     KARAOKE/SING → micro, BAR → verre, PHARMACY → croix, HOTEL → lit ; ShopBoard (O/P/E/N) : texte retiré seul ;
--   - budget (28/11, Chef de projet ; plafond 4 500 par zone) : un picto par face (2 pour le micro), pictos sans
--     contour, petit cerisier sur les nobori, rectangles gloutons : 947 pièces au lieu de 2 553, zone à 5 154 ;
--   - le picto micro du KARAOKE (Tower_S5) est posé dans Tower_S5, ses blocs nommés BladeNeon_Picto : le FX_NeonFlicker
--     déjà là le fait grésiller avec les tubes de l'enseigne.
-- Intérieurs (en-têtes de rayons, écrans muraux, promos, réserve) non touchés : consigne du Chef de projet du 28/11.
-- Les SurfaceGui retirés vont dans ServerStorage/MapBackups/<date>_Enseignes_Tokyo (attributs Path, NomOrigine) :
-- pour revenir en arrière, remettre chacun dans la pièce de son Path et lui rendre son NomOrigine.
-- Relançable : ne retrouve plus de texte une fois passé ; pour refaire les pictos, remettre d'abord les SurfaceGui.

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local LV = _G.LettresVoxel
assert(LV and LV.surFace and LV.motMagasin, "charger d'abord tools/clement/zones/lettres_voxel.luau")
local Z = workspace.Map.Zone_3
local ST = Z.Street_Tokyo
local Bio = ST:FindFirstChild("Biome")
assert(Bio, "lancer d'abord biome_tokyo.luau")
local mb = game.ServerStorage.MapBackups
local bname = os.date("%Y-%m-%d") .. "_Enseignes_Tokyo"
local bk = mb:FindFirstChild(bname)
if not bk then bk = Instance.new("Folder") bk.Name = bname bk.Parent = mb end
local rec = CHS:TryBeginRecording("Enseignes Tokyo", { allowNoUndo = true })

local function keep(inst)
	inst:SetAttribute("Path", inst:GetFullName())
	inst:SetAttribute("NomOrigine", inst.Name)
	for _, d in inst:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
	inst.Parent = bk
end
local STREET = {
	SAKURA = "sakura", ["HOTEL SAKURA"] = "sakura", HOTEL = "lit", ARCADE = "manette", GAME = "manette",
	CAMERA = "appareil", MANGA = "livre", ANIME = "livre", COMICS = "livre", SUSHI = "sushi", RAMEN = "ramen",
	NOODLES = "ramen", KARAOKE = "micro", SING = "micro", BAR = "verre", PHARMACY = "croix", TOKYO = "lanterne",
}
local CLOTH = { Banner = true, Noren = true, Noren_1 = true, Noren_2 = true, Plaque = true }

local jobs = {}
for _, g in Z:GetDescendants() do
	if g:IsA("SurfaceGui") and g.Parent:IsA("BasePart") and not g:FindFirstAncestor("Interior") and not g:FindFirstAncestor("Reserve") then
		local t = g:FindFirstChildWhichIsA("TextLabel", true)
		if t then
			local txt = t.Text:gsub("<[^>]+>", ""):gsub("[/\n]", ""):gsub("^%s+", ""):gsub("%s+$", "")
			table.insert(jobs, { g = g, host = g.Parent, face = g.Face, text = txt })
		end
	end
end
local E = Bio:FindFirstChild("Enseignes")
if not E then E = Instance.new("Folder") E.Name = "Enseignes" E.Parent = Bio end
local done, strips, made, notes = {}, 0, 0, {}
for _, j in jobs do
	local h = j.host
	local store = h
	while store and not store.Name:match("^STORE_") do store = store.Parent end
	local isElec = store and store.Name:match("Electronique") ~= nil
	local pic
	if h.Name == "SignPart" then pic = "__mot"
	elseif h.Name == "FacadeScreen" or h.Name == "AdScreen" then pic = isElec and "mire" or (h.Name == "FacadeScreen" and "vaisseau" or "coeur_piece")
	elseif h.Name:match("^Noren_") or h.Name:match("^VSign_") then pic = isElec and "eclair" or "manette"
	elseif h.Name == "ShopBoard" then pic = false
	else pic = STREET[j.text] end
	if pic == nil then
		table.insert(notes, "laissé : " .. h.Name .. " « " .. j.text .. " »")
	else
		keep(j.g)
		strips += 1
		if pic == "__mot" then
			if not done[h] then
				done[h] = true
				local word = isElec and "TECH" or "GAMES"
				local m, px = LV.motMagasin(store, word, Color3.fromHex(isElec and "18e0ff" or "ff3ea5"), { px = 0.5, neon = true })
				if m then made += 1 table.insert(notes, word .. " à " .. px) else table.insert(notes, "pas de place pour " .. word) end
			end
		elseif pic then
			local screen = h.Name == "FacadeScreen" or h.Name == "AdScreen"
			local cloth = CLOTH[h.Name]
			local fx = h:FindFirstAncestor("Tower_S5") ~= nil and j.text == "KARAOKE"
			local parent = fx and h:FindFirstAncestor("Tower_S5") or E
			if cloth and pic == "sakura" then pic = "sakura_petit" end -- 28/11 : moins de pièces sur les nobori
			local ms = LV.surFace(parent, h, j.face, pic, {
				max = fx and 2 or 1, -- 28/11 : un picto par face (2 pour le micro qui grésille) : budget du téléphone
				neon = not cloth,
				contour = false, -- 28/11 : sans contour (l'enseigne sert de fond), pour le budget du téléphone
				marge = screen and 0.95 or 0.85,
				repete = not (screen or cloth),
				nom = fx and "Picto_micro_FX" or ("Picto_" .. pic),
			})
			if fx then
				for _, m in ms do for _, p in m:GetDescendants() do if p:IsA("BasePart") and p.Name == "Bloc" then p.Name = "BladeNeon_Picto" end end end
			end
			made += #ms
		end
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local np = 0 for _, d in E:GetDescendants() do if d:IsA("BasePart") then np += 1 end end
return ("Enseignes Tokyo : %d textes retirés, %d enseignes et pictos (%d pièces) ; %s"):format(strips, made, np, table.concat(notes, " ; "))
