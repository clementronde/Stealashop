--!nocheck
-- Banc a244 (vague 72) : la renaissance allumée au lancement. Lu après lib.luau (copie a244 de celle d'a164).
--   on     vrai RebirthService, Features tel quel (Rebirth = true), hors Studio : allumé, accroche des revenus,
--          renaissance par le remote, réserve vidée, demande en double ignorée
--   alert  vrai RailAlertController : pastille RebirthAlert (attributs Rebirths, RebirthItemOwned, Cash)

local function readyProfile(cash)
	local d = newData()
	d.Cash = cash
	d.Items.req1 = item("Z6_DiamantGeant", 6)
	d.Items.low = item("Z1_PotDeNouilles", 1)
	d.Items.mid = item("Z2_PelucheGeante", 2)
	d.Display["1"] = "req1"
	return d
end

if SCENARIO == "on" then
	IS_STUDIO = false
	check(Config.Features.Rebirth == true, "N0 Features.Rebirth = true (vraie valeur)")
	local baseIncome = FAKES.DisplayService.GetIncomeMultiplier
	local d = readyProfile(25e9)
	d.Reserve = { "low", "mid", "gone" }
	DATA[P1] = d
	local e = readyProfile(20e9)
	DATA[P2] = e
	local service = loadRebirthService()
	service.Init()
	check(service.IsEnabled(), "N1 allumé hors Studio, sans RebirthTest")
	check(FAKES.DisplayService.GetIncomeMultiplier ~= baseIncome, "N2 accroche des revenus installée")
	check(P1:GetAttribute("Rebirths") == 0 and P1:GetAttribute("RebirthItemOwned") == true, "N3 attributs posés au chargement (0 renaissance, objet requis possédé)")
	check(FAKES.DisplayService.GetIncomeMultiplier(P1) == 1, "N4 0 renaissance : revenus ×1")
	check(REBIRTH_HANDLER ~= nil, "N5 remote Rebirth écouté")
	REBIRTH_HANDLER(P1, 1)
	check(d.Rebirths == 1 and P1:GetAttribute("Rebirths") == 1, `N6 renaissance faite par le remote ({tostring(d.Rebirths)})`)
	check(type(d.Reserve) == "table" and #d.Reserve == 0, `N7 réserve vidée ({type(d.Reserve) == "table" and table.concat(d.Reserve, ",") or "?"})`)
	local shown = 0
	for _ in d.Display do
		shown += 1
	end
	check(count(d.Items) == 2 and d.Items.low ~= nil and d.Items.mid ~= nil and shown == 2, "N8 les 2 objets gardés sont sur les présentoirs, pas en réserve")
	check(FAKES.DisplayService.GetIncomeMultiplier(P1) == 1.5, "N9 après la 1re : revenus ×1,5")
	local before = deepCopy(d)
	REBIRTH_HANDLER(P1, 1)
	check(deepEqual(before, d), "N10 la même demande en double est ignorée (profil identique)")
	REBIRTH_HANDLER(P1, 2)
	check(deepEqual(before, d) and d.Rebirths == 1, "N11 la 2e sans argent ni Trône en or : refusée, profil identique")
	e.Reserve = nil
	REBIRTH_HANDLER(P2, 1)
	check(e.Rebirths == 1 and e.Reserve == nil, "N12 profil sans réserve (d'avant la vague 63) : renaissance faite, champ laissé absent")
elseif SCENARIO == "alert" then
	local alerts = charge("RailAlertController")
	local function state()
		alerts.Refresh()
		return alerts.GetState().Rebirth
	end
	check(state() == false, "A1 renaissance coupée (attribut Rebirths absent) : éteinte")
	P1:SetAttribute("Rebirths", 0)
	P1:SetAttribute("RebirthItemOwned", true)
	P1:SetAttribute("Cash", 19e9)
	check(state() == false, "A2 objet requis, 19B sur 20B : éteinte")
	P1:SetAttribute("Cash", 20e9)
	check(state() == true, "A3 objet requis et 20B : allumée")
	P1:SetAttribute("RebirthItemOwned", false)
	check(state() == false, "A4 sans l'objet requis : éteinte")
	P1:SetAttribute("Rebirths", 1)
	P1:SetAttribute("RebirthItemOwned", true)
	check(state() == false, "A5 1 renaissance faite, 20B sur 500B : éteinte")
	P1:SetAttribute("Cash", 500e9)
	check(state() == true, "A6 500B et le Trône en or : allumée")
	P1:SetAttribute("Cash", nil)
	check(state() == false, "A7 argent pas encore posé : éteinte")
else
	error("scénario inconnu : " .. tostring(SCENARIO))
end

print(`{checks} vérification(s), {fails} échec(s)`)
