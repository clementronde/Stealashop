-- a228 : expose la table locale `hidden` de ShopWallsService au test (ShopWallsService._hidden).
SOURCES["server/Services/ShopWallsService.luau"] = (string.gsub(SOURCES["server/Services/ShopWallsService.luau"], "\nreturn ShopWallsService%s*$", "\nShopWallsService._hidden = hidden\nreturn ShopWallsService\n"))
