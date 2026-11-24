-- a416 : après rangf70c3.luau. Guard/ClientView dans le dossier Guard des services (celui de CatchPickUp s'il existe).
if SOURCES["server/Services/Guard/ClientView.luau"] then
	moduleScript(SERVICES:FindFirstChild("Guard") or folder(SERVICES, "Guard"), "ClientView", "server/Services/Guard/ClientView.luau")
end
