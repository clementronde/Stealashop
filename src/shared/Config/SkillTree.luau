--!strict
-- Arbre de compétences (liaison L-085 et L-096 point 2 ; note de Clément docs/claude/notes/ui-skilltree-pour-ironix.md ;
-- écran StarterGui/UI_SkillTree). Décision de Clément (2026-11-11) : il sort au lancement du MVP.
-- Prix et effets : Partie 2, section 2 (V0 du doc). Ce qui est marqué « V0 proposé, absent du doc » est à valider.
--
-- Contrat partagé entre le serveur (SkillTreeService) et le client (SkillTreeController) :
--   - sauvegarde : un niveau par Id (champ SkillTree du profil, comme Upgrades) ;
--   - le serveur pose sur le joueur l'attribut `Skill_<Id>` = niveau (0 si rien acheté), pour chaque Id ;
--   - remote BuySkill(id) (client -> serveur) : achète le niveau suivant de `id` ;
--   - une tuile est ouverte si OpensWhen est nil (les 6 autour de la tuile centrale) ou si la compétence
--     OpensWhen.Id a au moins le niveau OpensWhen.Level ;
--   - Coded = nombre de niveaux achetables aujourd'hui (effet codé) ; 0 = « Soon » : la tuile se voit, rien ne
--     s'achète. Un niveau au-delà de Coded est refusé par le serveur, même ouvert ;
--   - RequiresRebirth = n (L-173, vague 56, a183 ; V0, Clément valide) : tuile de l'anneau extérieur fermée tant
--     que le joueur n'a pas fait n renaissances (attribut `Rebirths` du Player, posé par RebirthService ; absent :
--     renaissance coupée, la tuile reste fermée). Règle commune au serveur et au client : SkillTree.NeedsRebirth.
--     Une tuile déjà achetée (niveau ≥ 1) n'est jamais refermée. Tableau proposé (List) : Curtain 1,
--     PotionTime 2, DoorGuard 3, Traps 4.
-- Labels[n] = texte de l'effet au niveau n (n = 0 possible : effet offert sans achat), pour Info.TileName
-- (« Glass ×2 ») et StatBox.NodeEffect (« ×2 ▶ ×3 »). Textes du jeu en anglais.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Features = require(script.Parent.Features)

export type SkillId =
	"Walls"
	| "GlassThickness"
	| "GlassRegen"
	| "Cameras"
	| "Bodyguards"
	| "PotionLuck"
	| "Curtain"
	| "DoorGuard"
	| "PotionTime"
	| "Traps"

export type Opens = { Id: SkillId, Level: number }

export type Skill = {
	Id: SkillId,
	Tile: string, -- tuile de UI_SkillTree.Tree
	OldTiles: { string }?, -- anciens noms de la même tuile, acceptés pendant un renommage annoncé (contrat 2.2)
	DisplayName: string, -- début de Info.TileName et de InfoPanel.Header.NodeName (en majuscules)
	Stat: string, -- InfoPanel.StatBox.NodeStat (V0 proposé, absent du doc)
	MaxLevel: number,
	Prices: { number }, -- Prices[n] = prix du niveau n ; vide = pas encore décidé
	Effects: { number }, -- Effects[n] = valeur au niveau n (voir chaque ligne)
	Labels: { [number]: string },
	Coded: number,
	OpensWhen: Opens?,
	RequiresRebirth: number?, -- renaissances faites pour ouvrir la tuile (L-173, V0) ; nil : aucune
	Icon: string?, -- rbxassetid de la note de Clément (l'image est déjà posée sur la tuile dans Studio)
}

local List: { Skill } = {
	{
		-- Murs de la boutique (décision de Clément du 2026-11-12, L-105 point 3 et L-106 point 2) : l'ancienne tuile
		-- ShopLevel (Partie 2 : Stand, Boutique…) devient Walls ; la boutique grandit toujours avec ses présentoirs
		-- (ShopStageService). L-163 (a159, 2026-11-14) : Walls ne touche plus aux coups de la porte (décor : la
		-- porte reste le seul passage) ; aucun effet en jeu, Effects vide. Prix : ceux de l'ancienne tuile Shop Level
		-- (Partie 2). Mur visible par niveau : ShopWallsService (attributs ShowFromWalls / HideFromWalls). Tuile
		-- d'UI : Tile_Walls, ou Tile_ShopLevel tant que Clément ne l'a pas renommée (OldTiles).
		Id = "Walls",
		Tile = "Tile_Walls",
		OldTiles = { "Tile_ShopLevel" },
		DisplayName = "Walls",
		Stat = "Shop walls", -- V0 (L-163)
		MaxLevel = 4,
		Prices = { 1_300, 8_300, 120_000, 1_600_000 }, -- V0 proposé (Cantin, 20/11), avant : { 10_000, 250_000, 6_250_000, 156_000_000 }
		Effects = {},
		Labels = { "I", "II", "III", "IV" },
		Coded = 4,
		Icon = "rbxassetid://89598496809365",
	},
	{
		-- « Reinforced Door » (L-163, correction de Clément du 2026-11-14 au soir ; V0) : Effects[n] = coups ajoutés
		-- à la porte de la boutique (PvP.DoorHits = 40), +8 par niveau, 80 coups au plus (16 s seul, 10 s en groupe,
		-- hors réparation). Avant : PV × 1,5 à × 8 (Partie 2).
		Id = "GlassThickness",
		Tile = "Tile_Glass",
		DisplayName = "Reinforced Door",
		Stat = "Door hits",
		MaxLevel = 5,
		Prices = { 1_900, 9_600, 88_000, 630_000, 6_000_000 }, -- V0 proposé (Cantin, 20/11), avant : { 25_000, 300_000, 4_000_000, 50_000_000, 600_000_000 }
		Effects = { 8, 16, 24, 32, 40 },
		Labels = { [0] = "40", "48", "56", "64", "72", "80" },
		Coded = 5,
		Icon = "rbxassetid://101463818389249",
	},
	{
		-- Effects[n] = réparation de la porte en part de son maximum par seconde (Partie 2 : base 3 %, +1 % par
		-- niveau). L-163 : comptée en coups (8 % de 80 = 6,4 coups par seconde), et
		-- seulement quand personne ne frappe depuis PvP.DoorRepairDelay (3) s (WindowService).
		Id = "GlassRegen",
		Tile = "Tile_GlassRegen",
		DisplayName = "Door Repair", -- V0 (L-163)
		Stat = "Door repair",
		MaxLevel = 5,
		Prices = { 2_600, 15_000, 100_000, 630_000, 5_000_000 }, -- V0 proposé (Cantin, 20/11), avant : { 50_000, 500_000, 5_000_000, 50_000_000, 500_000_000 }
		Effects = { 0.04, 0.05, 0.06, 0.07, 0.08 },
		Labels = { [0] = "3%/s", "4%/s", "5%/s", "6%/s", "7%/s", "8%/s" },
		Coded = 5,
		Icon = "rbxassetid://126487278824716",
	},
	{
		-- Partie 2 : N1 alerte dès le 1er coup sur la vitrine ; N2 voleur surligné à travers les murs 30 s ;
		-- N3 flèche, distance et son jusqu'au voleur. Effects[n] = durée du surlignage (s). a408 (vague GC6, L-163, V0 de
		-- L-175 : plus aucune flèche) : N3 = voleur surligné en rouge vif et son de radar qui accélère en approchant
		-- (CameraAlertController, Config/ShopDefense.CameraRadar), relancé quand il prend un objet (ShopDefenseService) ;
		-- achetable avec Features.CameraRadar (sinon 2 niveaux).
		Id = "Cameras",
		Tile = "Tile_Cameras",
		DisplayName = "Cameras",
		Stat = "Security",
		MaxLevel = 3,
		Prices = { 980, 5_300, 100_000 }, -- V0 proposé (Cantin, 20/11), avant : { 5_000, 150_000, 5_000_000 }
		Effects = { 0, 30, 30 },
		Labels = { "I", "II", "III" },
		Coded = if Features.CameraRadar then 3 else 2,
		Icon = "rbxassetid://130895616275969",
	},
	{
		-- Partie 2 (MAJ 3) : agent PNJ dans la boutique ; Effects[n] = sa vitesse (à l'échelle 1). a408 (vague GC6) :
		-- ShopDefenseService, Config/ShopDefense.Bodyguard ; achetable avec Features.Bodyguards (sinon « Soon »).
		Id = "Bodyguards",
		Tile = "Tile_Guards",
		DisplayName = "Guards",
		Stat = "Bodyguard speed",
		MaxLevel = 5,
		Prices = { 3_800, 49_000, 530_000, 7_900_000, 160_000_000 }, -- V0 proposé (Cantin, 20/11), avant : { 100_000, 2_000_000, 40_000_000, 800_000_000, 16_000_000_000 }
		Effects = { 20, 28, 36, 44, 52 },
		Labels = { "I", "II", "III", "IV", "V" },
		Coded = if Features.Bodyguards then 5 else 0,
		Icon = "rbxassetid://133701105676131",
	},
	{
		-- Potions (L-085, vague 28, PotionService). Effects[n] = facteur du délai entre deux apparitions de potions
		-- (Config/Potions.SpawnEvery × Effects[n]). Prix et effets : V0 proposés, absents du doc.
		Id = "PotionLuck",
		Tile = "Tile_PotionLuck",
		DisplayName = "Potion Luck",
		Stat = "Potion luck",
		MaxLevel = 3,
		Prices = { 1_700, 12_000, 150_000 }, -- V0 proposé (Cantin, 20/11), avant : { 20_000, 400_000, 8_000_000 }
		Effects = { 0.8, 0.65, 0.5 },
		Labels = { "I", "II", "III" },
		Coded = 3,
		Icon = "rbxassetid://82423065290603",
	},
	{
		-- L-163 (a159) : le rideau devient un verrou à la Brainrot (SkillTreeService, remote LockShop) : le
		-- propriétaire ferme sa boutique Lock.BaseDuration (30) s offertes, puis Effects[n] s ; ensuite
		-- Lock.Cooldown s de recharge. V0. Prix : ceux du rideau (Partie 2). Avant : rideau 30, 60, 90 s.
		Id = "Curtain",
		Tile = "Tile_Curtain",
		DisplayName = "Lock",
		Stat = "Lock time",
		MaxLevel = 2,
		Prices = { 2_600, 27_000 }, -- V0 proposé (Cantin, 20/11), avant : { 50_000, 1_000_000 }
		Effects = { 45, 60 },
		Labels = { [0] = "30s", "45s", "60s" },
		Coded = 2,
		OpensWhen = { Id = "GlassThickness", Level = 1 },
		RequiresRebirth = 1, -- V0 (L-173) : les 30 s offertes restent sans renaissance
		Icon = "rbxassetid://135129985966759",
	},
	{
		-- L-163 : « un garde à la porte qui repousse le voleur toutes les X s ». a408 (vague GC6) : Effects[1] = X (s) ;
		-- ShopDefenseService, Config/ShopDefense.DoorGuard ; achetable avec Features.DoorGuard (sinon « Soon »).
		Id = "DoorGuard",
		Tile = "Tile_DoorGuard",
		DisplayName = "Door Guard",
		Stat = "Push every", -- V0 proposé (Cantin, 23/11)
		MaxLevel = 1,
		Prices = { 530_000 }, -- V0 proposé (Cantin, 23/11) : le prix du niveau 3 de Guards
		Effects = { 4 }, -- V0 proposé (Cantin, 23/11) : une poussée toutes les 4 s au plus
		Labels = { "4s" },
		Coded = if Features.DoorGuard then 1 else 0,
		OpensWhen = { Id = "Bodyguards", Level = 1 },
		RequiresRebirth = 3, -- V0 (L-173)
		Icon = "rbxassetid://133701105676131",
	},
	{
		-- Potions (vague 28, PotionService). Effects[n] = facteur de la durée d'un effet de potion
		-- (Config/Potions, Duration × Effects[n]). Prix et effets : V0 proposés, absents du doc.
		Id = "PotionTime",
		Tile = "Tile_PotionTime",
		DisplayName = "Potion Time",
		Stat = "Potion time",
		MaxLevel = 2,
		Prices = { 3_800, 49_000 }, -- V0 proposé (Cantin, 20/11), avant : { 100_000, 2_000_000 }
		Effects = { 1.25, 1.5 },
		Labels = { "×1.25", "×1.5" },
		Coded = 2,
		OpensWhen = { Id = "PotionLuck", Level = 1 },
		RequiresRebirth = 2, -- V0 (L-173)
		Icon = "rbxassetid://102799696275335",
	},
	{
		-- Partie 2 (MAJ 4) : pièges derrière la vitrine. Ouvre à Walls 2 (Shop Level 2 du prototype de Clément).
		-- Vague 72 (a243, L-218 ; V0 à valider par Clément) : Effects[n] = pièges posés sur TrapSlot_01 à _0n
		-- (TrapService, genres de Config/Traps.SlotLayout) ; achetable seulement avec Features.Traps (sinon « Soon »).
		Id = "Traps",
		Tile = "Tile_Next1",
		DisplayName = "Traps",
		Stat = "Trap slots",
		MaxLevel = 4,
		Prices = { 27_000, 180_000, 1_100_000, 9_900_000 }, -- V0 proposé (Cantin, 20/11), avant : { 1_000_000, 10_000_000, 100_000_000, 1_000_000_000 }
		Effects = { 1, 2, 3, 4 },
		Labels = { [0] = "0", "1", "2", "3", "4" },
		Coded = if Features.Traps then 4 else 0,
		OpensWhen = { Id = "Walls", Level = 2 },
		RequiresRebirth = 4, -- V0 (L-173)
	},
}

local ById: { [string]: Skill } = {}
for _, skill in List do
	ById[skill.Id] = skill
end

-- Anciens Id sauvegardés dans des profils, relus sous le nouvel Id au chargement (SkillTreeService ; migration
-- douce, sans changer la version du profil).
local Renamed: { [string]: SkillId } = {
	ShopLevel = "Walls", -- L-105 point 3 (2026-11-12)
}

-- Compétences retirées (vague 54, a176) : [ancien Id] = son ancienne tuile. Un niveau sauvegardé sous cet Id est
-- ignoré sans avertissement au chargement (SkillTreeService, pas de remboursement) ; la tuile, si elle est encore
-- dans UI_SkillTree, est cachée par SkillTreeController. Safe : le coffre-fort n'existe plus (Cantin, 2026-11-15).
local Removed: { [string]: string } = {
	Safe = "Tile_Next4",
}

-- Visuels de la boutique liés à une compétence (règle de Cantin du 2026-11-13) : cachés tant que le propriétaire
-- n'a pas Level dans Id, quel que soit le niveau de la boutique (ShopWallsService). Reconnus par le nom de la pièce
-- (n'importe où dans la parcelle, copies Stage_j comprises) ; une pièce peut aussi porter l'attribut
-- ShowFromSkill = "<Id>" ou "<Id> <niveau>" (ex. "Cameras", "Cameras 2"), qui passe avant son nom.
--   Cameras : Stage_5/Cameras du gabarit PLOT_Shop (5 caméras de Clément, décor du niveau 5 avant l'arbre).
--   Security et Alarm : Stage_5/Security (le digicode) et Stage_5/Alarm (le gyrophare), avec Cameras 1 comme les
--     caméras (Clément, 2026-11-14, L-137 point 1).
--   Walls : Stage_3/Walls (murs pleins et vitrines de façade), avec Walls 1 (Clément, 2026-11-14, L-137 point 3 :
--     les murs suivent la tuile Walls, pas le niveau de la boutique).
-- EveryStage = true : la pièce ne dépend pas du niveau de la boutique. Tant que la boutique est sous le niveau du
-- Stage_j qui la contient dans le gabarit, ShopStageService en pose une copie à part (dossier SkillVisuals de la
-- boutique), cachée ou montrée par ShopWallsService comme les autres ; à partir de ce niveau, c'est celle du
-- Stage_j copié.
export type PlotVisual = { Id: SkillId, Level: number, EveryStage: boolean? }
local PlotVisuals: { [string]: PlotVisual } = {
	Cameras = { Id = "Cameras", Level = 1 },
	Security = { Id = "Cameras", Level = 1 },
	Alarm = { Id = "Cameras", Level = 1 },
	-- Vague 42 (L-150 point 5, réponse (c) de Clément) : plus d'EveryStage, les murs ne se voient qu'à partir du
	-- niveau 3 de la boutique (avec Stage_3) ; Walls n'a plus d'effet en jeu sur la porte depuis L-163. EveryStage reste prêt pour des murs à la taille des niveaux 1 et 2 (réponse (a), plus tard).
	Walls = { Id = "Walls", Level = 1 },
}

-- Renaissances faites, lues dans l'attribut `Rebirths` du Player : entier ≥ 0, ou nil (attribut absent ou
-- illisible : renaissance coupée).
local function rebirthsOf(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return nil
	end
	return math.floor(value)
end

-- La renaissance qui ferme encore la tuile (L-173), ou nil si aucune ne la ferme. `level` = niveau acheté,
-- `rebirths` = renaissances faites (nil : renaissance coupée, toute tuile à renaissance est fermée). Une tuile
-- déjà achetée (niveau ≥ 1) reste ouverte : rien de ce qu'un joueur a acheté n'est retiré.
local function needsRebirth(skill: Skill, level: number, rebirths: number?): number?
	local needed = skill.RequiresRebirth
	if needed == nil or level >= 1 or (rebirths ~= nil and rebirths >= needed) then
		return nil
	end
	return needed
end

-- Les compétences que la renaissance numéro `rebirth` ouvre, dans l'ordre de List.
local function unlockedBy(rebirth: number): { Skill }
	local list: { Skill } = {}
	for _, skill in List do
		if skill.RequiresRebirth == rebirth then
			table.insert(list, skill)
		end
	end
	return list
end

-- Base sans achat : réparation Balance (RegenPerSecond, 3 %).
local SkillTree = {
	List = List,
	ById = ById,
	Renamed = Renamed,
	Removed = Removed,
	-- Mur visible de la boutique (ShopWallsService) : attribut de la parcelle et attributs des pièces de Clément.
	WallsLevelAttribute = "WallsLevel",
	ShowFromWalls = "ShowFromWalls",
	HideFromWalls = "HideFromWalls",
	ShowFromSkill = "ShowFromSkill", -- attribut d'une pièce de la parcelle (voir PlotVisuals)
	PlotVisuals = PlotVisuals,
	SkillVisualsFolder = "SkillVisuals", -- dossier de la boutique : copies EveryStage (V0 proposé, absent du doc)
	AttributePrefix = "Skill_", -- attribut Skill_<Id> du joueur, posé par le serveur
	-- Verrou de la boutique (tuile Curtain, L-163, V0) : durée offerte sans achat, recharge après la fin du verrou,
	-- et attribut de la parcelle (heure serveur de la fin du verrou ; absent = ouverte) lu par les clients.
	Lock = {
		BaseDuration = 30,
		Cooldown = 120,
		UntilAttribute = "LockedUntil",
		ReadyAttribute = "LockReadyAt", -- attribut du Player : heure serveur où le verrou se recharge
	},
	RootTile = "RootTile", -- tuile centrale « UPGRADES » : rien ne s'y achète
	NeverTile = "Tile_Next2", -- « ??? » qui ne s'ouvre jamais (maquette de Clément)
	-- Tuiles à renaissance (L-173, a183 ; noms proposés par Clément le 2026-11-15, adoptés ; facultatifs).
	RebirthsAttribute = "Rebirths", -- attribut du Player (RebirthService) : renaissances faites ; absent = coupée
	RequiresRebirthAttribute = "RequiresRebirth", -- attribut de la tuile, posé en jeu par SkillTreeController (Config fait foi)
	RebirthLayer = "RebirthLocked", -- calque de la tuile, à côté de Bought, Available et Locked
	RebirthLockedName = "LockedName", -- dans RebirthLocked : RebirthNameText (« REBIRTH 1 »)
	RebirthLockedLabel = "LockedLabel", -- dans RebirthLocked : RebirthLabelText (« TO UNLOCK »)
	RebirthNameText = "REBIRTH %d", -- maquette de Clément
	RebirthLabelText = "TO UNLOCK",
	-- Renaissance coupée (Features.Rebirth = false, lancement) : true, les tuiles à renaissance sont cachées
	-- (aucune promesse que le joueur ne peut pas tenir) ; false, montrées verrouillées. V0, à valider par Cantin.
	HideWhenRebirthOff = true,
	RebirthsOf = rebirthsOf,
	NeedsRebirth = needsRebirth,
	UnlockedBy = unlockedBy,
}

export type SkillTree = typeof(SkillTree)

return DeepFreeze(SkillTree)
