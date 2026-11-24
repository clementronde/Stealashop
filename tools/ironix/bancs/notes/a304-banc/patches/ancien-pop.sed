# a304 : Config/UiMotion d'avant le pop immédiat (OpenStagger et Appear.Cascade : From = 0,2, Start = 0,23 s).
s/^(\t\tFrom = )0(, -- validé par Cantin, 21\/11 \(tableau)/\1if VIDEO_RHYTHM then 0.2 else 0\2/
s/^(\t\tStart = if VIDEO_RHYTHM then )0( else 0\.08,)/\10.23\2/
s/^(\t\t\tStart = if VIDEO_RHYTHM then )0( else 0\.05,)/\10.23\2/
s/^(\t\t\tFrom = )0(, -- validé par Cantin, 21\/11 \(a304\))/\1if VIDEO_RHYTHM then 0.2 else 0\2/
