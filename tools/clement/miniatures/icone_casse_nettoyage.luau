--[[
	Nettoyage après icone_casse_scene.luau (MOD-043, 2026-11-21) : remet StarterGui.ShowDevelopmentGui à sa valeur
	d'avant, remet à leur valeur d'avant les LocalTransparencyModifier notés, puis supprime
	workspace.CurrentCamera._MINIATURE_TMP. Après lui, la place est exactement comme avant la mise en scène.
	Ne jamais enregistrer entre les deux.
]]
local SG = game:GetService("StarterGui")
local cam = workspace.CurrentCamera
local tmp = cam:FindFirstChild("_MINIATURE_TMP")
if not tmp then
	return "rien à nettoyer (ShowDevelopmentGui = " .. tostring(SG.ShowDevelopmentGui) .. ")"
end
local before = tmp:GetAttribute("ShowDevGuiAvant")
SG.ShowDevelopmentGui = if before ~= nil then before else true
local restored = 0
for _, v in tmp:GetDescendants() do
	if v:IsA("ObjectValue") and v.Name == "Hidden" and v.Value then
		(v.Value :: BasePart).LocalTransparencyModifier = v:GetAttribute("Old") or 0
		restored += 1
	end
end
tmp:Destroy()
return ("nettoyé : ShowDevelopmentGui = %s, %d pièce(s) rendue(s) visible(s), dossier supprimé"):format(tostring(SG.ShowDevelopmentGui), restored)
