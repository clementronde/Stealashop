# lot98-commun (petit chef 2) : a412 (textes du jeu, vocabulaire « strength ») : le bandeau de zone dit « Strength N »
# (AdvicePanel.strengthText). Le garde-fou « pas « Strength » » d'avant (bandeau en « Damage ») est inversé.
undef $/; $_ = <>;
s/check\(not string\.find\(damage, "Strength"\), `zone \{zone\} : pas « Strength »`\)/check(string.find(damage, "Strength", 1, true) ~= nil, `zone {zone} : « Strength » (a412)`)/;
print;
