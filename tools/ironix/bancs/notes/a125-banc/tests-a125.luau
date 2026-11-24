
---------------------------------------------------------------- a125 (f) : saut de Glitch porté ou animé
-- Suit un objet pendant `frames` images : saut vu, pièces cachées, copie décalée, pièces déplacées.
local function watchJump(model, body, cap, frames)
	local start, capStart = body.CFrame, cap.CFrame
	local saw, hiddenSeen, copyShifted, moved, copyClose = false, false, false, false, true
	for _ = 1, frames do
		advance(1 / 60)
		local s = Fx.GetState(model)
		if s and s.Jumping then
			saw = true
			if body.Transparency == 1 and cap.Transparency == 1 then
				hiddenSeen = true
			end
			local j = s.Jump
			local jb = j and j:FindFirstChild("Body")
			if jb and j.Parent ~= nil then
				local d = (jb.Position - body.Position).Magnitude
				if d > 1e-4 then
					copyShifted = true
				end
				if d > 0.03 * 3 * 1.5 then -- GlitchJump × plus grand côté, avec marge
					copyClose = false
				end
			end
		end
		if body.CFrame ~= start or cap.CFrame ~= capStart then
			moved = true
		end
	end
	return saw, hiddenSeen, copyShifted, moved, copyClose
end

local function waitEndJump(model)
	for _ = 1, 120 do
		local s = Fx.GetState(model)
		if s and not s.Jumping then
			return
		end
		advance(1 / 60)
	end
end

-- Objet porté (non ancré, comme celui soudé à la tête par CarryService) : le saut reste, rien n'est déplacé.
local carriedG, cgBody, cgCap = makeItem("CarryVisualGlitch", "CarriedItem", "Glitch", nil, Vector3.new(10, 0, 5), { anchored = false })
advance(0.6)
local cgs = Fx.GetState(carriedG)
check(cgs ~= nil and cgs.Jump ~= nil and cgs.Jump.Name == "MutationJump", "porté + Glitch : copie MutationJump préparée")
check(cgs ~= nil and cgs.Jump ~= nil and cgs.Jump.Parent == nil, "porté + Glitch : copie cachée hors saut")
local saw, hiddenSeen, shifted, moved, close = watchJump(carriedG, cgBody, cgCap, 300)
check(saw, "porté + Glitch : le saut a lieu (L-131 f)")
check(hiddenSeen, "porté + Glitch : pendant le saut, les pièces sont cachées en local")
check(shifted and close, "porté + Glitch : la copie est décalée d'un petit saut")
check(not moved, "porté + Glitch : aucune pièce de l'objet déplacée (soudure à la tête intacte)")
waitEndJump(carriedG)
check(cgBody.Transparency == 0 and cgCap.Transparency == 0 and Fx.GetState(carriedG).Jump.Parent == nil, "porté + Glitch : après le saut, transparence d'origine et copie retirée")
-- la copie suit l'objet qui bouge (joueur qui court)
local followed, seenMoving = true, false
for _ = 1, 240 do
	carriedG:PivotTo(carriedG:GetPivot() * CFrame.new(0.05, 0, 0))
	advance(1 / 60)
	local s = Fx.GetState(carriedG)
	if s and s.Jumping and s.Jump.Parent ~= nil then
		seenMoving = true
		local jb = s.Jump:FindFirstChild("Body")
		if (jb.Position - cgBody.Position).Magnitude > 0.2 then
			followed = false
		end
	end
end
check(seenMoving and followed, "porté + Glitch : la copie suit l'objet qui se déplace")
-- objet caché en local (CarryController, potion) : la copie l'est aussi, le modificateur n'est jamais touché
cgBody.LocalTransparencyModifier = 1
local copyHidden, seenHidden = true, false
for _ = 1, 200 do
	advance(1 / 60)
	local s = Fx.GetState(carriedG)
	if s and s.Jumping then
		seenHidden = true
		local jb = s.Jump:FindFirstChild("Body")
		if jb.LocalTransparencyModifier ~= 1 then
			copyHidden = false
		end
	end
end
check(seenHidden and copyHidden and cgBody.LocalTransparencyModifier == 1, "porté caché en local : la copie aussi, LocalTransparencyModifier gardé")
cgBody.LocalTransparencyModifier = 0
-- transparence changée par le serveur pendant un saut : gardée
for _ = 1, 300 do
	local s = Fx.GetState(carriedG)
	if s and s.Jumping then
		break
	end
	advance(1 / 60)
end
cgCap.Transparency = 0.5
waitEndJump(carriedG)
check(cgCap.Transparency == 0.5 and cgBody.Transparency == 0, "transparence changée pendant un saut : la nouvelle est gardée")
cgCap.Transparency = 0

-- Objet animé (Idle) : le saut reste, les pièces ne sont jamais déplacées par l'effet.
local idleG, igBody, igCap = makeItem("ITM_GlitchIdle2", "DisplayItem", "Glitch", nil, Vector3.new(15, 0, -10), { idle = true })
advance(0.6)
local saw2, hidden2, shifted2, moved2 = watchJump(idleG, igBody, igCap, 300)
check(saw2 and hidden2 and shifted2, "animé (Idle) + Glitch : le saut a lieu, par la copie")
check(not moved2, "animé (Idle) + Glitch : l'idle garde la main (pièces jamais déplacées par l'effet)")
-- l'idle tourne une pièce pendant les sauts : la copie suit sa pose
local turned, seenTurn = true, false
for _ = 1, 240 do
	igCap.CFrame = igCap.CFrame * CFrame.Angles(0, 0.05, 0)
	advance(1 / 60)
	local s = Fx.GetState(idleG)
	if s and s.Jumping then
		seenTurn = true
		local jc = s.Jump:FindFirstChild("Cap")
		if (jc.Position - igCap.Position).Magnitude > 0.2 then
			turned = false
		end
	end
end
check(seenTurn and turned, "animé (Idle) + Glitch : la copie suit la pièce animée")
-- mutation retirée pendant un saut : transparence remise, copie détruite
for _ = 1, 300 do
	local s = Fx.GetState(idleG)
	if s and s.Jumping then
		break
	end
	advance(1 / 60)
end
local st = Fx.GetState(idleG)
local jumpCopy = st and st.Jump
local wasJumping = st and st.Jumping
idleG:SetAttribute("MutationEffect", nil)
advance(0.3)
check(wasJumping and igBody.Transparency == 0 and igCap.Transparency == 0 and jumpCopy.Parent == nil, "mutation retirée pendant un saut : transparence d'origine, copie détruite")
-- objet immobile : saut d'origine (pièces déplacées puis remises), pas de copie
local still = makeItem("ITM_GlitchStill", "DisplayItem", "Glitch", nil, Vector3.new(-15, 0, -10))
advance(0.6)
check(Fx.GetState(still) ~= nil and Fx.GetState(still).Jump == nil, "objet immobile + Glitch : pas de copie (saut d'origine)")
-- objet porté sans Glitch : pas de copie
local carriedGold = makeItem("CarryVisualGold", "CarriedItem", "Gold", nil, Vector3.new(20, 0, 5), { anchored = false })
advance(0.6)
check(Fx.GetState(carriedGold) ~= nil and Fx.GetState(carriedGold).Jump == nil, "porté + Gold : pas de copie")

---------------------------------------------------------------- a125 (g) : style sur BB_Carry
-- BB_Carry de CarryService : sur un LabelPoint de l'objet porté, ligne Mutation facultative.
local function carryWithLabel(name, effect, withMutation, at)
	local m = makeItem(name, "CarriedItem", effect, "Big", at, { anchored = false })
	local old = m.PrimaryPart:FindFirstChild("BillboardPoint")
	if old then
		old:Destroy()
	end
	local point = inst("Attachment", m.PrimaryPart, "LabelPoint")
	local bb = inst("BillboardGui", point, "BB_Carry")
	local item = inst("TextLabel", bb, "ItemName", { Text = "Soda Can", TextColor3 = hex("FFFFFF") })
	local mut = nil
	if withMutation then
		mut = inst("TextLabel", bb, "Mutation", { Text = "BIG · GOLD", TextColor3 = hex("FFC21A") })
		inst("UIStroke", mut, "UIStroke", { Color = hex("000000"), Transparency = 0 })
	end
	return m, mut, item
end
local cb, cbMut, cbItem = carryWithLabel("CarryLabelGold", "Gold", true, Vector3.new(0, 0, 30))
advance(0.6)
local cbGrad = cbMut:FindFirstChild("MutationGradient")
check(cbGrad ~= nil and cbGrad:GetAttribute("Which") == "TextGradient:Gold", "BB_Carry.Mutation : TextGradient de Gold posé")
check(cbMut.TextColor3 == hex("FFFFFF") and cbMut:FindFirstChild("UIStroke").Color == hex("6B3A00"), "BB_Carry.Mutation : texte blanc, contour à StrokeColor")
check(cbItem:FindFirstChild("MutationGradient") == nil and cbItem.TextColor3 == hex("FFFFFF"), "BB_Carry : ItemName jamais touché")
local x0 = cbGrad and cbGrad.Offset.X
local swept = false
for _ = 1, 200 do
	advance(1 / 60)
	if cbGrad and cbGrad.Offset.X ~= x0 then
		swept = true
	end
end
check(swept, "BB_Carry.Mutation : mouvement Shine joué (objet proche)")
cb:SetAttribute("MutationEffect", nil)
cb:SetAttribute("MutationSize", nil)
advance(0.3)
check(cbMut:FindFirstChild("MutationGradient") == nil and cbMut.TextColor3 == hex("FFC21A") and cbMut:FindFirstChild("UIStroke").Color == hex("000000"), "BB_Carry.Mutation sans mutation : remise comme avant")
-- BB_Carry sans ligne Mutation : rien n'est fait
local cn, _, cnItem = carryWithLabel("CarryLabelNone", "Neon", false, Vector3.new(5, 0, 30))
advance(0.6)
local anyGrad = false
for _, d in cn:GetDescendants() do
	if d.Name == "MutationGradient" then
		anyGrad = true
	end
end
check(not anyGrad and cnItem.TextColor3 == hex("FFFFFF"), "BB_Carry sans Mutation : le code ne fait rien")
-- BB_Carry posé après le tag : stylé aussi
local late = makeItem("CarryLate", "CarriedItem", "Shiny", nil, Vector3.new(10, 0, 30), { anchored = false })
advance(0.3)
local lp = inst("Attachment", late.PrimaryPart, "LabelPoint")
local lbb = inst("BillboardGui", lp, "BB_Carry")
local lmut = inst("TextLabel", lbb, "Mutation", { Text = "SHINY", TextColor3 = hex("FFFFFF") })
-- le faux Roblox ne lance pas DescendantAdded tout seul : lancé ici, comme Roblox
late.DescendantAdded:Fire(lp)
late.DescendantAdded:Fire(lbb)
late.DescendantAdded:Fire(lmut)
advance(0.3)
local lg = lmut:FindFirstChild("MutationGradient")
check(lg ~= nil and lg:GetAttribute("Which") == "TextGradient:Shiny", "BB_Carry posé après le tag : stylé aussi")

local others = 0
for _, l in LOG do
	if l.kind == "ERROR" or l.kind == "WARN" then
		others += 1
		print("    " .. l.text)
	end
end
check(others == 0, "aucune erreur ni avertissement dans le journal")
