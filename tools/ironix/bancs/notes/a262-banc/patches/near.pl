# a262 : ajoute A262_NEAR(a, b) (écart < 0,0001) au fichier assemblé ; les revenus de la vague 76 ne sont plus entiers.
$t = "A262_NEAR = function(a: any, b: number): boolean\n\treturn type(a) == \"number\" and math.abs(a - b) < 1e-4\nend\n" . $t unless has('A262_NEAR = function');
