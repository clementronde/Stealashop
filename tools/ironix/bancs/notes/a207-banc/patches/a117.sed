# a207 (L-201 point 3) : ClaimLabel « CLAIMED » une fois la zone réclamée.
s/textOf\(claim, "ClaimLabel"\) == "Claimed!"/textOf(claim, "ClaimLabel") == "CLAIMED"/g
s/"Unlocked: ([0-9]+)\/83"/"\1 \/ 83 discovered"/g
