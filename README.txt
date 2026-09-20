THE LAST TAVERN 3D — Devín to Bratislava river siege

Current build purpose:
- Preview the new river-defense direction on the real Bratislava DEM/OSM terrain.
- Invader ships sail from Devín downstream toward Bratislava.
- A stone embankment, watchtowers and cannon batteries defend the city riverfront.
- Ships and cannon fire are animated; there is no hero in this review build.
- The source scene is Bratislava_Real_Terrain_Godot4.glb.
- The former land route remains in the repository but is not shown or used in
  this river-siege review scene.

Visible geography:
- Danube and Morava confluence near Devin
- Bratislava Castle and Stare Mesto
- Petrzalka lowland
- Little Carpathians and Kamzik

Landmark treatment:
- Devin walls and limestone crag are fitted to DEM elevations inside the real OSM site.
- Bratislava Castle keeps the simplified palace model; fortification walls are disabled.
- The Danube crossing uses a historically appropriate timber pontoon form.
- The Morava crossing is a historically styled gameplay route, not presented as an exact surviving bridge.

Review controls:
- Right mouse drag — orbit camera
- Mouse wheel — zoom
- WASD — pan across the terrain
- T or TOP VIEW — top-down view
- R or OBLIQUE VIEW — reset to the starting oblique view
- 1 — close view of Bratislava Castle
- 2 — close view of restored Devin Castle
- 3 — close view of the Danube pontoon bridge
- 4 — close view of the Morava bridge near Devin
- 5 — close view of Bratislava's fortified riverfront
- 6 — full river route from Devín to Bratislava
- 7 — close fleet and cannon view

The GLB remains at real horizontal scale (about 19.3 x 18.9 km). The review
scene uses a clearly disclosed 1.6x vertical scale so the real ridges and
valleys remain readable in a whole-region overview.

Road source and rebuild:
- Blender source: assets/world/source/bratislava_castle_road.blend
- Rebuild script: tools/blender/build_bratislava_road.py
- The script imports visible Terrain and Terrain-col, applies the Godot 1.6
  vertical scale, projects every 2.5 m sample against both Blender BVHs,
  validates clearances/grade/self-intersections, and exports the fixed GLB
  plus navigation JSON.
