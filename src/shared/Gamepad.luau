--!strict
-- Shared/Gamepad (a419, client seulement ; demande de Cantin du 23/11, Config/Gamepad, Features.Gamepad) : aide commune
-- des contrôleurs pour la manette (rangée dans Shared comme Shared/HotbarLayout : présente dans tout arbre de banc).
--
-- « À la manette » = Features.Gamepad, Config/Gamepad présent, et UserInputService.PreferredInput = Gamepad (Roblox :
-- l'entrée que le joueur utilise vraiment, une manette sur PC compte dès qu'on s'en sert) ; sans PreferredInput, la
-- dernière entrée (GetLastInputType) est Gamepad1 à Gamepad8. Rien n'est lu ni branché sans Features.Gamepad : le clavier,
-- la souris et le tactile ne changent jamais. Config et Features sont cherchés au premier appel (absents : coupé).
--
-- API (client) :
--   Gamepad.IsActive() -> boolean                 le joueur joue à la manette
--   Gamepad.OnChanged(listener) -> () -> ()       listener(active) quand IsActive change ; renvoie la déconnexion
--   Gamepad.KeyText(key) -> string                nom court du bouton de la manette branchée, d'après
--                                                 UserInputService:GetStringForKeyCode sans « Button » : « A », « Cross »,
--                                                 « RB », « R1 »… (sinon le nom du KeyCode)
--   Gamepad.Config() -> Config/Gamepad?           nil sans Features.Gamepad ou sans Config/Gamepad

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Gamepad = {}

local GAMEPADS: { [string]: boolean } = {
	Gamepad1 = true, Gamepad2 = true, Gamepad3 = true, Gamepad4 = true,
	Gamepad5 = true, Gamepad6 = true, Gamepad7 = true, Gamepad8 = true,
}

local loaded: { [string]: any } = {} -- nom → module de Shared/Config trouvé (absent : cherché à l'appel suivant)

local function configModule(name: string): any
	local found = loaded[name]
	if found == nil then
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local folder = if shared then shared:FindFirstChild("Config") else nil
		local module = if folder then folder:FindFirstChild(name) else nil
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok and type(result) == "table" then
				found = result
				loaded[name] = result
			end
		end
	end
	return found
end

function Gamepad.Config(): any
	local features = configModule("Features")
	if features == nil or features.Gamepad ~= true then
		return nil
	end
	return configModule("Gamepad")
end

function Gamepad.IsActive(): boolean
	if Gamepad.Config() == nil then
		return false
	end
	local okPreferred, preferred = pcall(function(): any
		return (UserInputService :: any).PreferredInput
	end)
	if okPreferred and typeof(preferred) == "EnumItem" then
		return (preferred :: EnumItem).Name == "Gamepad"
	end
	local okLast, last = pcall(function(): any
		return UserInputService:GetLastInputType()
	end)
	return okLast and typeof(last) == "EnumItem" and GAMEPADS[(last :: EnumItem).Name] == true
end

local listeners: { (active: boolean) -> () } = {}
local watching = false
local lastActive = false

local function check()
	local active = Gamepad.IsActive()
	if active == lastActive then
		return
	end
	lastActive = active
	for _, listener in table.clone(listeners) do
		local ok, message = pcall(function()
			listener(active)
		end)
		if not ok then
			warn(`[Gamepad] changement d'entrée : {message}`)
		end
	end
end

function Gamepad.OnChanged(listener: (active: boolean) -> ()): () -> ()
	table.insert(listeners, listener)
	if not watching then
		watching = true
		lastActive = Gamepad.IsActive()
		pcall(function()
			UserInputService.LastInputTypeChanged:Connect(check)
		end)
		pcall(function()
			UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(check)
		end)
	end
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function Gamepad.KeyText(key: Enum.KeyCode): string
	local ok, text = pcall(function(): any
		return UserInputService:GetStringForKeyCode(key)
	end)
	local name = if ok and type(text) == "string" and text ~= "" then text else tostring((key :: any).Name or key)
	local short = string.gsub(name, "^Button", "")
	return if short ~= "" then short else name
end

return Gamepad
