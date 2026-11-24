---------------------------------------------------------------- montage a215 (après setup213.luau du banc a213)
-- Faux Roblox (ajouts purs, ce banc seulement) : mesure du texte comme Roblox le fait pour un TextLabel.
--   - police au caractère : MEASURE(text) = largeur en « em » (0,55 par caractère, 0,28 pour une espace) ;
--   - TextService:GetTextSize(text, size) = (MEASURE × size, size) ;
--   - TextBounds d'un TextLabel TextScaled : la plus grande taille (≤ 100) qui tient dans AbsoluteSize, sur une ligne,
--     ou, avec TextWrapped, sur 2 ou 3 lignes si le texte y est plus grand (ce que faisait Roblox avec « +8 Speed/s ») ;
--   - Font, TextXAlignment, TextYAlignment, TextWrapped connus des TextLabel.
PROPS.TextLabel.TextWrapped = false
PROPS.TextLabel.Font = "Enum.Font.GothamBold"
PROPS.TextLabel.TextXAlignment = "Enum.TextXAlignment.Center"
PROPS.TextLabel.TextYAlignment = "Enum.TextYAlignment.Center"

function PLAIN(text)
	return (string.gsub(text, "<[^>]*>", ""))
end
function MEASURE(text)
	local em = 0
	for _, code in utf8.codes(PLAIN(text)) do
		em += if code == 32 then 0.28 else 0.55
	end
	return em
end
LINES = setmetatable({}, { __mode = "k" }) -- lignes du dernier TextBounds lu, par TextLabel

local function textBounds(self)
	local props = rawget(self, "_props")
	local em = MEASURE(props.Text or "")
	if not props.TextScaled then
		LINES[self] = 1
		return Vector2.new(em * 14, 14)
	end
	local box = absSize(self)
	if box.X <= 0 or box.Y <= 0 or em <= 0 then
		LINES[self] = 1
		return Vector2.new(0, 0)
	end
	local best, lines = math.min(box.Y, box.X / em, 100), 1
	if props.TextWrapped then
		for k = 2, 3 do
			local s = math.min(box.Y / k, box.X * k / em, 100)
			if s > best then
				best, lines = s, k
			end
		end
	end
	LINES[self] = lines
	return Vector2.new(em / lines * best, lines * best)
end
do
	local baseIndex = InstanceMT.__index
	InstanceMT.__index = function(self, key)
		if key == "TextBounds" and rawget(self, "_class") == "TextLabel" then
			return textBounds(self)
		end
		return baseIndex(self, key)
	end
end

TEXT_SERVICE = {
	GetTextSize = function(_, text, size, _font, _frame)
		return Vector2.new(MEASURE(text) * size, size)
	end,
}
for side, old in table.clone(games) do
	games[side] = {
		GetService = function(_, name)
			if name == "TextService" then
				return TEXT_SERVICE
			end
			return old:GetService(name)
		end,
	}
end

-- BB_Gain de Clément tel que mesuré en Play (fusion58) : Row.Amount TextScaled et TextWrapped, à côté de l'icône
-- (ici 75 % / 25 % de la ligne) ; le billboard sur place fait 150 × 46 px.
do
	rawget(BB_GAIN, "_props").Size = UDim2.fromOffset(150, 46)
	local row = el(BB_GAIN, "Row")
	local amount = el(row, "Amount")
	amount.Size = UDim2.fromScale(0.75, 1)
	amount.TextScaled = true
	amount.TextWrapped = true
	amount.RichText = false -- créé avant les ajouts : ses propriétés posées ici
	amount.Font = "Enum.Font.GothamBold"
	amount.TextXAlignment = "Enum.TextXAlignment.Center"
	amount.TextYAlignment = "Enum.TextYAlignment.Center"
	local icon = el(row, "Icon")
	icon.Size = UDim2.fromScale(0.25, 1)
	icon.Position = UDim2.fromScale(0.75, 0)
end

-- Relayout de l'exposant comme Roblox après un rendu (TextBounds et AbsoluteSize changent) : on envoie les signaux.
function relayout(amount)
	amount:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	amount:GetPropertyChangedSignal("TextBounds"):Fire()
end

-- Vérifie, pour le TextLabel `amount` dont le texte commence par `head` (le nombre), qu'il tient sur une ligne et que
-- l'exposant `trailText` (s'il y en a un) est juste après le nombre sans couvrir ni lui ni la suite. `tag` : préfixe.
function checkLine(tag, amount, head, trailText)
	relayout(amount)
	local E = UiMotionC.FloatGain.TrailExponent
	local box = amount.AbsoluteSize
	local b = amount.TextBounds
	local text = PLAIN(amount.Text)
	check(LINES[amount] == 1 and amount.TextWrapped == false, `{tag} « {text} » sur une ligne ({LINES[amount]} ligne(s), Amount {math.floor(box.X)} × {math.floor(box.Y)} px, texte {math.floor(b.X)} × {math.floor(b.Y)} px)`)
	if trailText == nil then
		return b
	end
	local exp = amount:FindFirstChild(E.Name)
	check(exp ~= nil and exp.Text == trailText, `{tag} exposant « {trailText} » posé par le code ({exp and exp.Text})`)
	if exp == nil then
		return b
	end
	local left = (box.X - b.X) / 2
	local numberRight = left + MEASURE(head) * b.Y
	local gapEnd = left + (MEASURE(string.match(text, "^%S+%s*") or head)) * b.Y -- fin du blanc réservé
	local expLeft = exp.Position.X.Scale * box.X
	local expHeight = exp.Size.Y.Scale * box.Y
	local expRight = expLeft + MEASURE(trailText) * math.min(expHeight, exp.Size.X.Scale * box.X / MEASURE(trailText))
	check(expLeft >= numberRight - 0.5, `{tag} l'exposant ne couvre pas le nombre (nombre jusqu'à {math.floor(numberRight)} px, exposant dès {math.floor(expLeft)} px)`)
	check(expLeft <= numberRight + 0.28 * b.Y + 0.5, `{tag} juste après le nombre (écart {math.floor(expLeft - numberRight)} px)`)
	check(expRight <= gapEnd + 0.5, `{tag} ni la suite « Speed… » (exposant jusqu'à {math.floor(expRight)} px, suite dès {math.floor(gapEnd)} px)`)
	return b
end
