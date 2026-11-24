-- a252 : après setup.luau. Guard/CatchPickUp dans un dossier Guard des services (le Loader ne démarre que les
-- ModuleScripts enfants directs) ; CatchScene/Shot (client) dans un dossier à part, chargé côté serveur du banc.
if SOURCES["server/Services/Guard/CatchPickUp.luau"] then
	moduleScript(folder(SERVICES, "Guard"), "CatchPickUp", "server/Services/Guard/CatchPickUp.luau")
end
if SOURCES["client/Controllers/CatchScene/Shot.luau"] then
	moduleScript(folder(SERVICES, "_a252Client"), "Shot", "client/Controllers/CatchScene/Shot.luau")
end
