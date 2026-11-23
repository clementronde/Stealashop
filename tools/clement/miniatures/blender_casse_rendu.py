# Rendu Blender de la casse (MOD-043, miniature 01, 2026-11-22) à partir de l'OBJ exporté de Studio.
# Scène posée par blender_casse_scene.luau puis exportée par Clément (« Export Selection » : _MINIATURE_TMP et la
# Bijouterie). Studio n'exporte ni les vêtements ni les textures de l'avatar : ils sont recolorés ici (haut noir,
# cravate bleue, pantalon sombre, baskets blanches, cagoule noire et yeux). Les grands éclats de la vitre (invisibles
# avant la casse, donc absents de l'export) sont recréés ici autour du point d'impact.
# Lancer : "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" -b --factory-startup --python
#          tools/clement/miniatures/blender_casse_rendu.py -- <casse.obj> <sortie.png> [largeur] [échantillons]
import math
import random
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OBJ, SORTIE = argv[0], argv[1]
LARGEUR = int(argv[2]) if len(argv) > 2 else 1920
ECHANTILLONS = int(argv[3]) if len(argv) > 3 else 96

# Repères de la scène (coordonnées Blender = Roblox x, -z, y)
IMPACT = Vector((438.5, -54.4, 3.94))  # où la masse touche la vitre (blender_casse_scene.luau)
VITRE_Y = -54.75  # plan de la vitre
COURONNE = Vector((447.5, -58.5, 5.2))
CAMERA = Vector((443.9, -63.8, 4.7))
CIBLE = Vector((442.4, -52.0, 4.4))
OBJECTIF_MM = 22
SOCLE_DECALAGE = Vector((-0.3, 2.6, 0))  # socle et Couronne collés contre la vitrine, à droite
MASSE_ECHELLE = 1.5  # masse grossie autour de la main, pour se lire en petit (comme sur les versions IA)
MAIN_DROITE = Vector((438.81, -52.46, 2.54))  # centre de la main droite (objet R15BaconHair13)
TETE_MASSE = Vector((438.42, -53.77, 4.32))  # centre de la tête de la masse (objet Head1)
MISE_AU_POINT = Vector((440.0, -51.3, 3.6))  # le perso

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=OBJ, forward_axis="NEGATIVE_Z", up_axis="Y", use_split_objects=True, use_split_groups=True)
O = bpy.data.objects


def matiere(nom, couleur, rugosite=0.5, metal=0.0, emission=None, force=0.0, transmission=0.0, ior=1.45):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*couleur, 1)
    b.inputs["Roughness"].default_value = rugosite
    b.inputs["Metallic"].default_value = metal
    if transmission:
        b.inputs["Transmission Weight"].default_value = transmission
        b.inputs["IOR"].default_value = ior
    if emission:
        b.inputs["Emission Color"].default_value = (*emission, 1)
        b.inputs["Emission Strength"].default_value = force
    return m


def donner(o, m):
    if o is None:
        return
    o.data.materials.clear()
    o.data.materials.append(m)


def points(o):
    return np.array([tuple(o.matrix_world @ v.co) for v in o.data.vertices])


def repere(o, vers_camera):
    """Axes d'une pièce en forme de boîte (analyse en composantes) : avant (le plus mince, tourné vers la caméra),
    haut (le plus vertical), droite ; plus le centre et la demi-épaisseur vers l'avant."""
    p = points(o)
    c = p.mean(axis=0)
    _, v = np.linalg.eigh(np.cov((p - c).T))
    axes = [Vector(v[:, i]).normalized() for i in range(3)]
    avant = axes[0]
    if avant.dot(vers_camera) < 0:
        avant = -avant
    reste = sorted(axes[1:], key=lambda a: -abs(a.z))
    haut = reste[0] if reste[0].z > 0 else -reste[0]
    droite = haut.cross(avant).normalized()
    demi = max((Vector(tuple(q)) - Vector(tuple(c))).dot(avant) for q in p)
    return Vector(tuple(c)), avant, haut, droite, demi


def boite(nom, centre, droite, avant, haut, taille, m):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    o.name = nom
    rot = Matrix((droite, avant, haut)).transposed().to_4x4()
    o.matrix_world = Matrix.Translation(centre) @ rot @ Matrix.Diagonal((*taille, 1))
    donner(o, m)
    return o


def boule(nom, centre, droite, avant, haut, rayons, m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1)
    o = bpy.context.active_object
    o.name = nom
    rot = Matrix((droite, avant, haut)).transposed().to_4x4()
    o.matrix_world = Matrix.Translation(centre) @ rot @ Matrix.Diagonal((*rayons, 1))
    bpy.ops.object.shade_smooth()
    donner(o, m)
    return o


# --- matières ---
NOIR_HAUT = matiere("Haut", (0.018, 0.018, 0.022), 0.6)
NOIR_BAS = matiere("Pantalon", (0.03, 0.032, 0.04), 0.7)
PEAU = matiere("Peau", (0.95, 0.83, 0.68), 0.5)
BLANC = matiere("Baskets", (0.92, 0.92, 0.93), 0.45)
BLEU = matiere("Cravate", (0.02, 0.32, 0.95), 0.4)
CAGOULE = matiere("Cagoule", (0.015, 0.015, 0.018), 0.95)
CHEVEUX = matiere("Cheveux", (0.45, 0.17, 0.04), 0.55)
OEIL = matiere("Oeil", (1, 1, 1), 0.3)
PUPILLE = matiere("Pupille", (0.01, 0.01, 0.01), 0.2)
VERRE = matiere("Verre", (0.75, 0.9, 1.0), 0.03, transmission=1.0, ior=1.45)
OR = matiere("Or", (1.0, 0.68, 0.12), 0.22, metal=1.0)
CADRE = matiere("Cadre", (1.0, 0.74, 0.22), 0.3, metal=0.35)
VELOURS = matiere("Velours", (0.5, 0.0, 0.03), 0.85)
PERLES = matiere("Perles", (0.96, 0.93, 0.86), 0.25)
METAL_MASSE = matiere("TeteMasse", (0.05, 0.05, 0.07), 0.3, metal=0.7)
NEON = matiere("Neon", (1.0, 0.2, 0.75), 0.3, emission=(1.0, 0.25, 0.8), force=8.0)
MANCHE = matiere("Manche", (0.3, 0.06, 0.8), 0.35)
FLASH = matiere("Flash", (1, 1, 1), 0.5, emission=(1, 1, 1), force=40.0)

# --- avatar (pièces de l'export : R15BaconHair1 à 15, voir la note) ---
for i in range(1, 16):
    donner(O.get(f"R15BaconHair{i}"), NOIR_HAUT)
for n in ("R15BaconHair1", "R15BaconHair4", "R15BaconHair6", "R15BaconHair7", "R15BaconHair10"):
    donner(O.get(n), NOIR_BAS)  # jambes et bassin
for n in ("R15BaconHair5", "R15BaconHair8"):
    donner(O.get(n), BLANC)  # pieds : baskets blanches
for n in ("R15BaconHair9", "R15BaconHair13", "R15BaconHair2"):
    donner(O.get(n), PEAU)  # mains et tête (cachée par la cagoule)
donner(O.get("Minicagouletete1"), CAGOULE)
donner(O.get("Handle2"), CHEVEUX)  # cheveux Pal Hair

vers_cam = (CAMERA - IMPACT).normalized()
torse = O.get("R15BaconHair3")
if torse:
    c, avant, haut, droite, demi = repere(torse, vers_cam)
    boite("Cravate", c + avant * (demi + 0.02) - haut * 0.05, droite, avant, haut, (0.26, 0.05, 1.15), BLEU)
    boite("Noeud", c + avant * (demi + 0.03) + haut * 0.52, droite, avant, haut, (0.3, 0.07, 0.22), BLEU)
    tete = O.get("Minicagouletete1")
    if tete:
        pts = points(tete)
        ct = Vector(tuple(pts.mean(axis=0)))
        demi_t = max((Vector(tuple(q)) - ct).dot(avant) for q in pts)
        for cote in (-1, 1):
            base = ct + haut * 0.12 + droite * (0.24 * cote) + avant * (demi_t - 0.02)
            boule(f"Oeil{cote}", base, droite, avant, haut, (0.15, 0.06, 0.13), OEIL)
            boule(f"Pupille{cote}", base + avant * 0.05 + droite * (0.03 * cote) - haut * 0.02, droite, avant, haut, (0.06, 0.03, 0.07), PUPILLE)

# --- masse ---
donner(O.get("Head1"), METAL_MASSE)
donner(O.get("Faces1"), METAL_MASSE)
donner(O.get("Glow1"), NEON)
donner(O.get("Shaft1"), MANCHE)
donner(O.get("Handle1"), matiere("Poignee", (0.08, 0.02, 0.22), 0.6))
grossir = Matrix.Translation(MAIN_DROITE) @ Matrix.Scale(MASSE_ECHELLE, 4) @ Matrix.Translation(-MAIN_DROITE)
for n in ("Head1", "Faces1", "Glow1", "Shaft1", "Handle1"):
    o = O.get(n)
    if o:
        o.matrix_world = grossir @ o.matrix_world
TETE_MASSE = MAIN_DROITE + (TETE_MASSE - MAIN_DROITE) * MASSE_ECHELLE
# caisson du rideau de fer au-dessus de la vitrine : retiré, il barrait le ciel
for o in list(O):
    if o.type == "MESH" and o.name.startswith(("Slat", "Bottombar", "Winstripe", "Winvalance", "Awningtrim")):
        bpy.data.objects.remove(o)  # et le store au-dessus de la vitrine

# --- couronne et socle ---
donner(O.get("Gold1"), OR)
donner(O.get("Velvet1"), VELOURS)
donner(O.get("Pearls1"), PERLES)
donner(O.get("Gemsblue1"), matiere("GemmeBleue", (0.05, 0.2, 1.0), 0.1, emission=(0.1, 0.3, 1.0), force=1.5))
donner(O.get("Gemsred1"), matiere("GemmeRouge", (0.8, 0.0, 0.1), 0.1, emission=(1.0, 0.05, 0.2), force=1.5))
donner(O.get("Soclevitre1"), matiere("VerreVitrine", (0.9, 0.96, 1.0), 0.0, transmission=1.0, ior=1.08))
donner(O.get("Soclepied1"), matiere("Socle", (0.035, 0.035, 0.045), 0.4))
donner(O.get("Socleplateau1"), OR)
donner(O.get("Soclecoussin1"), VELOURS)
for n in ("Gold1", "Velvet1", "Pearls1", "Gemsblue1", "Gemsred1", "Soclevitre1", "Soclepied1", "Socleplateau1", "Soclecoussin1"):
    o = O.get(n)
    if o:
        o.location += SOCLE_DECALAGE
COURONNE = COURONNE + SOCLE_DECALAGE

# --- vitrine : cadre doré, cubes de verre, éclats recréés ---
for n in ("Frameb1", "Framel1", "Framer1", "Framet1"):
    donner(O.get(n), CADRE)
for o in list(O):
    if o.type == "MESH" and o.name.startswith("Cube") and o.name.endswith("1") and o.name[4:-1].isdigit():
        cdc = sum((o.matrix_world @ Vector(c) for c in o.bound_box), Vector()) / 8
        if (cdc - TETE_MASSE).length < 0.9:
            bpy.data.objects.remove(o)  # la tête de la masse reste visible
        else:
            donner(o, VERRE)
rnd = random.Random(7)
for i in range(46):
    d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1.6, -0.25), rnd.uniform(-0.6, 1.0))).normalized()
    dist = rnd.uniform(0.3, 5.2)
    centre = IMPACT + d * dist + Vector((0, -0.2, 0))
    if (centre - TETE_MASSE).length < 1.0:
        continue
    taille = rnd.uniform(0.25, 1.1) * (1.15 - dist / 6.5)
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=taille, radius2=0, depth=0.04)
    e = bpy.context.active_object
    e.name = f"Eclat{i}"
    e.location = centre
    e.rotation_euler = (rnd.uniform(0, 6.3), rnd.uniform(0, 6.3), rnd.uniform(0, 6.3))
    e.scale = (1, rnd.uniform(0.35, 1.0), 1)
    donner(e, VERRE)

# --- flash blanc à l'impact (le jeu en fait un à la casse) ---
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=IMPACT + Vector((-0.35, -0.3, -0.1)))
donner(bpy.context.active_object, FLASH)
bpy.ops.object.light_add(type="POINT", location=IMPACT + Vector((0, -0.6, 0)))
flash = bpy.context.active_object
flash.data.energy = 900
flash.data.color = (1, 0.97, 0.95)
flash.data.shadow_soft_size = 0.4
flash.visible_camera = False

# --- halo de la Couronne (Épique, violet) ---
bpy.ops.object.light_add(type="POINT", location=COURONNE + Vector((0, 1.6, 0.4)))
halo = bpy.context.active_object
halo.data.energy = 350
halo.data.color = (0.66, 0.33, 0.97)
halo.data.shadow_soft_size = 1.2
halo.visible_camera = False
halo.visible_glossy = False
halo.visible_transmission = False
flash.visible_glossy = False
flash.visible_transmission = False

# --- sol de la rue, ciel, soleil, lumière intérieure ---
bpy.ops.mesh.primitive_plane_add(size=400, location=(440, 80, 0.42))
donner(bpy.context.active_object, matiere("Rue", (0.42, 0.45, 0.5), 0.8))
monde = bpy.data.worlds.new("Ciel")
bpy.context.scene.world = monde
monde.use_nodes = True
nt = monde.node_tree
fond = nt.nodes.get("Background")
fond.inputs["Strength"].default_value = 1.0
# ciel en dégradé : bleu soutenu en haut, plus clair à l'horizon
coord = nt.nodes.new("ShaderNodeTexCoord")
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
rampe = nt.nodes.new("ShaderNodeValToRGB")
rampe.color_ramp.elements[0].position = 0.0
rampe.color_ramp.elements[0].color = (0.5, 0.78, 1.0, 1)
rampe.color_ramp.elements[1].position = 0.3
rampe.color_ramp.elements[1].color = (0.04, 0.3, 1.0, 1)
nt.links.new(coord.outputs["Generated"], sep.inputs[0])
nt.links.new(sep.outputs["Z"], rampe.inputs["Fac"])
nt.links.new(rampe.outputs["Color"], fond.inputs["Color"])
bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(-12), math.radians(200)))
soleil = bpy.context.active_object
soleil.data.energy = 5.5
soleil.data.color = (1.0, 0.95, 0.86)
soleil.data.angle = math.radians(4)
bpy.ops.object.light_add(type="AREA", location=(443, -66, 9))
interieur = bpy.context.active_object
interieur.data.energy = 9000
interieur.data.size = 12
interieur.data.color = (1.0, 0.93, 0.85)
interieur.rotation_euler = (math.radians(-75), 0, 0)
# contre-jour depuis la rue, en haut à gauche, pour détacher le perso du ciel
bpy.ops.object.light_add(type="AREA", location=(435.5, -44.0, 9.5))
contre = bpy.context.active_object
contre.data.energy = 2500
contre.data.size = 4
contre.data.color = (1.0, 0.92, 0.8)
contre.rotation_euler = (CIBLE - contre.location).to_track_quat("-Z", "Y").to_euler()
contre.visible_camera = False

# --- caméra ---
bpy.ops.object.camera_add(location=CAMERA)
cam = bpy.context.active_object
dir_vue = CIBLE - CAMERA
cam.rotation_euler = dir_vue.to_track_quat("-Z", "Y").to_euler()
cam.data.lens = OBJECTIF_MM
cam.data.clip_end = 1000
cam.data.dof.use_dof = True
cam.data.dof.focus_distance = (MISE_AU_POINT - CAMERA).length
cam.data.dof.aperture_fstop = 2.2
bpy.context.scene.camera = cam

# --- rendu ---
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = ECHANTILLONS
sc.cycles.use_denoising = True
sc.render.resolution_x = LARGEUR
sc.render.resolution_y = LARGEUR * 9 // 16
sc.render.film_transparent = False
sc.view_settings.view_transform = "AgX"
try:
    sc.view_settings.look = "AgX - Punchy"
except TypeError:
    pass
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA", "HIP", "ONEAPI"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            if any(d.type == kind for d in prefs.devices):
                for d in prefs.devices:
                    d.use = d.type == kind
                sc.cycles.device = "GPU"
                print("GPU", kind)
                break
        except TypeError:
            continue
except Exception as err:  # pas de GPU : le processeur suffit
    print("CPU", err)
sc.render.filepath = SORTIE
bpy.ops.render.render(write_still=True)
print("RENDU", SORTIE)
