-- Lecteur JSON minimal (banc a22) : objets, tableaux, textes (échappements et \uXXXX), nombres,
-- true, false ; null devient nil (la clé est absente de la table).
function decodeJson(text)
	local pos = 1
	local function fail(message)
		error(`JSON : {message} à la position {pos}`, 0)
	end
	local function skip()
		pos = string.find(text, "[^ \t\r\n]", pos) or #text + 1
	end
	local ESCAPES = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
	local parseValue
	local function parseString()
		pos += 1 -- guillemet ouvrant
		local out = {}
		while true do
			local stop = string.find(text, '["\\]', pos)
			if stop == nil then
				fail("texte non fermé")
			end
			table.insert(out, string.sub(text, pos, stop - 1))
			pos = stop
			if string.sub(text, pos, pos) == '"' then
				pos += 1
				return table.concat(out)
			end
			local code = string.sub(text, pos + 1, pos + 1)
			if code == "u" then
				table.insert(out, utf8.char(tonumber(string.sub(text, pos + 2, pos + 5), 16)))
				pos += 6
			else
				table.insert(out, ESCAPES[code] or fail("échappement inconnu"))
				pos += 2
			end
		end
	end
	local function parseNumber()
		local literal = string.match(text, "^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		if literal == nil then
			fail("nombre attendu")
		end
		pos += #literal
		return tonumber(literal)
	end
	local function parseArray()
		pos += 1
		local out = {}
		skip()
		if string.sub(text, pos, pos) == "]" then
			pos += 1
			return out
		end
		while true do
			table.insert(out, parseValue())
			skip()
			local c = string.sub(text, pos, pos)
			pos += 1
			if c == "]" then
				return out
			elseif c ~= "," then
				fail("« , » ou « ] » attendu")
			end
		end
	end
	local function parseObject()
		pos += 1
		local out = {}
		skip()
		if string.sub(text, pos, pos) == "}" then
			pos += 1
			return out
		end
		while true do
			skip()
			if string.sub(text, pos, pos) ~= '"' then
				fail("clé attendue")
			end
			local key = parseString()
			skip()
			if string.sub(text, pos, pos) ~= ":" then
				fail("« : » attendu")
			end
			pos += 1
			out[key] = parseValue()
			skip()
			local c = string.sub(text, pos, pos)
			pos += 1
			if c == "}" then
				return out
			elseif c ~= "," then
				fail("« , » ou « } » attendu")
			end
		end
	end
	parseValue = function()
		skip()
		local c = string.sub(text, pos, pos)
		if c == "{" then
			return parseObject()
		elseif c == "[" then
			return parseArray()
		elseif c == '"' then
			return parseString()
		elseif string.sub(text, pos, pos + 3) == "true" then
			pos += 4
			return true
		elseif string.sub(text, pos, pos + 4) == "false" then
			pos += 5
			return false
		elseif string.sub(text, pos, pos + 3) == "null" then
			pos += 4
			return nil
		end
		return parseNumber()
	end
	local value = parseValue()
	skip()
	if pos <= #text then
		fail("texte en trop")
	end
	return value
end
