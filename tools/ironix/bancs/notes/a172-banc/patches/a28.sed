# a172 (vague 53), banc a28 (tuto) : UI_Unbox n existe plus (vague 52), TutorialController ne le compte plus parmi les écrans
# qui cachent la bulle : ouvert, il ne cache plus rien (les écrans des boutiques, juste après, la cachent toujours).
s/check\(screen\.Enabled == false and Controller\.GetState\(\)\.Arrow == false, "UI_Unbox ouvert : bulle et flèche cachées"\)/check(screen.Enabled == true and Controller.GetState().Arrow == true, "a172 : UI_Unbox ouvert (écran retiré) : bulle et flèche restent")/
