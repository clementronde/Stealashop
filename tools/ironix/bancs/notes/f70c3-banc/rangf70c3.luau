-- f70c3 : après range252.luau. Guard/PathAvoid et Guard/Sidestep (f70c3b) dans le dossier Guard des services (celui de
-- CatchPickUp s'il existe).
for _, name in { "PathAvoid", "Sidestep" } do
	local key = "server/Services/Guard/" .. name .. ".luau"
	if SOURCES[key] then
		local guardFolder = SERVICES:FindFirstChild("Guard") or folder(SERVICES, "Guard")
		moduleScript(guardFolder, name, key)
	end
end
