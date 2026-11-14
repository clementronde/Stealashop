--!strict
--[[
	tools/prod-check.luau : contrôle avant la publication en PROD (DEV-063, liaison L-032 et L-143)
	Mode d'emploi complet : docs/claude/notes/publication-prod.md, étape 3.

	À exécuter dans Studio, en mode Edit (barre de commande ou MCP execute_luau), sur une COPIE
	locale de la place DEV : Fichier > Enregistrer dans un fichier, puis ouvrir ce fichier. Jamais
	dans la session Team Create de la place DEV : un retrait y serait appliqué pour tout le monde,
	vitrine de Clément comprise.

	Rapport, toujours :
	  - dossiers de développement à retirer avant la PROD, avec leur nombre d'objets :
	    Workspace/_SHOWROOM_CLEMENT (vitrine des assets de Clément, L-032),
	    Workspace/_INBOX_CLEMENT (livraisons pas encore rangées),
	    Workspace/_SANDBOX_IRONIX (tests d'Ironix),
	    ServerStorage/_GREYBOX_REMPLACE (ancienne greybox rangée par Clément) ;
	  - packs piégés du Creator Store (L-143), cherchés dans toute la place, même hors du showroom :
	    « Aura Pack Premium By Sanzzzzz » et « THE ULTRA VFX AND PARTICLES PACK » ;
	  - scripts suspects, où qu'ils soient : Script « Runtime », LocalScript « ScreenBuilder »,
	    attribut DesactiveParClaude (scripts des packs désactivés le 2026-11-14), source qui contient
	    require(<numéro>), loadstring, getfenv/setfenv ou HttpService ;
	  - scripts rangés hors des dossiers de code (ServerScriptService/Server,
	    StarterPlayerScripts/Client, ReplicatedStorage/Shared, ReplicatedStorage/Packages) : seuls
	    les FX_<Nom> (Script, RunContext = Client) sont admis (CLAUDE.md), ils sont listés à part ;
	  - HttpService.HttpEnabled (doit être false : le jeu n'appelle aucun site) ;
	  - attributs de test laissés sur le Workspace (crochets réservés à Studio, inoffensifs en
	    ligne, mais à ne pas publier) ;
	  - rappel : la sortie du ContractChecker se lit en Play (aucune ligne rouge).
	Retrait : mettre RETIRER = true ci-dessous. Sont retirés les dossiers de développement, les
	packs piégés et les scripts suspects nommés Runtime ou ScreenBuilder. Les autres alertes
	(require d'un numéro, script hors des dossiers de code…) se regardent à la main : le script ne
	les supprime jamais seul. Il refuse si la place est publiée (game.PlaceId ~= 0) : un fichier
	ouvert depuis le disque a un PlaceId de 0. Un point d'historique est posé avant, Ctrl+Z annule.
	Jamais retirés : ServerStorage/AnimRigs et ServerStorage/RBX_ANIMSAVES, les rigs et brouillons
	d'animation de Clément (CLAUDE.md). Ils restent côté serveur, aucun joueur ne les reçoit.
	Ensuite : relancer avec RETIRER = false (rapport propre attendu), Play, puis
	Fichier > Publier sur Roblox sous… > la place PROD du groupe, puis fermer la copie.
]]

local RETIRER = false

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

-- Dossiers de développement, par conteneur (noms du contrat de la section 2.1 et de la liaison).
local DEV_FOLDERS: { { parent: Instance, name: string, why: string } } = {
	{ parent = Workspace, name = "_SHOWROOM_CLEMENT", why = "vitrine des assets de Clément (L-032)" },
	{ parent = Workspace, name = "_INBOX_CLEMENT", why = "livraisons pas encore rangées" },
	{ parent = Workspace, name = "_SANDBOX_IRONIX", why = "tests d'Ironix" },
	{ parent = ServerStorage, name = "_GREYBOX_REMPLACE", why = "ancienne greybox rangée" },
}

-- Packs du Creator Store aux scripts piégés (L-143), cherchés par nom dans toute la place.
local TRAPPED_PACKS = { "Aura Pack Premium By Sanzzzzz", "THE ULTRA VFX AND PARTICLES PACK" }

-- Noms des scripts du piège (L-143) : retirés avec RETIRER = true.
local TRAP_SCRIPT_NAMES: { [string]: string } = { Runtime = "Script", ScreenBuilder = "LocalScript" }

-- Motifs suspects dans une source (L-143 : HttpService active, puis require d'un numéro).
local SUSPECT_PATTERNS: { { pattern: string, why: string } } = {
	{ pattern = "require%s*%(%s*%d", why = "require d'un numéro (module chargé depuis le site)" },
	{ pattern = "loadstring", why = "loadstring" },
	{ pattern = "[gs]etfenv", why = "getfenv/setfenv" },
	{ pattern = "HttpService", why = "HttpService" },
	{ pattern = "HttpEnabled", why = "HttpEnabled" },
}

-- Attributs de test lus par le code en Studio seulement (NightCycleService, TruckEventService,
-- TutorialService, AntiCheatService, FortuneTowerService).
local TEST_ATTRIBUTES = { "AntiCheatStrict", "NightSkipTo", "TruckSpawnNow", "TutorialReset", "FortuneTest" }

-- Dossiers de code d'Ironix (Script Sync) et dépendances : leurs scripts sont attendus.
local CODE_ROOTS: { Instance } = {}
for _, pair in { { ServerScriptService, "Server" }, { ReplicatedStorage, "Shared" }, { ReplicatedStorage, "Packages" } } do
	local root = (pair[1] :: Instance):FindFirstChild(pair[2] :: string)
	if root then
		table.insert(CODE_ROOTS, root)
	end
end
local playerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local clientRoot = playerScripts and playerScripts:FindFirstChild("Client")
if clientRoot then
	table.insert(CODE_ROOTS, clientRoot)
end

local function inCodeRoot(inst: Instance): boolean
	for _, root in CODE_ROOTS do
		if inst:IsDescendantOf(root) then
			return true
		end
	end
	return false
end

local function readSource(inst: Instance): string?
	local ok, source = pcall(function()
		return (inst :: any).Source
	end)
	return if ok and type(source) == "string" then source else nil
end

local lines: { string } = {}
local found: { Instance } = {}
local toRemove: { Instance } = {}

-- 1. Dossiers de développement.
for _, entry in DEV_FOLDERS do
	local folder = entry.parent:FindFirstChild(entry.name)
	if folder then
		table.insert(found, folder)
		table.insert(lines, `À retirer : {folder:GetFullName()} ({#folder:GetDescendants()} objets, {entry.why})`)
	end
end
if #found == 0 then
	table.insert(lines, "Aucun dossier de développement : rien à retirer")
end

local function insideFound(inst: Instance): boolean
	for _, folder in found do
		if inst == folder or inst:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

-- 2. Packs piégés (L-143), dans toute la place.
local packCount = 0
for _, inst in game:GetDescendants() do
	if table.find(TRAPPED_PACKS, inst.Name) then
		packCount += 1
		local note = if insideFound(inst) then " (dans un dossier déjà retiré)" else ""
		table.insert(lines, `Pack piégé (L-143) : {inst:GetFullName()}{note}`)
		if not insideFound(inst) then
			table.insert(toRemove, inst)
		end
	end
end
if packCount == 0 then
	table.insert(lines, "Aucun pack piégé de L-143")
end

-- 3. Scripts : pièges, sources suspectes, scripts hors des dossiers de code.
local suspects, outside, fxScripts = 0, 0, 0
for _, inst in game:GetDescendants() do
	if not inst:IsA("LuaSourceContainer") then
		continue
	end
	local where = inst:GetFullName()
	local reasons: { string } = {}
	local expected = TRAP_SCRIPT_NAMES[inst.Name]
	if expected and inst.ClassName == expected then
		table.insert(reasons, `{expected} « {inst.Name} » du piège`)
		if not insideFound(inst) and not table.find(toRemove, inst) then
			table.insert(toRemove, inst)
		end
	end
	if inst:GetAttribute("DesactiveParClaude") ~= nil then
		table.insert(reasons, "désactivé par Claude (pack de L-143)")
	end
	if not inCodeRoot(inst) then
		local source = readSource(inst)
		if source then
			for _, p in SUSPECT_PATTERNS do
				if string.find(source, p.pattern) then
					table.insert(reasons, p.why)
				end
			end
		end
	end
	if #reasons > 0 then
		suspects += 1
		table.insert(lines, `Script suspect : {where} [{inst.ClassName}] : {table.concat(reasons, ", ")}`)
	elseif not inCodeRoot(inst) and not insideFound(inst) then
		local isFx = inst:IsA("Script") and string.sub(inst.Name, 1, 3) == "FX_"
			and (inst :: Script).RunContext == Enum.RunContext.Client
		if isFx then
			fxScripts += 1
			table.insert(lines, `Effet visuel admis : {where} (vérifier : décor unique, visuel seulement)`)
		else
			outside += 1
			table.insert(lines, `Script hors des dossiers de code : {where} [{inst.ClassName}] (à regarder, à retirer s'il ne sert pas)`)
		end
	end
end
if suspects == 0 then
	table.insert(lines, "Aucun script suspect (Runtime, ScreenBuilder, require d'un numéro, loadstring, HttpService)")
end
if outside == 0 then
	table.insert(lines, `Aucun script hors des dossiers de code ({fxScripts} effet(s) FX_ admis)`)
end

-- 4. HttpService : le jeu n'appelle aucun site.
if HttpService.HttpEnabled then
	table.insert(lines, "ALERTE : HttpService.HttpEnabled = true. Le couper (Paramètres du jeu > Sécurité) et chercher qui l'a activé (L-143)")
else
	table.insert(lines, "HttpService.HttpEnabled = false : bien")
end

-- 5. Attributs de test.
for _, name in TEST_ATTRIBUTES do
	local value = Workspace:GetAttribute(name)
	if value ~= nil then
		table.insert(lines, `Attribut de test sur le Workspace : {name} = {tostring(value)} (à effacer)`)
		if RETIRER and game.PlaceId == 0 then
			Workspace:SetAttribute(name, nil)
		end
	end
end

-- Retrait sur la copie locale.
for _, inst in toRemove do
	table.insert(found, inst)
end
if RETIRER and #found > 0 then
	if game.PlaceId ~= 0 then
		table.insert(lines, `Retrait refusé : place publiée (PlaceId {game.PlaceId}). Ouvre une copie locale (Fichier > Enregistrer dans un fichier)`)
	else
		ChangeHistoryService:SetWaypoint("Avant prod-check")
		local removed = 0
		for _, inst in found do
			if inst.Parent then
				inst:Destroy()
				removed += 1
			end
		end
		ChangeHistoryService:SetWaypoint("prod-check : dossiers de développement et pièges retirés")
		table.insert(lines, `{removed} objet(s) retiré(s) de la copie (dossiers, packs, scripts du piège). Ctrl+Z pour annuler`)
	end
end
table.insert(lines, "Reste à faire : relancer avec RETIRER = false (rapport propre), Play sur la copie, aucune ligne rouge du ContractChecker, puis publier sur la place PROD")

local report = table.concat(lines, "\n")
print(report)
return report
