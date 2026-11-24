# a431 (L-332) : Labels qui se lisent seuls (Config/SkillTree), « None » au niveau 0 sans Labels[0], InfoPanel.NodeDesc facultatif.
#  - T2b, T2c, T2d, T3g, T4c, T4l, T4m, T4n, T4o : nouveaux textes attendus (56 hits, wall 1/4, 30s x-ray, None ▶ speed 20) ;
#  - K2a : l'écran construit reçoit NodeDesc (écran complet, comme livré ; sans lui, ligne jaune « facultatif ») ;
#  - D1, D2 (nouveaux) : NodeDesc reçoit la phrase de la compétence choisie (Cameras, puis Guards).
undef $/; $_ = <>;
s/(Text == )"Reinforced Door 56"(, "T2b )/$1"Reinforced Door 56 hits"$2/;
s/(Text == )"Walls I"(, "T2c )/$1"Walls wall 1\/4"$2/;
s/(Text == )"Cameras II"(, "T2d )/$1"Cameras 30s x-ray"$2/;
s/(Text == )"Reinforced Door 80"(, "T3g )/$1"Reinforced Door 80 hits"$2/;
s/(Text == )"56  ▶  64"(, "T4c )/$1"56 hits  ▶  64 hits"$2/;
s/(Text == )"II  ▶  III"( and panelEl\("NodeName"\)\.Text == "CAMERAS", "T4m )/$1"30s x-ray  ▶  30s radar"$2/;
s/(Text == )"—  ▶  I"(, "T4n )/$1"None  ▶  speed 20"$2/;
s/(NodeEffect"\)\.Text == )"I  ▶  II"( and [^\n]*"T4o )/$1"wall 1\/4  ▶  wall 2\/4"$2/;
s/(NodeEffect"\)\.Text == )"80  \(MAX\)"( and [^\n]*"T4l )/$1"80 hits  (MAX)"$2/;
# D1 et D2 juste après T4m et T4n.
s/(\ncheck\([^\n]*"T4m [^\n]*\n)/$1check(panelEl("NodeDesc") ~= nil and panelEl("NodeDesc").Text == "Warns you when someone hits your door. Level 2 shows the thief through walls, level 3 adds a radar.", "a431 D1 Cameras : NodeDesc = la phrase de Config\/SkillTree")\n/;
s/(\ncheck\([^\n]*"T4n [^\n]*\n)/$1check(panelEl("NodeDesc") ~= nil and string.sub(panelEl("NodeDesc").Text, 1, 22) == "A guard stands in your", "a431 D2 Guards : NodeDesc suit la tuile choisie")\n/;
# NodeDesc posé dans le constructeur de l'écran (toutes les parties du banc, K2a compris).
s/(\n\tNEW\("TextLabel", \{ Name = "NodeEffect"[^\n]*\n)/$1\tNEW("TextLabel", { Name = "NodeDesc", Text = "" }, panel) -- a431\n/;
print;
