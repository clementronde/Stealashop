--!nocheck
-- Mise en place du banc a152 (2026-11-14, vague 44), après celle d'a142 : vrai DisplayController (invites « Take »
-- et « Display » du propriétaire) et aides.
moduleScript(CONTROLLERS, "DisplayController", "client/Controllers/DisplayController.luau")

function takePromptOf(player, uid)
	local model = displayModelOf(player, uid)
	return if model then model:FindFirstChild("TakeDisplayPrompt", true) else nil
end
function slotPromptOf(player, index)
	local plot = shopOf(player)
	local attachment = plot and plot:FindFirstChild(string.format("DisplaySlot_%02d", index), true)
	return if attachment then attachment:FindFirstChild("DisplayHeldPrompt") else nil
end
-- Le joueur se tient à 3 studs du présentoir `index` de SA boutique, au sol.
function standBySlot(player, index)
	moveTo(player, refsOfShop(shopOf(player)).slots[index] + Vector3.new(0, -0.8, 3))
	advance(0.05)
end
function displayedAt(player, uid)
	for key, stored in dataOf(player).Display do
		if stored == uid then
			return tonumber(key)
		end
	end
	return nil
end
function trigger(prompt)
	prompt.Triggered:Fire()
	flush()
	advance(0.1)
end
function hotbarHas(uid)
	return slotsOf()["Slot_Item_" .. uid] ~= nil
end
-- Faux Roblox (ajout pur) : la caméra du banc n'a ni CFrame, ni champ, ni taille ; DisplayController (halos) les lit.
CAMERA.CFrame = CAMERA.CFrame or CFrame.new(0, 50, 0)
CAMERA.FieldOfView = CAMERA.FieldOfView or 70
CAMERA.ViewportSize = CAMERA.ViewportSize or Vector2.new(1280, 720)
