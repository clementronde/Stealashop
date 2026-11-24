---------------------------------------------------------------- montage a232 (après setup215.luau du banc a215)
-- Faux Roblox, comme Roblox Studio le fait (vu dans Studio le 17/11, a232) :
--   - TextLabel : TextWrapped = false remet TextScaled à false ; TextScaled = true remet TextWrapped à true ;
--   - TextScaled + TextWrapped ne coupe la ligne qu'aux espaces ASCII, jamais aux espaces insécables (U+00A0) : sans
--     espace ASCII, le texte reste sur une ligne, réduit à la largeur ;
--   - PLAIN lit une espace insécable comme une espace (mesure et motifs %s des tests).
-- checkLine (setup215) : « une ligne » = 1 ligne ET TextScaled gardé (avant : TextWrapped == false, état impossible).
do
	local baseNewIndex = InstanceMT.__newindex
	InstanceMT.__newindex = function(self, key, value)
		baseNewIndex(self, key, value)
		if rawget(self, "_class") == "TextLabel" then
			if key == "TextWrapped" and value == false then
				baseNewIndex(self, "TextScaled", false)
			elseif key == "TextScaled" and value == true then
				baseNewIndex(self, "TextWrapped", true)
			end
		end
	end
	local basePlain = PLAIN
	function PLAIN(text)
		return (string.gsub(basePlain(text), utf8.char(0xA0), " "))
	end
	local function textBounds(self)
		local props = rawget(self, "_props")
		local raw = string.gsub(props.Text or "", "<[^>]*>", "")
		local em = MEASURE(raw)
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
		if props.TextWrapped and string.find(raw, " ", 1, true) then
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
	local baseIndex = InstanceMT.__index
	InstanceMT.__index = function(self, key)
		if key == "TextBounds" and rawget(self, "_class") == "TextLabel" then
			return textBounds(self)
		end
		return baseIndex(self, key)
	end
	-- celui de setup215, avec « TextScaled gardé » à la place de « TextWrapped == false »
	function checkLine(tag, amount, head, trailText)
		relayout(amount)
		local E = UiMotionC.FloatGain.TrailExponent
		local box = amount.AbsoluteSize
		local b = amount.TextBounds
		local text = PLAIN(amount.Text)
		check(LINES[amount] == 1 and amount.TextScaled == true, `{tag} « {text} » sur une ligne, TextScaled gardé ({LINES[amount]} ligne(s), TextScaled {amount.TextScaled}, Amount {math.floor(box.X)} × {math.floor(box.Y)} px, texte {math.floor(b.X)} × {math.floor(b.Y)} px)`)
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
end
