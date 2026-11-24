# a181 : HoldItem entre au contrat (14 animations du joueur) ; AnimationController suit ChildRemoved du personnage (faux complété).
s/"4\/13 animation\(s\) préchargée\(s\)"/"4\/14 animation(s) préchargée(s)"/
s/^([[:space:]]*)ChildAdded = Signal\.new\(\),/\1ChildAdded = Signal.new(), ChildRemoved = Signal.new(),/
