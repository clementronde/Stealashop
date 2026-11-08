--!strict
--[[
	tools/prod-check.luau : contrôle avant la publication en PROD (DEV-063, liaison L-032)

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
	  - attributs de test laissés sur le Workspace (crochets réservés à Studio, inoffensifs en
	    ligne, mais à ne pas publier) ;
	  - rappel : la sortie du ContractChecker se lit en Play (aucune ligne rouge).
	Retrait : mettre RETIRER = true ci-dessous. Le script refuse si la place est publiée
	(game.PlaceId ~= 0) : un fichier ouvert depuis le disque a un PlaceId de 0. Un point
	d'historique est posé avant, Ctrl+Z annule.
	Jamais retirés : ServerStorage/AnimRigs et ServerStorage/RBX_ANIMSAVES, les rigs et brouillons
	d'animation de Clément (CLAUDE.md). Ils restent côté serveur, aucun joueur ne les reçoit.
	Ensuite : Fichier > Publier sur Roblox sous… > la place PROD du groupe, puis fermer la copie.
]]

local RETIRER = false

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Dossiers de développement, par conteneur (noms du contrat de la section 2.1 et de la liaison).
local DEV_FOLDERS: { { parent: Instance, name: string, why: string } } = {
	{ parent = Workspace, name = "_SHOWROOM_CLEMENT", why = "vitrine des assets de Clément (L-032)" },
	{ parent = Workspace, name = "_INBOX_CLEMENT", why = "livraisons pas encore rangées" },
	{ parent = Workspace, name = "_SANDBOX_IRONIX", why = "tests d'Ironix" },
	{ parent = ServerStorage, name = "_GREYBOX_REMPLACE", why = "ancienne greybox rangée" },
}

-- Attributs de test lus par le code en Studio seulement (NightCycleService, TruckEventService,
-- TutorialService, AntiCheatService).
local TEST_ATTRIBUTES = { "AntiCheatStrict", "NightSkipTo", "TruckSpawnNow", "TutorialReset" }

local lines: { string } = {}
local found: { Instance } = {}
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
for _, name in TEST_ATTRIBUTES do
	local value = Workspace:GetAttribute(name)
	if value ~= nil then
		table.insert(lines, `Attribut de test sur le Workspace : {name} = {tostring(value)} (à effacer)`)
		if RETIRER and game.PlaceId == 0 then
			Workspace:SetAttribute(name, nil)
		end
	end
end

if RETIRER and #found > 0 then
	if game.PlaceId ~= 0 then
		table.insert(lines, `Retrait refusé : place publiée (PlaceId {game.PlaceId}). Ouvre une copie locale (Fichier > Enregistrer dans un fichier)`)
	else
		ChangeHistoryService:SetWaypoint("Avant prod-check")
		for _, folder in found do
			folder:Destroy()
		end
		ChangeHistoryService:SetWaypoint("prod-check : dossiers de développement retirés")
		table.insert(lines, `{#found} dossier(s) retiré(s) de la copie. Ctrl+Z pour annuler`)
	end
end
table.insert(lines, "Reste à faire : Play sur la copie, aucune ligne rouge du ContractChecker, puis publier sur la place PROD")

local report = table.concat(lines, "\n")
print(report)
return report
