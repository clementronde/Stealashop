--[[
	collect_motion_proto.luau (Clément, 2026-11-23) : prototype en Edit du mouvement des objets exposés, validé par
	Clément (« les mouvements très cool »). Référence pour Ironix (liaison L-303) : dans le jeu, c'est
	DisplayController qui fait ce mouvement, côté client. Ce fichier n'est qu'un aperçu, à lancer dans la barre de
	commande en Edit, sur des objets posés à la main (ici Workspace/_APERCU_SolLumiere/Sol_3_Musee/_Proto, qui
	remplit _G.PadProto.data = { { item = Model, rest = CFrame, phase = number, plate = BasePart, plateRest = CFrame } }).
	Arrêt : _G.PadProto.conn:Disconnect().

	Le mouvement (valeurs du prototype) :
	- au repos, l'objet flotte : bas de sa boîte à 0,6 stud au-dessus de DisplaySlot_xx, et il monte et descend
	  de ±0,3 stud (sinus de 2,6 s), décalé de 0,7 rad d'une place à l'autre pour que tout ne bouge pas ensemble ;
	- à l'encaissement de sa plaque : un tour complet sur lui-même (axe vertical au centre de sa boîte) en 0,7 s
	  (Quad Out), avec 2 petits sauts dans le même temps, le premier de 0,9 stud, le second de 0,9 × 0,45 ;
	- la plaque s'enfonce de SinkDepth (0,1) pendant 0,15 s, comme aujourd'hui.
]]

local RunService = game:GetService("RunService")

local P = _G.PadProto
assert(P and P.data, "construire d'abord les objets du prototype (_G.PadProto.data)")
if P.conn then P.conn:Disconnect() end

P.cfg = {
	BobHeight = 0.3, -- studs, de part et d'autre
	BobPeriod = 2.6, -- secondes
	SpinTime = 0.7, -- secondes, un tour complet
	HopHeight = 0.9, -- studs, premier saut
	Hops = 2, -- sauts pendant le tour
	HopDecay = 0.45, -- chaque saut fait 45 % du précédent
	SinkDepth = 0.1,
	SinkTime = 0.15,
	AutoDemo = true, -- encaisse les plaques une par une, toutes les 0,45 s, puis pause de 2,5 s
}

local function easeOutQuad(a: number): number
	return 1 - (1 - a) * (1 - a)
end

function P.collect(i: number)
	local d = P.data[i]
	if not d then return end
	d.collectAt = os.clock()
	local gui = d.plate:FindFirstChild("AmountGui")
	local t = gui and gui:FindFirstChild("Amount")
	if t and t:IsA("TextLabel") then
		d.saved = d.saved or t.Text
		t.Text = "$0"
	end
end

local start = os.clock()
local nextDemo, demoIdx = os.clock() + 1.5, 0
P.conn = RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local c = P.cfg
	if c.AutoDemo and now >= nextDemo then
		demoIdx += 1
		if demoIdx > #P.data then
			demoIdx = 0
			nextDemo = now + 2.5
			for _, d in P.data do
				local gui = d.plate:FindFirstChild("AmountGui")
				local t = gui and gui:FindFirstChild("Amount")
				if d.saved and t and t:IsA("TextLabel") then t.Text = d.saved end
			end
		else
			P.collect(demoIdx)
			nextDemo = now + 0.45
		end
	end
	for _, d in P.data do
		if d.item.Parent then
			local bob = c.BobHeight * math.sin((now - start) * 2 * math.pi / c.BobPeriod + d.phase)
			local spin, hop, since = 0, 0, math.huge
			if d.collectAt then
				since = now - d.collectAt
				local a = since / c.SpinTime
				if a >= 1 then
					d.collectAt = nil
				else
					spin = easeOutQuad(a) * 2 * math.pi
					local k = a * c.Hops
					local which = math.floor(k)
					local f = k - which
					hop = c.HopHeight * (c.HopDecay ^ which) * 4 * f * (1 - f) -- parabole par saut
				end
			end
			d.item:PivotTo(d.rest * CFrame.new(0, bob + hop, 0) * CFrame.Angles(0, spin, 0))
			d.plate.CFrame = if since < c.SinkTime then CFrame.new(0, -c.SinkDepth, 0) * d.plateRest else d.plateRest
		end
	end
end)
