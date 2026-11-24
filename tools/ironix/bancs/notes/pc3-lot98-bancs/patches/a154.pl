# lot98 (petit chef 3) : après lot96-banc/patches/a154.pl (qui ajoute les remotes d'a314 et a410), les remotes ajoutés
# après ItemSecured par le lot 98 : FunnelStep (a414), Disguise et Denounce (a411). GlassThrow (a315) est avant ItemSecured.
undef $/; $_ = <>;
s/(ReportFocus = true) \}/$1, FunnelStep = true, Disguise = true, Denounce = true }/ or warn "lot98 : liste des remotes d'a154 introuvable\n";
print;
