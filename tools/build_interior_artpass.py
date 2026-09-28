"""Deterministic original interior assets. Run Blender --background --python this_file."""
import bpy, math, os, random
from mathutils import Vector
BASE=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(BASE,'assets','furniture','artpass')
os.makedirs(OUT,exist_ok=True)
random.seed(26)
def clear():
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name, rgb, rough=.6, metal=0, normal=None):
 m=bpy.data.materials.new(name); m.use_nodes=True
 m.diffuse_color=(*rgb,1); m.roughness=rough; m.metallic=metal
 # Blender localizes default node names (e.g. Russian UI). Find by stable type.
 p=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
 if p is None:
  p=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
  output=m.node_tree.get_output_node('ALL') or m.node_tree.nodes.new('ShaderNodeOutputMaterial')
  m.node_tree.links.new(p.outputs['BSDF'],output.inputs['Surface'])
 p.inputs['Base Color'].default_value=(*rgb,1); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
 if normal:
  path=os.path.join(BASE,'assets','textures',normal+'_normal.jpg')
  if os.path.isfile(path):
   im=bpy.data.images.load(path,check_existing=True); im.colorspace_settings.name='Non-Color'
   if max(im.size)>512: im.scale(512,512)
   tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im
   nm=m.node_tree.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=.22
   m.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color']); m.node_tree.links.new(nm.outputs['Normal'],p.inputs['Normal'])
 return m
sage=mat('Atelier_Sage_Linen',(.12,.19,.155),.93,normal='fabric')
seam=mat('Atelier_Linen_Piping',(.075,.115,.09),.98)
rust=mat('Atelier_Terracotta_Linen',(.32,.115,.064),.91,normal='fabric')
cream=mat('Atelier_Natural_Linen',(.57,.49,.37),.94,normal='fabric003')
wood=mat('Atelier_Smoked_Oak',(.16,.082,.036),.48,normal='wood003')
edge=mat('Atelier_Oak_Endgrain',(.09,.045,.018),.58)
metal=mat('Atelier_Blackened_Steel',(.025,.029,.027),.32,.7)
brass=mat('Atelier_Brushed_Brass',(.34,.22,.08),.32,.75)
blue=mat('Atelier_Ink',(.065,.115,.16),.83)
paper=mat('Atelier_Paper',(.62,.56,.43),.94)
def g(p): return (p[0],-p[2],p[1])
def box(name,p,s,m,b=.015):
 bpy.ops.mesh.primitive_cube_add(size=1,location=g(p)); o=bpy.context.object; o.name=name; o.dimensions=(s[0],s[2],s[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(m)
 for face in o.data.polygons: face.use_smooth=True
 if b:
  mod=o.modifiers.new('Soft manufactured edges','BEVEL'); mod.width=b; mod.segments=6
  mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); mod.keep_sharp=True
 return o

def tube(name,pts,r,m):
 c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.resolution_u=2; c.bevel_depth=r; c.bevel_resolution=2
 sp=c.splines.new('POLY'); sp.points.add(len(pts)-1)
 for v,p in zip(sp.points,pts): v.co=(*g(p),1)
 o=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(o); o.data.materials.append(m); return o

def export(name):
 # glTF applies bevels; each asset contains only its own selected geometry.
 bpy.ops.object.select_all(action='SELECT')
 for o in list(bpy.context.selected_objects):
  if o.type=='CURVE':
   bpy.context.view_layer.objects.active=o; bpy.ops.object.convert(target='MESH')
 bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'.glb'),export_format='GLB',use_selection=True,export_apply=True,export_cameras=False,export_lights=False)
 print('ARTPASS_ASSET_OK '+name)
clear()
# Model faces local -Z, matching the source sofa.
box('Upholstered frame',(0,.29,0),(2.15,.34,.88),sage,.075)
box('Padded back',(0,.79,.34),(2.15,.74,.22),sage,.09)
for x in [-.99,.99]: box('Rounded arm',(x,.63,0),(.23,.61,.90),sage,.075)
for x in [-.465,.465]:
 box('Independent seat cushion',(x,.57,-.075),(.90,.21,.68),sage,.085)
 box('Back cushion',(x,.9,.205),(.9,.45,.20),sage,.075)
 # Stitched border follows the rounded seat outline.
 pts=[]
 for cx,cz,start in [(x+.37,.18,0),(x-.37,.18,90),(x-.37,-.33,180),(x+.37,-.33,270)]:
  for a in range(start,start+91,15): pts.append((cx+.045*math.cos(math.radians(a)),.64,cz+.045*math.sin(math.radians(a))))
 pts.append(pts[0]); tube('Seat piping',pts,.003,seam)
for x,z in [(-.84,-.29),(.84,-.29),(-.84,.29),(.84,.29)]:box('Oak foot',(x,.085,z),(.08,.17,.08),wood,.012)
for x,m,angle in [(-.62,rust,-.16),(.60,cream,.18)]:
 o=box('Soft scatter cushion',(x,.88,-.01),(.39,.40,.15),m,.07); o.rotation_euler[1]=angle
export('sofa')
clear()
box('Solid oak top',(0,.425,0),(1.12,.065,.72),wood,.03)
box('Recessed lower shelf',(0,.15,0),(.94,.035,.55),wood,.012)
for x in [-.46,.46]:
 for z in [-.26,.26]:box('Steel leg',(x,.205,z),(.032,.41,.032),metal,.006)
box('Remote',( .20,.47,.02),(.085,.025,.23),metal,.012)
for i in range(4):box('Remote key',(.20,.485,-.04+i*.027),(.035,.004,.013),cream,.002)
export('coffee_table')
clear()
for x in [-.72,.72]:
 for z in [-.15,.15]:box('Tapered foot',(x,.065,z),(.045,.13,.045),metal,.008)
box('Cabinet carcass',(0,.4,0),(1.68,.54,.42),edge,.012)
box('Oak cap',(0,.691,0),(1.70,.035,.44),wood,.01)
for x in [-.42,.42]:
 box('Door',(x,.4,-.226),(.81,.49,.033),wood,.007)
 for i in range(12):box('Fluted door batten',(x-.366+i*.066,.40,-.247),(.028,.45,.016),wood,.006)
 box('Brass pull',(x+.29,.44,-.268),(.012,.14,.023),brass,.005)
export('tv_console')
clear()
box('Recessed back',(0,.92,.05),(1.55,1.78,.04),edge,.008)
for x in [-.775,.775]:box('Side',(x,.91,-.12),(.08,1.82,.42),wood,.012)
for row in range(4):
 y=.13+row*.53; box('Shelf',(0,y,-.12),(1.55,.045,.42),wood,.008)
 if row<3:
  for i in range(7):
   h=.21+random.random()*.12; x=-.6+i*.095
   box('Book pages',(x,y+.025+h/2,-.17),(.065,h,.21),paper,.003)
   for dx in [-.037,.037]:box('Book cover',(x+dx,y+.025+h/2,-.17),(.008,h+.008,.22),[blue,rust,sage][(row+i)%3],.002)
   box('Book spine',(x,y+.025+h/2,-.282),(.082,h+.008,.012),[blue,rust,sage][(row+i)%3],.003)
export('bookshelf')
clear()
box('Oak desk top',(0,.76,0),(2.35,.10,.72),wood,.02)
box('Pedestal',(-.91,.36,0),(.42,.70,.66),edge,.012)
for i in range(3):
 y=.59-i*.22;box('Drawer',(-.91,y,.34),(.38,.19,.025),sage,.008);box('Pull',(-.91,y,.363),(.15,.012,.018),brass,.004)
for z in [-.27,.27]:box('Steel frame upright',(.99,.36,z),(.04,.72,.04),metal,.005)
box('Steel frame foot',(.99,.025,0),(.05,.04,.59),metal,.005)
export('desk')
# Curtain panels use actual woven folds, a soft drape and weighted lower hems.
clear()
for side in [-1,1]:
 verts=[]; faces=[]; nx=48; ny=24
 for j in range(ny+1):
  v=j/ny
  for i in range(nx+1):
   u=i/nx; x=side*1.42+(u-.5)*(.49+.075*v)
   y=2.72-2.40*v + .018*math.cos(u*math.tau*4)*v**8
   z=.16+.055*math.cos(u*math.tau*6)+.018*math.sin(v*math.pi)
   verts.append(g((x,y,z)))
 for j in range(ny):
  for i in range(nx):
   a=j*(nx+1)+i; faces.append((a,a+1,a+nx+2,a+nx+1))
 me=bpy.data.meshes.new('Curtain folds');me.from_pydata(verts,[],faces);me.update()
 ob=bpy.data.objects.new('Linen curtain',me);bpy.context.collection.objects.link(ob);me.materials.append(cream)
 for p in me.polygons:p.use_smooth=True
 so=ob.modifiers.new('Cloth thickness','SOLIDIFY');so.thickness=.002
 for v in [.97,.985]:tube('Weighted hem',[(side*1.42+(i/nx-.5)*(.49+.075*v),2.72-2.4*v+.018*math.cos(i/nx*math.tau*4)*v**8,.163+.055*math.cos(i/nx*math.tau*6)+.018*math.sin(v*math.pi)) for i in range(nx+1)],.0025,cream)
export('curtains')
print('ARTPASS_BUILD_COMPLETE')

# Botanical silhouette with curved branches and individually shaped leaves.
clear()
terracotta=mat('Atelier_Stoneware',(.27,.16,.10),.74)
soil=mat('Atelier_Soil',(.027,.019,.011),1)
leafmat=mat('Atelier_Leaf',(.035,.115,.045),.57)
bpy.ops.mesh.primitive_cone_add(vertices=48,radius1=.17,radius2=.215,depth=.39,location=g((0,.215,0)))
o=bpy.context.object;o.name='Ceramic planter';o.data.materials.append(terracotta)
b=o.modifiers.new('Pot rim bevel','BEVEL');b.width=.012;b.segments=3
for p in o.data.polygons:p.use_smooth=True
bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.196,depth=.018,location=g((0,.409,0)));bpy.context.object.data.materials.append(soil)
for branch in range(9):
 a=branch*2.399; h=.67+branch*.058; dx=math.cos(a)*.25; dz=math.sin(a)*.25
 tube('Curving stem',[(0,.41,0),(dx*.25,h*.7,dz*.25),(dx,h,dz)],.008,leafmat)
 for j in range(3):
  aa=a+(j-1)*1.0; origin=Vector(g((dx,h-.1*j,dz)));direction=Vector(g((math.cos(aa)*.18,.15,math.sin(aa)*.18)))
  verts=[];faces=[]
  for k in range(13):
   t=k/12; width=math.sin(t*math.pi)**.8*.067
   center=origin+direction*t;center.z+=.035*math.sin(t*math.pi)
   for side in [-1,0,1]:verts.append(tuple(center+Vector((-math.sin(aa)*width*side,-math.cos(aa)*width*side,-.016*abs(side)*math.sin(t*math.pi)))))
  for k in range(12):
   for s in range(2):q=k*3+s;faces.append((q,q+1,q+4,q+3))
  me=bpy.data.meshes.new('Leaf');me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new('Ficus leaf',me);bpy.context.collection.objects.link(ob);me.materials.append(leafmat)
  for p in me.polygons:p.use_smooth=True
  mod=ob.modifiers.new('Leaf thickness','SOLIDIFY');mod.thickness=.001
export('plant')
clear()
box('Upholstered seat',(0,.52,0),(.55,.13,.52),blue,.065)
box('Upholstered back',(0,.88,.20),(.51,.62,.095),blue,.045)
box('Back support',(0,.66,.23),(.045,.48,.04),metal,.008)
box('Gas lift',(0,.27,0),(.055,.44,.055),metal,.015)
for i in range(5):
 a=i*math.tau/5;dx=math.cos(a)*.31;dz=math.sin(a)*.31
 tube('Star base',[(0,.14,0),(dx,.075,dz)],.022,metal)
 box('Caster',(dx,.046,dz),(.06,.085,.06),metal,.025)
for x in [-.31,.31]:
 box('Arm upright',(x,.60,.10),(.035,.27,.035),metal,.006)
 box('Arm pad',(x,.735,-.025),(.07,.045,.30),metal,.019)
export('office_chair')
for name,w,h,d,drawers in [('nightstand',.62,.67,.52,2),('dresser',1.25,.94,.52,3)]:
 clear();box('Carcass',(0,h/2,0),(w,h-.06,d),edge,.013)
 box('Oak top',(0,h,0),(w+.02,.035,d+.02),wood,.012)
 for i in range(drawers):
  dh=(h-.14)/drawers;y=.10+dh*(i+.5)
  box('Drawer front',(0,y,-d/2-.012),(w-.04,dh-.018,.035),wood,.008)
  box('Brass handle',(0,y,-d/2-.040),(w*.22,.014,.025),brass,.005)
 export(name)
clear()
# Authored directly in the existing bed root's coordinates; Rita stays intact.
box('Timber bed frame',(0,.34,0),(2.55,.58,1.55),wood,.035)
box('Upholstered headboard',(-1.20,.88,0),(.16,1.34,1.55),cream,.065)
box('Mattress',(0,.68,0),(2.42,.30,1.45),cream,.10)
for z in [-.37,.37]:box('Sleeping pillow',(-.88,.87,z),(.47,.15,.56),cream,.07)
# Closed duvet with low-amplitude folds, bevelled border and a rolled top edge.
verts=[];faces=[];nx=48;nz=30
for j in range(nz+1):
 z=-.41+j/nz*1.08
 for i in range(nx+1):
  x=-.60+i/nx*1.73
  y=.872+.016*math.sin(x*12+z*7)+.008*math.sin(x*23-z*13)
  verts.append(g((x,y,z)))
for j in range(nz):
 for i in range(nx):
  q=j*(nx+1)+i;faces.append((q,q+1,q+nx+2,q+nx+1))
me=bpy.data.meshes.new('Duvet folds');me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new('Draped duvet',me);bpy.context.collection.objects.link(ob);me.materials.append(sage)
for p in me.polygons:p.use_smooth=True
mod=ob.modifiers.new('Duvet thickness','SOLIDIFY');mod.thickness=.08
export('bed')
print('ARTPASS_EXTENDED_COMPLETE')

# Second pass: room-specific assets, all compatible with glTF/WebGL.
ceramic=mat('Room_Porcelain',(.72,.70,.65),.24)
chrome=mat('Room_Chrome',(.46,.49,.50),.20,.85)
stone=mat('Room_Limestone',(.38,.365,.32),.72)
black=mat('Room_Rubber',(.014,.018,.02),.78)
def lathe(name,profile,rx,rz,m,center=(0,0,0)):
 vs=[];fs=[];n=48
 for radius,y in profile:
  for i in range(n):
   a=i*math.tau/n;vs.append(g((center[0]+math.cos(a)*radius*rx,center[1]+y,center[2]+math.sin(a)*radius*rz)))
 for j in range(len(profile)-1):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;fs.append((a,a+n,b+n,b))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
 ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);mesh.materials.append(m)
 for p in mesh.polygons:p.use_smooth=True
 return ob
clear()
lathe('Porcelain pedestal',[(0,0),(.55,0),(.64,.06),(.5,.23),(.70,.34),(.85,.39)],.32,.40,ceramic)
lathe('Hollow bowl',[(.65,.25),(.88,.31),(1,.42),(.99,.47),(.83,.475),(.76,.40),(.50,.29),(0,.28)],.32,.40,ceramic)
lathe('Oval seat',[(.87,.485),(.99,.485),(1,.51),(.86,.525),(.80,.51),(.87,.485)],.32,.40,cream)
box('Cistern',(0,.62,.35),(.62,.56,.23),ceramic,.075)
box('Cistern lid',(0,.91,.35),(.64,.045,.25),ceramic,.025)
box('Flush button',(0,.936,.35),(.10,.009,.055),chrome,.018)
export('toilet')
clear()
# Coordinates in the existing BathroomFurniture root (1.45,0,1.35).
box('Vanity cabinet',(6.13,.45,1.75),(.62,.84,1.15),wood,.018)
box('Stone counter',(6.13,.90,1.75),(.68,.065,1.20),stone,.016)
for z in [1.475,2.025]:
 box('Inset front',(5.81,.46,z),(.028,.69,.53),sage,.009)
 tube('Vanity pull',[(5.777,.52,z-.095),(5.758,.52,z-.095),(5.758,.52,z+.095),(5.777,.52,z+.095)],.008,brass)
lathe('Wash basin',[(0,0),(.75,.005),(1,.08),(.98,.145),(.89,.15),(.85,.09),(.50,.04),(0,.035)],.235,.38,ceramic,(6.10,.935,1.75))
lathe('Drain',[(0,0),(.025,0),(.025,.008),(0,.008)],1,1,chrome,(6.10,.975,1.75))
export('vanity')
clear()
tube('Faucet neck',[(0,0,0),(.0,.18,0),(.03,.23,0),(.12,.24,0),(.20,.21,0),(.20,.15,0)],.023,chrome)
box('Mixer lever',(0,.075,.075),(.035,.016,.14),chrome,.008)
export('faucet')
clear()
# Rail and hose authored in world coordinates as static bathroom detail.
tube('Shower rail',[(7.74,.77,5.16),(7.74,2.17,5.16)],.018,chrome)
for y in [.82,2.08]:tube('Wall mounting',[(7.90,y,5.16),(7.74,y,5.16)],.024,chrome)
tube('Overhead arm',[(7.74,1.95,5.16),(7.74,2.23,5.16),(7.65,2.30,5.16),(7.34,2.30,5.16)],.019,chrome)
lathe('Rain shower',[(0,0),(.17,0),(.18,.025),(0,.035)],1,1,chrome,(7.34,2.265,5.16))
for i in range(24):
 a=i*2.399;r=.035+.11*(i/24)**.5
 box('Rain nozzle',(7.34+math.cos(a)*r,2.262,5.16+math.sin(a)*r),(.012,.007,.012),black,.003)
tube('Flexible shower hose',[(7.74,.80,5.16),(7.54,.56,5.16),(7.35,.57,5.16),(7.29,.77,5.16),(7.32,1.36,5.16)],.011,chrome)
tube('Mixer bar',[(7.72,.91,4.99),(7.72,.91,5.34)],.035,chrome)
export('shower_hardware')
clear()
# A slim linen-lined basket, with gaps in the woven body.
for y in [i*.035+.035 for i in range(18)]:
 pts=[]
 for i in range(65):
  a=i*math.tau/64;pts.append((math.cos(a)*.28,y,math.sin(a)*.23))
 tube('Woven horizontal',pts,.009,cream)
for i in range(32):
 a=i*math.tau/32;tube('Woven upright',[(math.cos(a)*.28,.03,math.sin(a)*.23),(math.cos(a)*.28,.65,math.sin(a)*.23)],.008,wood)
box('Canvas liner',(0,.31,0),(.51,.56,.41),cream,.055)
box('Soft linen',(0,.61,0),(.44,.09,.35),blue,.045)
export('hamper')
clear()
box('Padded bench seat',(0,.49,0),(1.25,.16,.58),rust,.06)
for x in [-.5,.5]:
 for z in [-.2,.2]:box('Oak bench leg',(x,.23,z),(.065,.46,.065),wood,.012)
box('Lower bench shelf',(0,.14,0),(1.08,.035,.45),wood,.012)
export('bench')
clear()
# Garment extends mainly along local Z, matching a wardrobe rail.
outline=[(-.21,.18),(-.24,.58),(-.35,.55),(-.37,.75),(-.17,.90),(-.075,.94),(0,.87),(.075,.94),(.17,.90),(.37,.75),(.35,.55),(.24,.58),(.21,.18)]
verts=[]
for x in [-.035,.035]:
 for z,y in outline:verts.append(g((x+.008*math.sin(y*20),y,z)))
n=len(outline);faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
for i in range(n):faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
me=bpy.data.meshes.new('Shirt');me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new('Shirt with sleeves',me);bpy.context.collection.objects.link(ob);me.materials.append(blue)
b=ob.modifiers.new('Seams','BEVEL');b.width=.013;b.segments=3
b=ob.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
tube('Shirt placket',[(-.047,.20,0),(-.047,.84,0)],.005,cream)
for y in [.30,.43,.56,.69]:box('Button',(-.053,y,0),(.009,.014,.014),cream,.004)
tube('Wooden hanger',[(0,.88,-.23),(0,1.01,0),(0,.88,.23),(0,.88,-.23)],.012,wood)
tube('Hanger hook',[(0,1.01,0),(0,1.085,0),(0,1.11,.024),(0,1.095,.05)],.006,chrome)
export('garment')
clear()
for i,m in enumerate([cream,blue,cream]):
 box('Folded fabric',(0,.025+i*.032,0),(.42,.045,.34),m,.02)
 tube('Fold seam',[(-.18,.035+i*.032,-.17),(.18,.035+i*.032,-.17)],.0025,m)
export('folded_linen')
clear()
box('Oak dining top',(0,.77,0),(1.55,.075,.88),wood,.03)
for x in [-.63,.63]:
 for z in [-.32,.32]:box('Dining leg',(x,.365,z),(.065,.73,.065),wood,.01)
export('dining_table')
clear()
box('Upholstered dining seat',(0,.45,0),(.47,.11,.46),sage,.045)
box('Curved padded back',(0,.76,.20),(.45,.43,.085),sage,.04)
for x in [-.18,.18]:
 for z in [-.18,.18]:box('Chair leg',(x,.22,z),(.038,.44,.038),wood,.008)
export('dining_chair')
print('ROOM_ASSETS_COMPLETE')

# Final pass: small hero pieces that previously read as primitive blocks.
clear()
box('Console carcass',(0,.47,0),(.38,.83,.90),wood,.025)
box('Stoneware console cap',(0,.925,0),(.45,.055,1.0),stone,.015)
for z in [-.23,.23]:
 box('Sage inset drawer',(.207,.67,z),(.025,.21,.41),sage,.008)
 tube('Brass drawer pull',[(.232,.69,z-.10),(.26,.69,z-.10),(.26,.69,z+.10),(.232,.69,z+.10)],.007,brass)
box('Lower open shelf',(.04,.19,0),(.27,.025,.78),wood,.008)
for z in [-.36,.36]:box('Tapered leg',(0,.085,z),(.055,.17,.055),wood,.012)
export('hall_console')

clear()
box('Bench carcass',(0,.36,0),(.40,.62,1.00),wood,.03)
for z in [-.30,.30]:
 box('Slatted oak door',(-.216,.34,z),(.022,.50,.39),wood,.006)
 for n in range(5):box('Oak louver',(-.233,.17+n*.085,z),(.013,.016,.35),edge,.003)
box('Tufted cushion',(-.02,.73,0),(.46,.13,1.09),rust,.055)
for z in [-.29,0,.29]:box('Cushion seam',(-.02,.798,z),(.37,.003,.003),seam,.001)
export('shoe_bench')

clear()
box('Washer enamel cabinet',(0,0,0),(.78,1.18,.72),ceramic,.035)
box('Brushed steel fascia',(0,.39,-.362),(.68,.17,.014),chrome,.008)
for x in [-.32,.32]:
 for y in [-.47,.05]:box('Front panel screw',(x,y,-.371),(.012,.012,.003),metal,.002)
for n in range(7):box('Vent slot',(-.27+n*.035,-.49,-.366),(.017,.009,.004),black,.002)
box('Lower kick plate',(0,-.555,-.368),(.65,.045,.012),stone,.008)
export('washer_cabinet')

clear()
sole=mat('Sneaker_Offwhite_Sole',(.57,.54,.45),.82)
upper=mat('Sneaker_Dark_Canvas',(.064,.09,.10),.92,normal='fabric')
box('Cushioned sole',(0,.025,0),(.17,.05,.37),sole,.022)
box('Canvas upper',(0,.088,.015),(.16,.115,.28),upper,.055)
box('Rubber toe',(0,.063,-.135),(.17,.072,.095),sole,.025)
box('Padded heel collar',(0,.13,.11),(.16,.055,.085),upper,.022)
for z in [-.07,-.025,.02,.065]:
 tube('Crossed cotton lace',[(-.067,.15,z),(.065,.15,z+.025)],.004,cream)
 tube('Crossed cotton lace',[(.067,.15,z),(-.065,.15,z+.025)],.004,cream)
for x in [-.086,.086]:tube('Sole welt',[(x,.04,-.14),(x,.04,.14)],.004,edge)
export('sneaker')

clear()
skin=mat('Rita_Skin',(.64,.39,.29),.82)
hairmat=mat('Rita_Chestnut',(.078,.041,.025),.88)
lash=mat('Rita_Lashes',(.015,.011,.009),.9)
def ellipsoid(name,p,s,m,segments=32):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=16,location=g(p))
 o=bpy.context.object;o.name=name;o.scale=(s[0],s[2],s[1]);o.data.materials.append(m)
 for face in o.data.polygons:face.use_smooth=True
 return o
ellipsoid('Face',(0,0,0),(.175,.145,.17),skin)
ellipsoid('Back of hair',(-.08,-.035,0),(.16,.15,.18),hairmat)
for z in [-.155,.155]:
 ellipsoid('Ear',(-.005,-.015,z),(.042,.055,.025),skin,20)
for z in [-.075,.075]:
 tube('Closed sleeping eyelid',[(-.048,.136,z-.036),(-.025,.143,z),(0,.136,z+.035)],.004,lash)
 tube('Soft eyebrow',[(-.075,.148,z-.034),(-.04,.16,z),(0,.15,z+.026)],.006,hairmat)
ellipsoid('Nose',(0,.153,0),(.025,.018,.025),skin,20)
tube('Relaxed mouth',[(.055,.114,-.029),(.066,.117,0),(.055,.114,.029)],.003,lash)
for z in [-.12,-.08,-.04,0,.04,.08,.12]:
 tube('Hair fringe',[(-.13,.14,z),(-.09,.155,z+.014),(-.07,.138,z+.02)],.011,hairmat)
export('rita_portrait')
print('HERO_ASSETS_COMPLETE')
