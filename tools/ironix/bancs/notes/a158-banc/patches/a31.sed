# a158, banc a31 (catalogue v2) : DataService.convertBoxes tourne maintenant sans condition au chargement. Le faux arbre
# de ce banc n a pas Config/Mutations (lu par convertBoxes) : la conversion y échoue proprement, avec son avertissement
# « conversion des colis impossible … colis gardés », le seul avertissement de DataService permis par ce contrôle.
/aucune ligne de migration des ItemId ni avertissement de DataService/s/logCount\("\[DataService\]", "WARN"\) == 0/logCount("[DataService]", "WARN") == logCount("conversion des colis impossible", "WARN")/
