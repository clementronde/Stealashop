# lot96 (a283, audit a271 point 12) : HubController écoute AncestryChanged de l'étiquette ; le faux Instance d'a160
# (fakes.luau) ne l'avait pas : signal ajouté (jamais tiré, l'étiquette reste dans le Workspace du banc).
undef $/; $_ = <>;
s/(\tlocal o = \{ ClassName = className, Name = name, Parent = nil, _children = \{\}, _attrs = \{\}, _attrSignals = \{\} \}\r?\n)/$1\to.AncestryChanged = signal()\n/;
print;
