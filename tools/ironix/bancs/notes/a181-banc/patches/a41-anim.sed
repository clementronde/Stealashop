# a181 : AnimationController suit ChildRemoved du personnage (objet tenu, HoldItem) : faux complété.
s/^([[:space:]]*)ChildAdded = Signal\.new\(\),/\1ChildAdded = Signal.new(), ChildRemoved = Signal.new(),/
