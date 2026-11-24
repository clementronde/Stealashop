# a158, banc a118 (antivol visible, pastilles) : la section « colis : à poser, puis posé, puis prêt » est retirée (plus de
# colis dans l inventaire ni au sol) ; les pastilles de l objet sous antivol restent vérifiées.
/^section\("colis : à poser, puis posé \(éteint\), puis prêt \(allumé\)"\)$/,/^section\("point 4 : PLACE de l.objet sous antivol, mode pose"\)$/{
/^section\("point 4 : PLACE/!d
}
