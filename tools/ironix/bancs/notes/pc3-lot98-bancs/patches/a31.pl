# lot98 (petit chef 3) : Shared/ShopFloor, Config/ShopGrowth et Config/SkillTree posés dans le faux Roblox d'a31 (même
# arbre réduit qu'a22-core). Depuis a280, DataService lit Shared.ShopFloor au chargement d'un profil (migration ShopLayout,
# sous pcall : absent, avertissement « membre inconnu ShopFloor » que le banc refuse) et le checkFloor2 du ContractChecker
# attend Config/SkillTree. Les sources sont déjà dans SOURCES (dossier shared).
undef $/; $_ = <>;
if (/local ConfigF = folder\(Shared, "Config"\)/) {
	s/(local ConfigF = folder\(Shared, "Config"\)\nfor _, n in \{ "Balance", "Bat", "Cosmetics", "DeepFreeze", "Features", "Formulas", "ItemIdle", "Items", "Night", "PvP", "Rarities", "Shatter", "ShelfBoxes", )("Tools",)/$1"ShopGrowth", "SkillTree", $2/ or warn "lot98 : liste des Config d'a31 introuvable\n";
	s/(\nlocal ContractF = folder\(Shared, "Contract"\)\n)/\nmoduleScript(Shared, "ShopFloor", "shared\/ShopFloor.luau") -- lot98 : a280$1/ or warn "lot98 : dossier Contract d'a31 introuvable\n";
}
print;
