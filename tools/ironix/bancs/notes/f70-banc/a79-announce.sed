/^local Services = folder\(folder\(ServerScriptService, "Server"\), "Services"\)$/i\
-- fusion70 (a254, L-240 point 3) : Shared/Announce et Config/Announce, requis par StoreHeistService (s'ils existent).\
if SOURCES["shared/Announce.luau"] then\
	moduleScript(ConfigF, "Announce", "shared/Config/Announce.luau")\
	moduleScript(Shared, "Announce", "shared/Announce.luau")\
end
