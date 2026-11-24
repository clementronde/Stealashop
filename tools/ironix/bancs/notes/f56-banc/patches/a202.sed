# fusion56 : la doublure d'ItemWeight du banc a202 s'appuie sur le vrai module d'a203 (Enabled, Effective, CappedScale…),
# que Mutations et les services appellent depuis la fusion ; Roll, ScaleFor, IncomeFactor, SizeMutationFor et SizeClassFor restent pilotés.
s/^SOURCES\["shared\/ItemWeight\.luau"\] = \[==\[(\r?)$/SOURCES["shared\/ItemWeightReal.luau"] = SOURCES["shared\/ItemWeight.luau"]\1\nSOURCES["shared\/ItemWeight.luau"] = [==[\1\nlocal W = table.clone(require(script.Parent.ItemWeightReal)) -- fusion56\1/
s/^local W = \{\}(\r?)$/-- (fusion56 : W vient du vrai module, ci-dessus)\1/
