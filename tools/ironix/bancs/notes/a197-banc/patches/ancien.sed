# a197 (vague 60) : remet les règles d'avant a197 dans Config/Tutorial du fichier assemblé : Passer finit le tuto,
# la flèche passe d'abord par la porte de sa boutique, pas de liste des tâches.
s/^(	SkipOneStep = )true,/\1false,/
s/^(	ArrowViaDoor = )false,/\1true,/
s/^(	TaskList = )true,/\1false,/
