# lot98 (petit chef 3) : Config/SkillTree posé dans le faux Roblox d'a22-core. Depuis a280 (checkFloor2), le ContractChecker
# fait require(Shared.Config:WaitForChild("SkillTree")) ; absent, le faux WaitForChild attend dans le fil principal et le
# banc s'arrête sans message à la section F (code 1). La source est déjà dans SOURCES (dossier shared).
undef $/; $_ = <>;
s/(for _, n in \{ "Balance", "Bat", "Cosmetics", "DeepFreeze", "Features", "Formulas", "ItemIdle", "Items", "Night", "PvP", "Rarities", "Shatter", "ShelfBoxes", )("Tools",)/$1"SkillTree", $2/ or warn "lot98 : liste des Config d'a22-core introuvable\n";
print;
