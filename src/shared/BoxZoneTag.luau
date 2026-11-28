--!strict
-- BoxZoneTag (a517, demande de Cantin du 27/11) : étiquette « ZONE N » sur un colis d'une zone plus haute que la zone
-- « normale » de l'endroit où il apparaît. Seulement pour un colis dont la zone est connue à l'apparition (les 10 % de
-- zone suivante tirés à l'ouverture sont retirés depuis a516). Interrupteur Config/Features.BoxZoneTag (partout) et
-- BoxZoneTagDev (jeu DEV et TEST, Config/ProductIds.IsDev), lu à chaque appel (Shared/LiveFeatures peut le changer).
--
-- Règle V0 (Cantin, 27/11) :
--   - colis posé dans le couloir (rayon d'événement : camion, fourgon ; rayons PNJ) : étiquette si la zone du colis est
--     plus haute que celle de l'endroit (zone du rayon) ; un rayon PNJ n'a que des colis de sa zone, donc jamais ;
--   - colis offert hors du couloir (roue, cadeaux de temps de jeu) : étiquette si sa zone est plus haute que la meilleure
--     zone du joueur (celle de ses objets, la référence du colis de zone : UnboxService.GiveZoneBoxItem).
-- Le serveur décide (Shown) et pose l'attribut BoxZone (nombre) sur le Model du colis, seulement quand l'étiquette se
-- montre ; le colis offert la reçoit dans RevealStarted (boxZone). Le client (Apply) l'écrit dans l'élément ZoneTag du
-- billboard du colis (BB_Box sur un rayon, BB_UnboxOdds pendant l'ouverture), livré par Clément : un TextLabel, ou un
-- GuiObject qui contient un TextLabel Label. Sans lui : un repli du code (pastille sombre au texte jaune, au-dessus du
-- billboard, hors de son cadre). Sans zone : ZoneTag caché (celui de Clément comme le repli).
--
-- API :
--   BoxZoneTag.Attribute = "BoxZone"
--   BoxZoneTag.ElementName = "ZoneTag"
--   BoxZoneTag.Enabled() -> boolean
--   BoxZoneTag.Shown(boxZone, placeZone) -> number?   boxZone si l'étiquette se montre (allumé, boxZone > placeZone)
--   BoxZoneTag.Text(zone) -> string                    « ZONE 3 »
--   BoxZoneTag.Apply(board, zone) -> GuiObject?        client : écrit ou cache l'étiquette dans `board`

local Config = script.Parent:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features")) :: any

-- Config/ProductIds chargé s'il est là ; sans lui, IsDev faux (PROD), comme ZoneBoxEverywhere.
local isDev = (function(): boolean
	local module = Config:FindFirstChild("ProductIds")
	if module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return (result :: any).IsDev == true
		end
	end
	return false
end)()

local BoxZoneTag = {}

BoxZoneTag.Attribute = "BoxZone"
BoxZoneTag.ElementName = "ZoneTag"

-- Repli du code (V0 proposé, a517) : à part du reste du billboard (fond sombre, texte jaune, contour noir).
local FALLBACK_TEXT = Color3.fromRGB(255, 214, 64)
local FALLBACK_BACK = Color3.fromRGB(24, 20, 36)

local function finiteZone(value: any): number?
	if type(value) == "number" and value == value and value >= 1 and value < math.huge then
		return math.floor(value)
	end
	return nil
end

function BoxZoneTag.Enabled(): boolean
	return Features.BoxZoneTag == true or (Features.BoxZoneTagDev == true and isDev)
end

function BoxZoneTag.Shown(boxZone: any, placeZone: any): number?
	local zone, place = finiteZone(boxZone), finiteZone(placeZone)
	if zone == nil or place == nil or not BoxZoneTag.Enabled() then
		return nil
	end
	return if zone > place then zone else nil
end

function BoxZoneTag.Text(zone: number): string
	return `ZONE {math.floor(zone)}`
end

-- Repli : une pastille au-dessus du billboard (les BillboardGui ne coupent pas leurs enfants : ClipsDescendants faux).
local function fallback(board: Instance): TextLabel
	local tag = Instance.new("TextLabel")
	tag.Name = BoxZoneTag.ElementName
	tag.AnchorPoint = Vector2.new(0.5, 1)
	tag.Position = UDim2.new(0.5, 0, 0, -2)
	tag.Size = UDim2.fromScale(0.7, 0.42)
	tag.BackgroundColor3 = FALLBACK_BACK
	tag.BackgroundTransparency = 0.1
	tag.BorderSizePixel = 0
	tag.Font = Enum.Font.GothamBlack
	tag.TextScaled = true
	tag.TextColor3 = FALLBACK_TEXT
	tag.TextStrokeTransparency = 0
	tag.ZIndex = 10
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = tag
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = FALLBACK_TEXT
	stroke.Thickness = 1.5
	stroke.Parent = tag
	tag.Parent = board
	return tag
end

local function textOf(element: Instance): TextLabel?
	if element:IsA("TextLabel") then
		return element
	end
	local label = element:FindFirstChild("Label", true)
	return if label and label:IsA("TextLabel") then label else nil
end

function BoxZoneTag.Apply(board: Instance?, zone: any): GuiObject?
	if board == nil then
		return nil
	end
	local value = finiteZone(zone)
	local found = board:FindFirstChild(BoxZoneTag.ElementName, true)
	local element: GuiObject? = if found and found:IsA("GuiObject") then found else nil
	if value == nil then
		if element then
			element.Visible = false
		end
		return element
	end
	local shown: GuiObject = element or fallback(board)
	local text = textOf(shown)
	if text then
		text.Text = BoxZoneTag.Text(value)
	end
	shown.Visible = true
	return shown
end

return BoxZoneTag
