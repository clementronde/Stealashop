# a197 (vague 60) : remet les règles d'avant a197 dans Config/Tutorial du fichier assemblé : Passer finit le tuto,
# la flèche passe d'abord par la porte de sa boutique, pas de liste des tâches.
s/^(	SkipOneStep = )true,/\1false,/
s/^(	ArrowViaDoor = )false,/\1true,/
s/^(	TaskList = )true,/\1false,/

# a199 (vague 61) : remet les règles d'avant a199 dans Config/Tutorial du fichier assemblé : attente de la fin du
# bouclier à l'étape 10 (et sa tâche), pas de don d'argent, 30 s de tapis, progression de Speed à l'étape 9.
s/^(local WAIT_SHIELD_END = )false/\1true/
s/^(	TrainDuration = )10,/\130,/
s/^(	GiftCash = )true,/\1false,/
s/^(	\[9\] = \{ Do = "Walk through the Zone 2 gate") \},/\1, Need = "Speed: {have} \/ {need} to outrun Zone 2 guards", NeedFormat = "Short" },/
