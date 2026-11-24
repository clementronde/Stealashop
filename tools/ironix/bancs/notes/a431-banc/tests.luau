-- Tests du banc a431 (L-332). Modules : SkillTree, Features, PvP, Potions, Disguise (vrais fichiers du dépôt).
VERBOSE = false
local total, fails = 0, 0
local function check(ok: boolean, what: string)
	total += 1
	if ok then
		if VERBOSE then print("  ok    " .. what) end
	else
		fails += 1
		print("  ÉCHEC " .. what)
	end
end
local function num(x: number): string -- 0.04 -> "4", 1.25 -> "1.25"
	local s = string.format("%.2f", x):gsub("0+$", ""):gsub("%.$", "")
	return s
end

local List = SkillTree.List
check(#List == 11, `11 compétences ({#List})`)

-- D. Une phrase par compétence.
for _, skill in List do
	local d = skill.Description
	check(type(d) == "string" and #d >= 20 and #d <= 120, `D1 {skill.Id} : une phrase de 20 à 120 caractères ({type(d) == "string" and #d or "absente"})`)
	check(type(d) == "string" and string.find(d, "—", 1, true) == nil and string.match(d, "^%u") ~= nil and string.match(d, "[%.!]$") ~= nil, `D2 {skill.Id} : majuscule au début, point à la fin, sans « — »`)
end

-- L. Un Label à chaque niveau, jamais « — » ni un mot en capitale (il remplacerait le nom de la tuile).
for _, skill in List do
	for n = 1, skill.MaxLevel do
		local l = skill.Labels[n]
		check(type(l) == "string" and l ~= "" and l ~= "—", `L1 {skill.Id} niveau {n} : Label présent ({tostring(l)})`)
		check(type(l) == "string" and string.match(l, "^%u%l") == nil, `L2 {skill.Id} niveau {n} : pas un mot en capitale ({tostring(l)})`)
		local chiffre = type(l) == "string" and string.find(l, "%d") ~= nil
		check(chiffre or (skill.Id == "Cameras" and n == 1), `L3 {skill.Id} niveau {n} : chiffré ({tostring(l)} ; seule exception : Cameras 1 « hit alert »)`)
	end
	local l0 = skill.Labels[0]
	check(l0 == nil or (l0 ~= "" and l0 ~= "—"), `L4 {skill.Id} niveau 0 : rien ou une valeur ({tostring(l0)})`)
end

-- V. Les Labels sont les vraies valeurs de Config.
local B = SkillTree.ById
local function each(id: string, f: (n: number, e: number) -> string)
	local skill = B[id]
	for n = 1, skill.MaxLevel do
		local e = skill.Effects[n]
		local want = f(n, e)
		check(skill.Labels[n] == want, `V {id} niveau {n} : « {want} » ({tostring(skill.Labels[n])})`)
	end
end
each("GlassThickness", function(_, e) return tostring(PvP.DoorHits + e) .. " hits" end)
check(B.GlassThickness.Labels[0] == tostring(PvP.DoorHits) .. " hits", "V GlassThickness niveau 0 : PvP.DoorHits")
each("GlassRegen", function(_, e) return num(e * 100) .. "%/s" end)
each("Bodyguards", function(_, e) return "speed " .. tostring(e) end)
each("PotionLuck", function(_, e) return "+" .. tostring(math.floor((1 / e - 1) * 100 + 0.5)) .. "% potions" end)
check(B.PotionLuck.Labels[0] == nil, "V PotionLuck niveau 0 : rien (« None » à l'écran)")
each("Curtain", function(_, e) return tostring(e) .. "s" end)
check(B.Curtain.Labels[0] == tostring(SkillTree.Lock.BaseDuration) .. "s", "V Curtain niveau 0 : Lock.BaseDuration")
each("DoorGuard", function(_, e) return "push/" .. tostring(e) .. "s" end)
each("PotionTime", function(_, e) return "×" .. num(e) end)
check(B.PotionTime.Labels[0] == "×1", "V PotionTime niveau 0 : ×1 (sans achat)")
each("Traps", function(_, e) return tostring(e) .. (if e == 1 then " trap" else " traps") end)
check(B.Traps.Labels[0] == "0 traps", "V Traps niveau 0 : 0 traps")
each("Walls", function(n) return `wall {n}/{B.Walls.MaxLevel}` end)
check(B.FittingRoom.Labels[1] == tostring(Disguise.Duration) .. "s disguise", "V FittingRoom : Disguise.Duration")
check(B.Cameras.Labels[1] == "hit alert", "V Cameras 1 : alerte seule (Effects[1] = 0)")
for n = 2, 3 do
	check(string.find(B.Cameras.Labels[n], tostring(B.Cameras.Effects[n]) .. "s", 1, true) == 1, `V Cameras {n} : Effects[{n}] s en tête ({B.Cameras.Labels[n]})`)
end
check(string.find(B.Cameras.Labels[3], "radar", 1, true) ~= nil, "V Cameras 3 : radar")
check(string.find(B.Curtain.Description, tostring(SkillTree.Lock.Cooldown) .. "s", 1, true) ~= nil, "V Curtain : recharge Lock.Cooldown dans la phrase")
check(string.find(B.GlassRegen.Description, tostring(PvP.DoorRepairDelay) .. "s", 1, true) ~= nil, "V GlassRegen : PvP.DoorRepairDelay dans la phrase")

print(`a431 : {total} vérification(s), {fails} échec(s)`)
