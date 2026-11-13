--!strict
-- Arbre de compétences (liaison L-085 et L-096 point 2 ; note de Clément docs/claude/notes/ui-skilltree-pour-ironix.md ;
-- écran StarterGui/UI_SkillTree). Décision de Clément (2026-11-11) : il sort au lancement du 18 décembre.
-- Prix et effets : Partie 2, section 2 (V0 du doc). Ce qui est marqué « V0 proposé, absent du doc » est à valider.
--
-- Contrat partagé entre le serveur (SkillTreeService) et le client (SkillTreeController) :
--   - sauvegarde : un niveau par Id (champ SkillTree du profil, comme Upgrades) ;
--   - le serveur pose sur le joueur l'attribut `Skill_<Id>` = niveau (0 si rien acheté), pour chaque Id ;
--   - remote BuySkill(id) (client -> serveur) : achète le niveau suivant de `id` ;
--   - une tuile est ouverte si OpensWhen est nil (les 6 autour de la tuile centrale) ou si la compétence
--     OpensWhen.Id a au moins le niveau OpensWhen.Level ;
--   - Coded = nombre de niveaux achetables aujourd'hui (effet codé) ; 0 = « Soon » : la tuile se voit, rien ne
--     s'achète. Un niveau au-delà de Coded est refusé par le serveur, même ouvert.
-- Labels[n] = texte de l'effet au niveau n (n = 0 possible : effet offert sans achat), pour Info.TileName
-- (« Glass ×2 ») et StatBox.NodeEffect (« ×2 ▶ ×3 »). Textes du jeu en anglais.

local DeepFreeze = require(script.Parent.DeepFreeze)

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
	| "Safe"

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
	Icon: string?, -- rbxassetid de la note de Clément (l'image est déjà posée sur la tuile dans Studio)
}

local List: { Skill } = {
	{
		-- Murs de la boutique (décision de Clément du 2026-11-12, L-105 point 3 et L-106 point 2) : l'ancienne tuile
		-- ShopLevel (Partie 2 : Stand, Boutique…) devient Walls ; la boutique grandit toujours avec ses présentoirs
		-- (ShopStageService). Effects[n] = multiplicateur des PV de la porte de la boutique : c'est la vitre
		-- PlotDoor/Window, la même barre que Glass (les deux se multiplient). Effets : V0 proposés, absents du doc ;
		-- prix : ceux de l'ancienne tuile Shop Level (Partie 2). Mur visible par niveau : ShopWallsService
		-- (attributs ShowFromWalls / HideFromWalls). Tuile d'UI : Tile_Walls, ou Tile_ShopLevel tant que Clément
		-- ne l'a pas renommée (OldTiles).
		Id = "Walls",
		Tile = "Tile_Walls",
		OldTiles = { "Tile_ShopLevel" },
		DisplayName = "Walls",
		Stat = "Door HP",
		MaxLevel = 4,
		Prices = { 10_000, 250_000, 6_250_000, 156_000_000 },
		Effects = { 1.25, 1.5, 2, 3 },
		Labels = { [0] = "×1", "×1.25", "×1.5", "×2", "×3" },
		Coded = 4,
		Icon = "rbxassetid://89598496809365",
	},
	{
		-- Effects[n] = multiplicateur des PV de la vitrine de la boutique (Partie 2 : ×1,5, ×2, ×3, ×5, ×8).
		Id = "GlassThickness",
		Tile = "Tile_Glass",
		DisplayName = "Glass",
		Stat = "Window HP",
		MaxLevel = 5,
		Prices = { 25_000, 300_000, 4_000_000, 50_000_000, 600_000_000 },
		Effects = { 1.5, 2, 3, 5, 8 },
		Labels = { [0] = "×1", "×1.5", "×2", "×3", "×5", "×8" },
		Coded = 5,
		Icon = "rbxassetid://101463818389249",
	},
	{
		-- Effects[n] = réparation de la vitrine en part de ses PV par seconde (Partie 2 : base 3 %, +1 % par niveau).
		Id = "GlassRegen",
		Tile = "Tile_GlassRegen",
		DisplayName = "Glass Regen",
		Stat = "Window repair",
		MaxLevel = 5,
		Prices = { 50_000, 500_000, 5_000_000, 50_000_000, 500_000_000 },
		Effects = { 0.04, 0.05, 0.06, 0.07, 0.08 },
		Labels = { [0] = "3%/s", "4%/s", "5%/s", "6%/s", "7%/s", "8%/s" },
		Coded = 5,
		Icon = "rbxassetid://126487278824716",
	},
	{
		-- Partie 2 : N1 alerte dès le 1er coup sur la vitrine ; N2 voleur surligné à travers les murs 30 s ;
		-- N3 flèche, distance et son jusqu'au voleur (pas encore codé). Effects[2] = durée du surlignage (s).
		Id = "Cameras",
		Tile = "Tile_Cameras",
		DisplayName = "Cameras",
		Stat = "Security",
		MaxLevel = 3,
		Prices = { 5_000, 150_000, 5_000_000 },
		Effects = { 0, 30, 30 },
		Labels = { "I", "II", "III" },
		Coded = 2,
		Icon = "rbxassetid://130895616275969",
	},
	{
		-- Partie 2 (MAJ 3) : agent PNJ dans la boutique ; Effects[n] = sa vitesse. Pas encore codé.
		Id = "Bodyguards",
		Tile = "Tile_Guards",
		DisplayName = "Guards",
		Stat = "Bodyguard speed",
		MaxLevel = 5,
		Prices = { 100_000, 2_000_000, 40_000_000, 800_000_000, 16_000_000_000 },
		Effects = { 20, 28, 36, 44, 52 },
		Labels = { "I", "II", "III", "IV", "V" },
		Coded = 0,
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
		Prices = { 20_000, 400_000, 8_000_000 },
		Effects = { 0.8, 0.65, 0.5 },
		Labels = { "I", "II", "III" },
		Coded = 3,
		Icon = "rbxassetid://82423065290603",
	},
	{
		-- Partie 2 : rideau 30 s offert, 60 s pour 50 K $, 90 s pour 1 M $ ; bouton dans la boutique (modèle à venir).
		Id = "Curtain",
		Tile = "Tile_Curtain",
		DisplayName = "Curtain",
		Stat = "Curtain time",
		MaxLevel = 2,
		Prices = { 50_000, 1_000_000 },
		Effects = { 60, 90 },
		Labels = { [0] = "30s", "60s", "90s" },
		Coded = 0,
		OpensWhen = { Id = "GlassThickness", Level = 1 },
		Icon = "rbxassetid://135129985966759",
	},
	{
		Id = "DoorGuard",
		Tile = "Tile_DoorGuard",
		DisplayName = "Door Guard",
		Stat = "Door guard",
		MaxLevel = 1,
		Prices = {},
		Effects = {},
		Labels = {},
		Coded = 0,
		OpensWhen = { Id = "Bodyguards", Level = 1 },
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
		Prices = { 100_000, 2_000_000 },
		Effects = { 1.25, 1.5 },
		Labels = { "×1.25", "×1.5" },
		Coded = 2,
		OpensWhen = { Id = "PotionLuck", Level = 1 },
		Icon = "rbxassetid://102799696275335",
	},
	{
		-- Partie 2 (MAJ 4) : pièges derrière la vitrine. Ouvre à Walls 2 (Shop Level 2 du prototype de Clément).
		Id = "Traps",
		Tile = "Tile_Next1",
		DisplayName = "Traps",
		Stat = "Trap slots",
		MaxLevel = 1,
		Prices = {},
		Effects = {},
		Labels = {},
		Coded = 0,
		OpensWhen = { Id = "Walls", Level = 2 },
	},
	{
		-- Partie 2 : coffre-fort, présentoirs non volables (1 offert dès le MVP), +1 à 250 K $, +1 à 25 M $.
		-- Effects[n] = présentoirs protégés en plus de celui offert.
		Id = "Safe",
		Tile = "Tile_Next4",
		DisplayName = "Safe",
		Stat = "Protected stands",
		MaxLevel = 2,
		Prices = { 250_000, 25_000_000 },
		Effects = { 1, 2 },
		Labels = { [0] = "1", "2", "3" },
		Coded = 2,
		OpensWhen = { Id = "GlassRegen", Level = 1 },
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

-- Visuels de la boutique liés à une compétence (règle de Cantin du 2026-11-13) : cachés tant que le propriétaire
-- n'a pas Level dans Id, quel que soit le niveau de la boutique (ShopWallsService). Reconnus par le nom de la pièce
-- (n'importe où dans la parcelle, copies Stage_j comprises) ; une pièce peut aussi porter l'attribut
-- ShowFromSkill = "<Id>" ou "<Id> <niveau>" (ex. "Cameras", "Cameras 2"), qui passe avant son nom.
--   Cameras : Stage_5/Cameras du gabarit PLOT_Shop (5 caméras de Clément, décor du niveau 5 avant l'arbre).
export type PlotVisual = { Id: SkillId, Level: number }
local PlotVisuals: { [string]: PlotVisual } = {
	Cameras = { Id = "Cameras", Level = 1 },
}

-- Base sans achat : réparation Balance (RegenPerSecond, 3 %) et coffre-fort offert Config/PvP.VaultSlots (1).
local SkillTree = {
	List = List,
	ById = ById,
	Renamed = Renamed,
	-- Mur visible de la boutique (ShopWallsService) : attribut de la parcelle et attributs des pièces de Clément.
	WallsLevelAttribute = "WallsLevel",
	ShowFromWalls = "ShowFromWalls",
	HideFromWalls = "HideFromWalls",
	ShowFromSkill = "ShowFromSkill", -- attribut d'une pièce de la parcelle (voir PlotVisuals)
	PlotVisuals = PlotVisuals,
	AttributePrefix = "Skill_", -- attribut Skill_<Id> du joueur, posé par le serveur
	RootTile = "RootTile", -- tuile centrale « UPGRADES » : rien ne s'y achète
	NeverTile = "Tile_Next2", -- « ??? » qui ne s'ouvre jamais (maquette de Clément)
}

export type SkillTree = typeof(SkillTree)

return DeepFreeze(SkillTree)
