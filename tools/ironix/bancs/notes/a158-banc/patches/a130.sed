# a158, banc a130 (Fortune Tower, vendeurs) : sans rayon d événement dans ce faux arbre, la vitrine s ouvre sans butin au sol.
s/check\(#fortuneDrops\(\) > 0, `F4d butin au sol \(\{#fortuneDrops\(\)\}\)`\)/check(#fortuneDrops() == 0, `F4d a158 : plus de butin au sol ({#fortuneDrops()})`)/
