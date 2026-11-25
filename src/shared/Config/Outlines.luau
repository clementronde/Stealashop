--!strict
-- Contours « façon BD » (a446 ; liaison L-305 et L-344, Clément 23/11 et 24/11) : un contour fin, de la couleur de nos
-- icônes, sur tout ce qui est interactif et seulement là, blanc sur l'élément dont l'invite est affichée. Lu par
-- OutlineController (client), ShelfBoxController (client : il laisse les colis à OutlineController quand c'est allumé).
--
-- Interrupteurs : Features.BdOutlines (partout, PROD compris) et Features.BdOutlinesDev (jeu DEV seulement,
-- Config/ProductIds.IsDev). Enabled ci-dessous = l'un ou l'autre. Coupé : rien ne change (contours des colis de
-- ShelfBoxController, 20 au plus, comme avant).
--
-- Aspect : copié des deux Highlight modèles de Clément, ReplicatedStorage/Assets/FX/FX_Outline et FX_OutlineFocus
-- (Contract/Models.Outline) : OutlineColor, OutlineTransparency, FillColor, FillTransparency, DepthMode. Clément change
-- l'aspect sans toucher au code. Un modèle absent : l'aspect de secours (Fallback, les valeurs livrées par Clément le
-- 23/11, L-305 point 2) et une ligne dans la sortie.
--
-- Origine de chaque valeur, notée en commentaire :
--   L-305       valeur écrite dans la liaison (V0 proposés par Ironix, validés par Clément) ;
--   V0          V0 proposé, absent du doc, à régler en jeu.
-- Unités : studs, secondes.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Module de Config chargé s'il est là (bancs à liste de modules fixe), comme Config/Items.
local function optional(name: string): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild(name)
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end
local Features: any = optional("Features")
local ProductIds: any = optional("ProductIds")

local Outlines = {
	-- Allumé partout (BdOutlines) ou dans le jeu DEV seulement (BdOutlinesDev et ProductIds.IsDev).
	Enabled = Features.BdOutlines == true or (Features.BdOutlinesDev == true and ProductIds.IsDev == true),

	-- Modèles de Clément, dans ReplicatedStorage/Assets/<FxFolder> (L-305 point 2 ; contrat : Contract/Models.Outline).
	FxFolder = "FX",
	Template = "FX_Outline",
	FocusTemplate = "FX_OutlineFocus",

	-- Règle « dynamique » (L-305 point 4) : FX_Outline sur les éléments de la liste à MaxDistance studs au plus de la
	-- caméra, sur les MaxOutlines plus proches au plus. C'est aussi la taille de la réserve : MaxOutlines Highlight
	-- créés une fois au départ, jamais plus (Roblox : 255 Highlight au plus par client, un Highlight éteint garde sa
	-- place). L'élément dont l'invite est affichée passe avant les autres, même au-delà de MaxDistance.
	MaxDistance = 60, -- L-305
	MaxOutlines = 60, -- L-305
	RefreshInterval = 0.25, -- V0 : tri par distance 4 fois par seconde (comme Config/ShelfBoxes)

	-- a473 (L-369, Clément 25/11) : contours toujours visibles, à toute distance et hors des MaxOutlines ci-dessus
	-- (Features.BdOutlinesHub, ou BdOutlinesHubDev et jeu DEV ; seulement avec Enabled). Dans la zone safe
	-- (Shared/SafeZone) : les comptoirs WeaponShop, AuraShop, RobuxShop, PawnShop, ENV_Hub_FreeGift et ENV_Hub_Wheel, et
	-- les éléments de la boutique du joueur local (porte, tapis, objets exposés, présentoir à acheter, panneaux
	-- UpgradeSign) ; partout : son outil en main et l'objet porté au-dessus de sa tête. MaxPinned Highlight de plus dans
	-- la réserve, créés au départ avec les autres : MaxOutlines + MaxPinned = 100 Highlight au plus, sous les 255 de
	-- Roblox (L-305 ; 40 vus à la fois par Clément). Plus d'éléments que MaxPinned : outil et objet porté d'abord, puis
	-- les stands, puis la boutique par distance ; les autres suivent la règle de près.
	PinnedEnabled = (Features.BdOutlines == true or (Features.BdOutlinesDev == true and ProductIds.IsDev == true))
		and (Features.BdOutlinesHub == true or (Features.BdOutlinesHubDev == true and ProductIds.IsDev == true)),
	MaxPinned = 40, -- V0 : 6 stands, outil, objet porté, porte, présentoir, panneau, tapis et jusqu'à 24 objets exposés

	-- Invite affichée (ProximityPromptService.PromptShown) : l'élément de la liste qui la contient ; sinon (invite
	-- posée à côté, comme celle d'un colis, sur le ShelfSlot_xx de son rayon) l'élément de la liste le plus proche de
	-- l'invite, à FocusMatchDistance studs au plus.
	FocusMatchDistance = 4, -- V0

	-- Aspect de secours, quand le modèle de Clément manque (valeurs de ses modèles du 23/11, L-305 point 2).
	Fallback = {
		Outline = {
			OutlineColor = Color3.fromRGB(4, 4, 53), -- #040435, la couleur de nos icônes
			OutlineTransparency = 0,
			FillColor = Color3.fromRGB(4, 4, 53),
			FillTransparency = 1,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		},
		Focus = {
			OutlineColor = Color3.fromRGB(255, 255, 255),
			OutlineTransparency = 0,
			FillColor = Color3.fromRGB(255, 255, 255),
			FillTransparency = 1,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		},
	},
}

export type Outlines = typeof(Outlines)

return DeepFreeze(Outlines)
