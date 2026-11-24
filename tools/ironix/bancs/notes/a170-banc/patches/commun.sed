# a170 : Shared/InventoryState n'a plus de Boxes (vague 52) ; les aides des bancs qui le parcourent lisent une liste vide.
s/in (state|inv|inventory|current|st|s)\.Boxes do/in (\1.Boxes or {}) do/g
