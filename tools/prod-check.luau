--!strict
--[[
	tools/prod-check.luau : contrôle avant la publication en PROD (DEV-063, liaison L-032 et L-143 ;
	check-up a417, M1, R16, R17, R18, R22, R23)
	Mode d'emploi complet : docs/claude/notes/publication-prod.md, étape 4.

	À exécuter dans Studio, en mode Edit (barre de commande ou MCP execute_luau), sur une COPIE
	locale de la place DEV : Fichier > Enregistrer dans un fichier, puis ouvrir ce fichier. Jamais
	dans la session Team Create de la place DEV : un retrait y serait appliqué pour tout le monde,
	vitrine de Clément comprise.

	Rapport, toujours :
	  - dossiers de travail à retirer avant la PROD, règle par règle, avec leur nombre d'objets :
	      1. tout enfant de Workspace dont le nom commence par « _ » (_SHOWROOM_CLEMENT, _INBOX_CLEMENT,
	         _SANDBOX_IRONIX, _PROTO_*, _BENCH_*, _PREVIEW_*, _APERCU_*, _EXEMPLE_STUDS…, R16) ;
	      2. tout enfant de ServerStorage dont le nom commence par « _ » (_GREYBOX_REMPLACE,
	         _BENCH_AURAS, _UI_RETIREE, _HUB_RETIRE, _ARBRES_REMPLACES…, R17) ;
	      3. ServerStorage/MapBackups (sauvegardes de la map, R18) ;
	      4. ServerStorage/Assets/MapBackup_* et ServerStorage/Assets/_Sauvegarde_* (R18) ;
	      5. FX_Auras_Import et FX_Eclair_Cloud (imports bruts d'effets), à la racine de ServerStorage,
	         de ServerStorage/Assets, de ReplicatedStorage ou du Workspace ;
	      6. ReplicatedStorage/GuiAnimatorPlugin (restes d'un plugin, R22) ;
	      7. tout enfant de TestService (LuauLSP_Settings…, R23) ;
	  - packs piégés du Creator Store (L-143), cherchés dans toute la place, même hors des dossiers :
	    « Aura Pack Premium By Sanzzzzz » et « THE ULTRA VFX AND PARTICLES PACK » ;
	  - scripts suspects, où qu'ils soient : Script « Runtime », LocalScript « ScreenBuilder »,
	    attribut DesactiveParClaude (scripts des packs désactivés le 2026-11-14), source qui contient
	    require(<numéro>), loadstring, getfenv/setfenv ou HttpService ;
	  - scripts rangés hors des dossiers de code (ServerScriptService/Server,
	    StarterPlayerScripts/Client, ReplicatedStorage/Shared, ReplicatedStorage/Packages) : seuls
	    les FX_<Nom> (Script, RunContext = Client) sont admis (CLAUDE.md), ils sont listés à part ;
	  - HttpService.HttpEnabled (doit être false : le jeu n'appelle aucun site) ;
	  - attributs de test laissés sur le Workspace : tout nom qui finit par Test, Debug, Now, SkipTo
	    ou Reset, plus AntiCheatStrict (crochets réservés à Studio, inoffensifs en ligne, mais à ne
	    pas publier) ;
	  - un bilan : nombre d'objets trouvés (puis retirés) par règle ;
	  - rappel : la sortie du ContractChecker se lit en Play (aucune ligne rouge).
	Retrait : mettre RETIRER = true ci-dessous. Sont retirés les dossiers de travail des règles 1 à 7,
	les packs piégés, les scripts du piège nommés Runtime ou ScreenBuilder et les attributs de test.
	Les autres alertes (require d'un numéro, script hors des dossiers de code…) se regardent à la
	main : le script ne les supprime jamais seul. Il refuse si la place est publiée
	(game.PlaceId ~= 0) : un fichier ouvert depuis le disque a un PlaceId de 0. Un point
	d'historique est posé avant, Ctrl+Z annule.
	Jamais retirés : ServerStorage/AnimRigs et ServerStorage/RBX_ANIMSAVES, les rigs et brouillons
	d'animation de Clément (CLAUDE.md), ni rien dans les dossiers de code. Ils restent côté serveur,
	aucun joueur ne les reçoit.
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
local TestService = game:GetService("TestService")
local Workspace = game:GetService("Workspace")

-- Jamais retirés, même s'ils tombent sous une règle (CLAUDE.md : rigs et brouillons de Clément).
local PROTECTED: { Instance } = {}
for _, name in { "AnimRigs", "RBX_ANIMSAVES" } do
	local inst = ServerStorage:FindFirstChild(name)
	if inst then
		table.insert(PROTECTED, inst)
	end
end

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

-- Attributs de test lus par le code en Studio seulement, tous sur le Workspace (SkillTest,
-- PotionTest, TruckSpawnNow, NightSkipTo, TutorialReset, ChaseDebug…) : reconnus par leur suffixe.
-- Vérifié le 2026-11-24 : aucun attribut de jeu de src/ ne finit ainsi. Un attribut de jeu nouveau
-- ne doit pas prendre un de ces suffixes.
local TEST_SUFFIXES = { "Test", "Debug", "Now", "SkipTo", "Reset" }
-- Attributs de test sans ces suffixes (AntiCheatService).
local TEST_ATTRIBUTES = { "AntiCheatStrict" }

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

local function isProtected(inst: Instance): boolean
	for _, keep in PROTECTED do
		-- protégé lui-même, dedans, ou le contenant (retirer le parent emporterait les rigs)
		if inst == keep or inst:IsDescendantOf(keep) or keep:IsDescendantOf(inst) then
			return true
		end
	end
	return inCodeRoot(inst)
end

local function readSource(inst: Instance): string?
	local ok, source = pcall(function()
		return (inst :: any).Source
	end)
	return if ok and type(source) == "string" then source else nil
end

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

local function endsWith(text: string, suffix: string): boolean
	return #text > #suffix and string.sub(text, -#suffix) == suffix
end

local lines: { string } = {}
-- Objets à retirer, chacun avec sa règle ; bilan par règle (objets = l'objet et ses descendants).
type Rule = { label: string, roots: number, objects: number, removed: number }
local rules: { Rule } = {}
local toRemove: { { inst: Instance, rule: Rule } } = {}

local function newRule(label: string): Rule
	local rule: Rule = { label = label, roots = 0, objects = 0, removed = 0 }
	table.insert(rules, rule)
	return rule
end

local function insideRemoved(inst: Instance): boolean
	for _, entry in toRemove do
		if inst == entry.inst or inst:IsDescendantOf(entry.inst) then
			return true
		end
	end
	return false
end

local function mark(inst: Instance, rule: Rule, why: string)
	if insideRemoved(inst) then
		return
	end
	if isProtected(inst) then
		table.insert(lines, `Gardé (protégé) : {inst:GetFullName()} (règle « {rule.label} »)`)
		return
	end
	local count = 1 + #inst:GetDescendants()
	rule.roots += 1
	rule.objects += count
	table.insert(toRemove, { inst = inst, rule = rule })
	table.insert(lines, `À retirer : {inst:GetFullName()} ({count} objets, {why})`)
end

-- 1. Dossiers de travail.
local ruleWorkspace = newRule("Workspace/_*")
for _, child in Workspace:GetChildren() do
	if startsWith(child.Name, "_") then
		mark(child, ruleWorkspace, "dossier de travail du Workspace")
	end
end
local ruleServerStorage = newRule("ServerStorage/_*")
for _, child in ServerStorage:GetChildren() do
	if startsWith(child.Name, "_") then
		mark(child, ruleServerStorage, "dossier de travail de ServerStorage")
	end
end
local ruleBackups = newRule("ServerStorage/MapBackups")
local mapBackups = ServerStorage:FindFirstChild("MapBackups")
if mapBackups then
	mark(mapBackups, ruleBackups, "sauvegardes de la map")
end
local ruleAssetBackups = newRule("ServerStorage/Assets/MapBackup_* et _Sauvegarde_*")
local serverAssets = ServerStorage:FindFirstChild("Assets")
if serverAssets then
	for _, child in serverAssets:GetChildren() do
		if startsWith(child.Name, "MapBackup_") or startsWith(child.Name, "_Sauvegarde_") then
			mark(child, ruleAssetBackups, "sauvegarde rangée dans les assets")
		end
	end
end
local ruleFxImports = newRule("FX_Auras_Import, FX_Eclair_Cloud")
local fxParents: { Instance } = { ServerStorage, ReplicatedStorage, Workspace }
if serverAssets then
	table.insert(fxParents, serverAssets)
end
for _, parent in fxParents do
	for _, name in { "FX_Auras_Import", "FX_Eclair_Cloud" } do
		local inst = parent:FindFirstChild(name)
		if inst then
			mark(inst, ruleFxImports, "import brut d'effets")
		end
	end
end
local rulePlugin = newRule("ReplicatedStorage/GuiAnimatorPlugin")
local guiPlugin = ReplicatedStorage:FindFirstChild("GuiAnimatorPlugin")
if guiPlugin then
	mark(guiPlugin, rulePlugin, "restes d'un plugin, envoyés à chaque joueur")
end
local ruleTestService = newRule("TestService/*")
for _, child in TestService:GetChildren() do
	mark(child, ruleTestService, "réglages d'outils de développement")
end
if #toRemove == 0 then
	table.insert(lines, "Aucun dossier de travail : rien à retirer")
end

-- 2. Packs piégés (L-143), dans toute la place.
local rulePacks = newRule("Packs piégés (L-143)")
local packCount = 0
for _, inst in game:GetDescendants() do
	if table.find(TRAPPED_PACKS, inst.Name) then
		packCount += 1
		if insideRemoved(inst) then
			table.insert(lines, `Pack piégé (L-143) : {inst:GetFullName()} (dans un dossier déjà retiré)`)
		else
			mark(inst, rulePacks, "pack piégé de L-143")
		end
	end
end
if packCount == 0 then
	table.insert(lines, "Aucun pack piégé de L-143")
end

-- 3. Scripts : pièges, sources suspectes, scripts hors des dossiers de code.
local ruleTrapScripts = newRule("Scripts du piège (Runtime, ScreenBuilder)")
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
		mark(inst, ruleTrapScripts, "script du piège de L-143")
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
	elseif not inCodeRoot(inst) and not insideRemoved(inst) then
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

-- 5. Attributs de test (suffixes, plus la liste à part).
local function isTestAttribute(name: string): boolean
	if table.find(TEST_ATTRIBUTES, name) then
		return true
	end
	for _, suffix in TEST_SUFFIXES do
		if endsWith(name, suffix) then
			return true
		end
	end
	return false
end

local canRemove = RETIRER and game.PlaceId == 0
local testAttributes: { string } = {}
for name in Workspace:GetAttributes() do
	if isTestAttribute(name) then
		table.insert(testAttributes, name)
	end
end
table.sort(testAttributes)
for _, name in testAttributes do
	table.insert(lines, `Attribut de test sur le Workspace : {name} = {tostring(Workspace:GetAttribute(name))} (à effacer)`)
end
if #testAttributes == 0 then
	table.insert(lines, "Aucun attribut de test sur le Workspace")
end

-- Retrait sur la copie locale.
local attributesRemoved = 0
if RETIRER and (#toRemove > 0 or #testAttributes > 0) then
	if not canRemove then
		table.insert(lines, `Retrait refusé : place publiée (PlaceId {game.PlaceId}). Ouvre une copie locale (Fichier > Enregistrer dans un fichier)`)
	else
		ChangeHistoryService:SetWaypoint("Avant prod-check")
		for _, entry in toRemove do
			if entry.inst.Parent then
				entry.rule.removed += 1 + #entry.inst:GetDescendants()
				entry.inst:Destroy()
			end
		end
		for _, name in testAttributes do
			Workspace:SetAttribute(name, nil)
			attributesRemoved += 1
		end
		ChangeHistoryService:SetWaypoint("prod-check : dossiers de travail, pièges et attributs de test retirés")
	end
end

-- Bilan par règle.
local verb = if canRemove then "retirés" else "à retirer"
table.insert(lines, `Bilan ({verb}) :`)
local totalRoots, totalObjects = 0, 0
for _, rule in rules do
	local objects = if canRemove then rule.removed else rule.objects
	totalRoots += rule.roots
	totalObjects += objects
	table.insert(lines, `  {rule.label} : {rule.roots} dossier(s) ou objet(s), {objects} objets en tout`)
end
local attributesCount = if canRemove then attributesRemoved else #testAttributes
table.insert(lines, `  Attributs de test du Workspace : {attributesCount}`)
table.insert(lines, `  Total : {totalRoots} racine(s), {totalObjects} objets, {attributesCount} attribut(s)`)
if canRemove and (totalObjects > 0 or attributesCount > 0) then
	table.insert(lines, "Ctrl+Z pour annuler le retrait")
end
table.insert(lines, "Reste à faire : relancer avec RETIRER = false (rapport propre), Play sur la copie, aucune ligne rouge du ContractChecker, puis publier sur la place PROD")

local report = table.concat(lines, "\n")
print(report)
return report
