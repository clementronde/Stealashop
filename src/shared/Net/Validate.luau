--!strict
-- Contrôle de la forme des arguments d'un remote (ReplicatedStorage/Shared/Net/Validate).
-- Utilisé par Net : à chaque appel reçu par le serveur, et en Studio pour
-- avertir quand le code envoie des arguments mal formés.

local Definitions = require(script.Parent.Definitions)

type ArgSpec = Definitions.ArgSpec

export type Reason = "ArgCount" | "ArgType" | "ArgValue"

local Validate = {}

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- Renvoie nil si la valeur convient, sinon la raison et un détail en français.
local function checkOne(spec: ArgSpec, value: any): (Reason?, string?)
	local kind = spec.Kind
	if value == nil then
		if spec.Optional then
			return nil, nil
		end
		return "ArgType", `{spec.Name} : {kind} attendu, reçu nil`
	end

	local actual = typeof(value)
	if kind == "string" then
		if actual ~= "string" then
			return "ArgType", `{spec.Name} : string attendu, reçu {actual}`
		end
		local minLength = spec.Min or 1
		local maxLength = spec.Max or 0
		local length = #value
		if length < minLength or length > maxLength then
			return "ArgValue", `{spec.Name} : longueur {length} hors de [{minLength}, {maxLength}]`
		end
		if utf8.len(value) == nil then
			return "ArgValue", `{spec.Name} : chaîne UTF-8 invalide`
		end
	elseif kind == "int" or kind == "number" then
		if actual ~= "number" then
			return "ArgType", `{spec.Name} : {kind} attendu, reçu {actual}`
		end
		if not isFinite(value) then
			return "ArgValue", `{spec.Name} : nombre non fini ({value})`
		end
		if kind == "int" and math.floor(value) ~= value then
			return "ArgValue", `{spec.Name} : entier attendu, reçu {value}`
		end
		local min, max = spec.Min, spec.Max
		if (min ~= nil and value < min) or (max ~= nil and value > max) then
			return "ArgValue", `{spec.Name} : {value} hors de [{min or "-inf"}, {max or "+inf"}]`
		end
	elseif kind == "boolean" then
		if actual ~= "boolean" then
			return "ArgType", `{spec.Name} : boolean attendu, reçu {actual}`
		end
	elseif kind == "Vector3" then
		if actual ~= "Vector3" then
			return "ArgType", `{spec.Name} : Vector3 attendu, reçu {actual}`
		end
		if not (isFinite(value.X) and isFinite(value.Y) and isFinite(value.Z)) then
			return "ArgValue", `{spec.Name} : Vector3 non fini`
		end
	elseif kind == "Player" then
		if actual ~= "Instance" or not value:IsA("Player") then
			return "ArgType", `{spec.Name} : Player attendu, reçu {actual}`
		end
	elseif kind == "Instance" then
		if actual ~= "Instance" then
			return "ArgType", `{spec.Name} : Instance attendue, reçu {actual}`
		end
	end
	return nil, nil
end

-- Contrôle les arguments `...` d'un appel contre `args`. Renvoie nil si tout
-- convient, sinon la raison et un détail lisible.
function Validate.check(args: { ArgSpec }, ...: any): (Reason?, string?)
	local count = select("#", ...)
	local required = 0
	for i, spec in args do
		if not spec.Optional then
			required = i
		end
	end
	if count < required or count > #args then
		local expected = if required == #args then `{required}` else `{required} à {#args}`
		return "ArgCount", `{expected} argument(s) attendu(s), reçu {count}`
	end
	for i = 1, count do
		local reason, detail = checkOne(args[i], (select(i, ...)))
		if reason then
			return reason, `argument {i}, {detail}`
		end
	end
	return nil, nil
end

return Validate
