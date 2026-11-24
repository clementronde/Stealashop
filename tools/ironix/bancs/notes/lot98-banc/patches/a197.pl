# lot98-commun (petit chef 2) : a412 (textes anglais) : « Train: {have} / {need} to get faster » devient « Train {have} / {need} ».
undef $/; $_ = <>;
s/TutorialTasks\.Line\(6, 12, 30\) == "Train: 12s \/ 30s to get faster"/TutorialTasks.Line(6, 12, 30) == "Train 12s \/ 30s"/ or die "a197.pl : étape 6 absente\n";
print;
