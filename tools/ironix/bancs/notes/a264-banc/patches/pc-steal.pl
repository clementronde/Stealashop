# a264 (vague 78, 2026-11-20) : banc pc-steal. L'invite « Steal » d'un objet qui revole vers son rayon (Landed = false,
# retour après « Caught ») reste coupée et un appui n'envoie rien ; elle se rallume dès Landed = true, sans attendre le
# tour suivant de HeistController (0,2 s). Avant : allumée ≈ 0,34 s avant la pose, le serveur refusait le début du
# maintien (« objet en vol ») et prenait la fin pour un début. Cas V1 à V5, ajoutés à la fin du scénario.
lit(q{`toute autre échelle : portée {d5} et {d6} studs`)},
	q{`toute autre échelle : portée {d5} et {d6} studs`)

print("== a264 : invite « Steal » coupée tant que l'objet vole vers son rayon")
local fm = newInstance("Model")
fm.Name = "ITM_Test"
local fbody = inst("Part", fm, "Body", { CFrame = CFrame.new(slotPos(6) + Vector3.new(0, 0.75, 0)), Size = Vector3.new(1.5, 1.5, 1) })
fm.PrimaryPart = fbody
fm.WorldPivot = CFrame.new(slotPos(6))
fm:SetAttribute("SlotId", "STORE_Test:6")
fm:SetAttribute("ItemId", ITEM_ID)
fm:SetAttribute("Landed", false)
CollectionService:AddTag(fm, "ShelfItem")
fm.Parent = boxesF
advance(0.5)
local fp = fbody:FindFirstChild("ShelfItemPrompt")
check(fp ~= nil and fp.Enabled == false, "V1 objet en vol (Landed = false) : invite « Steal » coupée (a264)")
local sent = #NET.grab
if fp then
	fp.PromptButtonHoldBegan:Fire()
	fp.Triggered:Fire()
end
check(#NET.grab == sent, `V2 appui pendant le vol : aucun GrabItem envoyé ({#NET.grab - sent})`)
fm:SetAttribute("Landed", true)
check(fp ~= nil and fp.Enabled == true, "V3 posé (Landed = true) : invite rallumée tout de suite")
if fp then
	fp.PromptButtonHoldBegan:Fire()
	fp.Triggered:Fire()
end
check(#NET.grab == sent + 2 and NET.grab[sent + 1] == "STORE_Test:6", "V4 posé : début et fin du maintien envoyés")
advance(0.5)
check(fp ~= nil and fp.Enabled == true, "V5 toujours allumée au tour suivant")}, 'pc-steal fin');
