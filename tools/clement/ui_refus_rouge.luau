--!nonstrict
-- ui_refus_rouge.luau (Clément, 26/11 : « Pour les UI quand c'est un refus, le bouton doit être rouge. »)
-- À lancer en Edit (barre de commande). PREVIEW = true : liste seulement (sortie), rien ne change.
-- PREVIEW = false : repeint en rose-rouge d'Upgrades (seul rouge validé, fiche _Vault/UI/Boutons_valides.md) chaque
-- bouton de refus de StarterGui et de ReplicatedStorage/Assets/UI :
--   - clone d'un bouton validé (enfant Background, ImageLabel) : image Background du rose d'Upgrades, rectangle ou
--     carré selon la forme, et dégradé du contour de Rectangle 2 sur un carré ;
--   - ancien bouton (recette Lip/Face) : rebord #C11748, face #F7375C → #FA8198 ;
--   - autre bouton (fond plein) : BackgroundColor3 #F7375C.
-- Un bouton de refus = un GuiButton dont le nom commence par No, Cancel, Decline, Deny, LetGo, Skip, NotNow, Later,
-- Refuse ou Reject (NoThanksButton, NoButton, CancelButton…). La croix (CloseButton) n'est pas touchée : elle ferme.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-26_Refus_avant_rouge (écrans touchés).

local PREVIEW = true

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local PINK_RECT = "rbxassetid://78893674434588" -- Background rectangle PC d'Upgrades
local PINK_SQUARE = "rbxassetid://108792730558229" -- Background carré d'Upgrades
local LIP = Color3.fromHex("C11748")
local FACE_LOW, FACE_HIGH = Color3.fromHex("F7375C"), Color3.fromHex("FA8198")
local RIM_SQUARE = ColorSequence.new(Color3.fromHex("F9839A"), Color3.fromHex("FDCDD6"))
local PREFIXES = { "No", "Cancel", "Decline", "Deny", "LetGo", "Skip", "NotNow", "Later", "Refuse", "Reject" }

-- Clément, 26/11 : « oui et oui » : le rose d'Upgrades va, et SKIP du tuto est un refus (il passe en rouge et à
-- 44 px de haut au moins sur téléphone).
local EXTRA = { "UI_Tutorial.Bubble.NextButton" }

local function isRefusal(b)
	if not b:IsA("GuiButton") or b.Name == "CloseButton" then
		return false
	end
	for _, path in EXTRA do
		if b:GetFullName() == "StarterGui." .. path then
			return true
		end
	end
	for _, p in PREFIXES do
		local rest = b.Name:sub(#p + 1)
		-- « No » seul ou suivi d'une majuscule (NoButton, NoThanksButton), jamais Notify, Normal, Nothing…
		if b.Name:sub(1, #p) == p and (rest == "" or rest:sub(1, 1):match("%u")) then
			return true
		end
	end
	return false
end

local function kind(b)
	local bg = b:FindFirstChild("Background")
	if bg and bg:IsA("ImageLabel") then
		return "clone", bg
	end
	if b:FindFirstChild("Lip") and b:FindFirstChild("Face") then
		return "recette"
	end
	return "plein"
end

local function paint(b)
	local k, bg = kind(b)
	if k == "clone" then
		local square = b.AbsoluteSize.X > 0 and b.AbsoluteSize.X / math.max(b.AbsoluteSize.Y, 1) < 1.6
		bg.Image = if square then PINK_SQUARE else PINK_RECT
		local face = b:FindFirstChild("Rectangle 2")
		local g = face and face:FindFirstChildWhichIsA("UIGradient", true)
		if square and g then
			g.Color = RIM_SQUARE
		end
	elseif k == "recette" then
		b.Lip.BackgroundColor3 = LIP
		local g = b.Face:FindFirstChildOfClass("UIGradient")
		b.Face.BackgroundColor3 = Color3.new(1, 1, 1)
		if g then
			g.Color = ColorSequence.new(FACE_HIGH, FACE_LOW) -- rotation 90 : haut clair, bas foncé
		else
			b.Face.BackgroundColor3 = FACE_LOW
		end
	else
		b.BackgroundColor3 = FACE_LOW
	end
	return k
end

local roots = { SG }
local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
local ui = assets and assets:FindFirstChild("UI")
if ui then
	table.insert(roots, ui)
end
local found = {}
for _, r in roots do
	for _, d in r:GetDescendants() do
		if isRefusal(d) then
			table.insert(found, d)
		end
	end
end

local lines = {}
for _, b in found do
	local k = kind(b)
	table.insert(lines, string.format("%s  [%s]", b:GetFullName(), k))
end
table.sort(lines)
if PREVIEW then
	print("[ui_refus_rouge] " .. #found .. " boutons de refus (rien n'a changé) :\n" .. table.concat(lines, "\n"))
	return #found .. " boutons de refus listés dans la sortie"
end

local owners = {}
for _, b in found do
	local top = b
	while top.Parent and top.Parent ~= SG and top.Parent ~= ui do
		top = top.Parent
	end
	owners[top] = true
end
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-26_Refus_avant_rouge") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-26_Refus_avant_rouge"
	for top in owners do
		top:Clone().Parent = f
	end
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : boutons de refus en rose-rouge d'Upgrades")
local ok, err = pcall(function()
	for _, b in found do
		paint(b)
		if b.Name == "NextButton" then -- SKIP du tuto : 33 px sur téléphone, au moins 44 px demandés
			local c = b:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
			c.MinSize = Vector2.new(math.max(c.MinSize.X, 142), math.max(c.MinSize.Y, 44)) -- 96 × 44 avec son rapport 2,2
			c.Parent = b
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
print("[ui_refus_rouge] repeints :\n" .. table.concat(lines, "\n"))
return #found .. " boutons de refus repeints"
