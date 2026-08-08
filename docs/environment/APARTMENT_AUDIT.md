# Apartment environment audit

Audit date: 2026-07-30  
Engine: Godot 4.4.1  
Ceiling height: 3.0 m

## Plan and circulation

The apartment contains six existing zones. No new room is introduced.

| Zone | Approximate clear envelope | Existing function | Audit result |
|---|---:|---|---|
| Living room + office | 6.4 × 8.5 m | sofa/TV area and Denis's remote-work desk | Good zoning; desk and coffee route need denser, purposeful detail |
| Corridor | 3.2 × 13.0 m after pass; previously 2.6 × 13.0 m | entry, circulation and closed storage | Widened by 0.6 m; loose shoes and parcels moved out of the centre line |
| Kitchen + dining | 6.4 × 8.5 m | coffee quest, cooking, sink and dining | Working L-counter retained; quest surface and sink approach must remain clear |
| Rita's bedroom | 6.4 × 4.5 m | sleeping and quiet personal storage | Calm density is appropriate; stable bedside details are needed |
| Bathroom | 6.4 × 4.5 m | hygiene and cleaning-demand station | Fixtures exist; small functional objects and local storage are sparse |
| Walk-in wardrobe | 6.4 × 3.0 m | clothes, shoes and hide spot | Function is complete; right storage run was moved with the corridor wall |

Outer apartment envelope is approximately 16.0 × 13.0 m, with the wardrobe
extension reaching 9.5 m on the south side of the plan.

## Doors, windows and critical actors

- North windows: living/office and kitchen.
- Side-room doors: office/living opening, kitchen door, bedroom door and
  bathroom door, all along the corridor.
- South entry door: courier delivery point remains centred at the threshold.
- Bedroom-to-wardrobe door remains in the existing south bedroom wall.
- Rita remains on the bed, clear of decorative props.
- Critical interactions: laptop, TV, mug cabinet, coffee drawer, kettle,
  faucet, fridge, courier bag and CoffeePlacementZone.

## Corridor geometry change

- Structural side walls moved from x = ±1.30 m to x = ±1.60 m.
- Decorative corridor floor widened from 2.60 m to 3.20 m.
- Adjacent floor finishes, baseboards, door frames, room doors, wall outlets,
  mirror, wall labels, light switch and acoustic room bounds moved with them.
- Entry storage moved toward the walls.
- Shoes, slippers, backpack, parcel and umbrella were removed from the
  continuous centre route.
- Target central clear strip is at least 1.35 m; the player capsule diameter is
  substantially smaller, leaving carrying tolerance for the kettle and mug.

## Style direction

Chosen direction: a stylized contemporary lived-in apartment with believable
human scale, simple low/mid-poly silhouettes, matte surfaces and restrained PBR.

Palette:

- warm oak and dark stained wood;
- grey-beige walls and off-white stone;
- olive cabinetry and upholstery;
- muted blue and rust textiles;
- black and brushed-metal accents;
- warm local lights against cool dawn ambience.

Imported props must support this palette. Hero interactions keep their custom
procedural geometry and collisions; imported assets are used selectively for
secondary/background detail.

## Placement risks and rules

- Keep the corridor centre, all door swing arcs and the delivery threshold free.
- Keep the sink/faucet overlap volume and kettle approach free.
- Keep CoffeePlacementZone and the laptop ray target unobstructed.
- Keep a direct line of sight and interaction path to the TV.
- Bedroom props must be static or frozen so they cannot wake Rita at startup.
- Thin wall props receive no collision; large storage retains simple box
  collision.
- Kitchen clutter belongs at the back edge, in racks, or inside cabinets—not on
  the working strip used by the coffee quest.

