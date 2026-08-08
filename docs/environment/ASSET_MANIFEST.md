# Environment asset manifest

## Imported pack

Asset pack: Kenney Furniture Kit  
Author: Kenney  
Source: https://kenney.nl/assets/furniture-kit  
License: Creative Commons Zero 1.0 Universal (CC0)  
Attribution required: no  
Original format used: GLB  
Download date: 2026-07-30  
Original archive: `kenney_furniture-kit.zip`  
Pack contents reviewed: 140 models  
Models imported: 12  
Models rejected/not imported: 128  
Local license copy: `res://assets/environment/KENNEY_CC0_LICENSE.txt`

Only the following selected files were copied into the project:

| Imported file | Original model | Use | Changes |
|---|---|---|---|
| `corridor/rug_doormat.glb` | rugDoormat | entry threshold | scaled and aligned to the existing entry |
| `living_room/floor_lamp.glb` | lampRoundFloor | local living-room light | scaled; decorative, no collision |
| `living_room/pillow_warm.glb` | pillow | sofa asymmetry | scaled and recoloured to project palette |
| `living_room/pillow_blue_long.glb` | pillowBlueLong | sofa asymmetry | scaled and recoloured |
| `workspace/keyboard.glb` | computerKeyboard | remote-work desk | scaled; static background prop |
| `workspace/mouse.glb` | computerMouse | remote-work desk | scaled; static background prop |
| `workspace/monitor.glb` | computerScreen | remote-work desk | scaled; screen material adjusted |
| `bedroom/table_lamp.glb` | lampRoundTable | Rita bedside | scaled; decorative, no collision |
| `bathroom/wall_cabinet.glb` | bathroomCabinet | hygiene storage | scaled and placed against wall |
| `shared/books.glb` | books | shelves/bedside stories | reused instances |
| `shared/small_plant.glb` | plantSmall2 | controlled green accents | reused instances |
| `shared/trashcan.glb` | trashcan | kitchen/bathroom utility | reused instances |

The full pack archive and unused models remain outside the project. Large
architectural assets, duplicate beds, sofas, cabinets and kitchen modules were
rejected because the apartment already has working geometry and interactions.

## Reviewed but not imported

### Quaternius Ultimate House Interior Pack

Source: https://quaternius.com/packs/ultimatehomeinterior.html  
License: CC0  
Models reviewed at pack level: 123  
Imported: 0

Reason: its broad furniture coverage duplicated the working kitchen, doors,
bedroom and bathroom. Importing a second pack would mix silhouette languages
and increase unused content. Kenney's selected props were sufficient for the
missing secondary details.

### Quaternius Furniture Pack

Source: https://quaternius.com/packs/furniture.html  
License: CC0  
Models reviewed at pack level: 23  
Imported: 0

Reason: the pack focuses on large furniture already present in the scene.

## Rita cat character

Asset pack: Kenney Cube Pets  
Author: Kenney  
Source: https://kenney.nl/assets/cube-pets  
License: Creative Commons Zero 1.0 Universal (CC0)  
Attribution required: no  
Download date: 2026-08-03  
Imported files: `animal-cat.glb`, `Textures/colormap.png`  
Local license copy: `res://characters/rita_cat/assets/KENNEY_LICENSE.txt`

Only the animated cat and its shared colour map were retained. The other 23
animals were rejected to avoid turning the apartment into an unrelated asset
collection. Scale, collision and interaction are owned by the replaceable
`RitaCat` wrapper scene; the third-party GLB contains visuals and animations only.
