#!/usr/bin/env python3
"""Build the Bratislava Castle siege road as a Blender-authored GLB asset.

Run with Blender 4.3+:
  blender --background --python tools/blender/build_bratislava_road.py -- \
    --terrain Bratislava_Real_Terrain_Godot4.glb \
    --glb assets/world/bratislava_castle_road.glb \
    --blend assets/world/source/bratislava_castle_road.blend \
    --path-json assets/world/bratislava_castle_road_path.json \
    --report assets/world/bratislava_castle_road_validation.json

The route controls contain horizontal coordinates only. Every elevation is
resolved by downward BVH rays against both visible Terrain and Terrain-col
after applying the same 1.6 vertical review scale used by Godot. The higher
hit wins, so neither render nor collision geometry can cover the road. The
Danube bridge span uses the existing bridge deck as its support surface.
"""

import argparse
import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


VERTICAL_SCALE = 1.6
SAMPLE_SPACING = 2.5
ROAD_HALF_WIDTH = 6.0
ROAD_CLEARANCE = 0.28
ROAD_BOTTOM_CLEARANCE = 0.05
BRIDGE_X = 2262.0
BRIDGE_NORTH_Z = 5005.0
BRIDGE_SOUTH_Z = 5350.0
BRIDGE_DECK_Y = 41.95

# World X/Z only. Heights are intentionally absent and are never hand-authored.
# The route is: bridge -> east/lower traverse -> east hairpin -> west/middle
# traverse -> west hairpin -> east/upper traverse -> river-facing castle gate.
ROUTE_CONTROLS_GODOT_XZ = [
    (2262.0, 5480.0),
    (2262.0, 5350.0),
    (2262.0, 5005.0),
    (2390.0, 4995.0),
    (2600.0, 4970.0),
    (2780.0, 4930.0),
    (2840.0, 4870.0),
    (2820.0, 4780.0),
    (2760.0, 4700.0),
    (2700.0, 4640.0),
    (2630.0, 4600.0),
    (2600.0, 4550.0),
    (2530.0, 4550.0),
    (2490.0, 4640.0),
    (2470.0, 4700.0),
    (2440.0, 4720.0),
]


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--terrain", required=True)
    parser.add_argument("--glb", required=True)
    parser.add_argument("--blend", required=True)
    parser.add_argument("--path-json", required=True)
    parser.add_argument("--report", required=True)
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(args)


def clean_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for datablock in list(collection):
            if datablock.users == 0:
                collection.remove(datablock)


def find_terrain_meshes():
    candidates = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    visible = next((obj for obj in candidates if obj.name.lower() == "terrain"), None)
    collision = next((obj for obj in candidates if obj.name.lower() == "terrain-col"), None)
    if visible is None or collision is None:
        raise RuntimeError("Both Terrain and Terrain-col meshes are required in the source GLB")
    return [visible, collision]


def build_scaled_terrain_bvh(terrain_obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = terrain_obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    vertices = []
    for vertex in mesh.vertices:
        point = terrain_obj.matrix_world @ vertex.co
        vertices.append(Vector((point.x, point.y, point.z * VERTICAL_SCALE)))
    polygons = [tuple(poly.vertices) for poly in mesh.polygons]
    evaluated.to_mesh_clear()
    return BVHTree.FromPolygons(vertices, polygons, all_triangles=False), len(vertices), len(polygons)


def terrain_height(bvhs, x, godot_z):
    # glTF/Godot (X, Y-up, Z) maps to Blender (X, -Z, Z-up).
    origin = Vector((x, -godot_z, 5000.0))
    locations = [bvh.ray_cast(origin, Vector((0.0, 0.0, -1.0)), 10000.0)[0] for bvh in bvhs]
    locations = [location for location in locations if location is not None]
    if not locations:
        raise RuntimeError(f"Terrain BVH ray missed at Godot X/Z {x:.3f}, {godot_z:.3f}")
    return max(location.z for location in locations)


def smoothstep(edge0, edge1, value):
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def support_height(bvhs, x, godot_z):
    ground = terrain_height(bvhs, x, godot_z)
    # The northern bridge landing turns east along the low river terrace. Its
    # height blends from the deck to the BVH-projected bank over 128 metres.
    if 2248.0 <= x <= 2405.0 and 4960.0 <= godot_z <= 5075.0:
        factor = smoothstep(BRIDGE_X, 2390.0, x)
        landing = BRIDGE_DECK_Y * (1.0 - factor) + ground * factor
        return max(ground, landing), "bridge"
    if abs(x - BRIDGE_X) <= 14.0 and BRIDGE_NORTH_Z <= godot_z <= BRIDGE_SOUTH_Z:
        if godot_z > BRIDGE_SOUTH_Z - 55.0:
            bank_height = terrain_height(bvhs, x, BRIDGE_SOUTH_Z)
            factor = smoothstep(BRIDGE_SOUTH_Z - 55.0, BRIDGE_SOUTH_Z, godot_z)
            ramp = BRIDGE_DECK_Y * (1.0 - factor) + bank_height * factor
            return max(ground, ramp), "bridge"
        return max(ground, BRIDGE_DECK_Y), "bridge"
    return ground, "terrain"


def chaikin(points, passes=4):
    result = [Vector(point) for point in points]
    for _ in range(passes):
        rounded = [result[0]]
        for a, b in zip(result[:-1], result[1:]):
            rounded.append(a.lerp(b, 0.25))
            rounded.append(a.lerp(b, 0.75))
        rounded.append(result[-1])
        result = rounded
    return result


def resample_polyline(points, spacing):
    cumulative = [0.0]
    for a, b in zip(points[:-1], points[1:]):
        cumulative.append(cumulative[-1] + (b - a).length)
    total = cumulative[-1]
    result = []
    segment = 0
    distance = 0.0
    while distance < total:
        while segment + 1 < len(cumulative) and cumulative[segment + 1] < distance:
            segment += 1
        length = cumulative[segment + 1] - cumulative[segment]
        factor = 0.0 if length == 0.0 else (distance - cumulative[segment]) / length
        result.append(points[segment].lerp(points[segment + 1], factor))
        distance += spacing
    result.append(points[-1])
    return result


def route_points_2d():
    # Blender horizontal space: X is identical, Blender Y is negative Godot Z.
    controls = [(x, -z) for x, z in ROUTE_CONTROLS_GODOT_XZ]
    return resample_polyline(chaikin(controls, 4), SAMPLE_SPACING)


def tangent_and_side(points, index):
    previous = points[max(0, index - 1)]
    following = points[min(len(points) - 1, index + 1)]
    tangent = (following - previous).normalized()
    return tangent, Vector((-tangent.y, tangent.x))


def create_material(name, color, roughness=0.9):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Roughness"].default_value = roughness
    return material


def create_centerline_curve(points, heights):
    curve = bpy.data.curves.new("BratislavaRoad_SourceCurve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for item, point, height in zip(spline.points, points, heights):
        item.co = (point.x, point.y, height + ROAD_CLEARANCE, 1.0)
    obj = bpy.data.objects.new("BratislavaRoad_SourceCurve", curve)
    bpy.context.collection.objects.link(obj)
    obj.hide_render = True
    obj.hide_viewport = True
    return obj


def create_road_mesh(bvhs, points):
    # Sample both shoulders, the centre and both road edges. This preserves the
    # terrain-following cross-section without redundant metre-wide Web geometry.
    lateral_offsets = (-6.0, -5.0, 0.0, 5.0, 6.0)
    columns = len(lateral_offsets)
    top_vertices = []
    bottom_vertices = []
    support_kinds = []
    center_heights = []
    top_clearance_errors = []
    terrain_clearances = []

    for index, point in enumerate(points):
        _tangent, side = tangent_and_side(points, index)
        row_kinds = []
        row_heights = []
        for offset in lateral_offsets:
            lateral = point + side * offset
            godot_z = -lateral.y
            support, support_kind = support_height(bvhs, lateral.x, godot_z)
            ground = terrain_height(bvhs, lateral.x, godot_z)
            top_vertices.append((lateral.x, lateral.y, support + ROAD_CLEARANCE))
            bottom_vertices.append((lateral.x, lateral.y, support + ROAD_BOTTOM_CLEARANCE))
            row_kinds.append(support_kind)
            row_heights.append(support)
            top_clearance_errors.append(abs((support + ROAD_CLEARANCE) - support - ROAD_CLEARANCE))
            terrain_clearances.append((support + ROAD_CLEARANCE) - ground)
        support_kinds.append(row_kinds[2])
        center_heights.append(row_heights[2])

    vertices = top_vertices + bottom_vertices
    top_faces = []
    top_materials = []
    for row in range(len(points) - 1):
        for strip in range(columns - 1):
            a = row * columns + strip
            b = a + 1
            c = (row + 1) * columns + strip + 1
            d = c - 1
            top_faces.extend([(a, b, c), (a, c, d)])
            is_road_surface = lateral_offsets[strip] >= -5.0 and lateral_offsets[strip + 1] <= 5.0
            top_materials.extend([0 if is_road_surface else 1] * 2)

    bottom_offset = len(top_vertices)

    side_faces = []
    for row in range(len(points) - 1):
        for column in (0, columns - 1):
            top_a = row * columns + column
            top_b = (row + 1) * columns + column
            bottom_a = bottom_offset + top_a
            bottom_b = bottom_offset + top_b
            if column == 0:
                side_faces.extend([(top_a, top_b, bottom_b), (top_a, bottom_b, bottom_a)])
            else:
                side_faces.extend([(top_a, bottom_b, top_b), (top_a, bottom_a, bottom_b)])

    start_top = list(range(columns))
    end_top = list(range((len(points) - 1) * columns, len(points) * columns))
    cap_faces = []
    for strip in range(columns - 1):
        cap_faces.extend([
            (start_top[strip], bottom_offset + start_top[strip + 1], start_top[strip + 1]),
            (start_top[strip], bottom_offset + start_top[strip], bottom_offset + start_top[strip + 1]),
            (end_top[strip], end_top[strip + 1], bottom_offset + end_top[strip + 1]),
            (end_top[strip], bottom_offset + end_top[strip + 1], bottom_offset + end_top[strip]),
        ])

    # The underside is never visible; the narrow vertical edge faces retain a
    # readable roadbed silhouette without shipping duplicate bottom triangles.
    faces = top_faces + side_faces + cap_faces
    mesh = bpy.data.meshes.new("BratislavaCastleRoadMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    road_material = create_material("Packed earth road", (0.30, 0.17, 0.075), 0.96)
    shoulder_material = create_material("Stone shoulders", (0.29, 0.27, 0.22), 0.92)
    mesh.materials.append(road_material)
    mesh.materials.append(shoulder_material)
    for polygon_index, material_index in enumerate(top_materials):
        mesh.polygons[polygon_index].material_index = material_index
    for polygon in mesh.polygons[len(top_faces) :]:
        polygon.material_index = 1

    obj = bpy.data.objects.new("Bratislava_Castle_Road", mesh)
    bpy.context.collection.objects.link(obj)
    obj["source_terrain"] = "Bratislava_Real_Terrain_Godot4.glb/Terrain + Terrain-col"
    obj["vertical_scale"] = VERTICAL_SCALE
    obj["sample_spacing_m"] = SAMPLE_SPACING
    obj["road_width_m"] = ROAD_HALF_WIDTH * 2.0
    obj["clearance_m"] = ROAD_CLEARANCE
    return obj, center_heights, support_kinds, terrain_clearances, max(top_clearance_errors)


def orientation(a, b, c):
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


def segments_intersect(a, b, c, d):
    return orientation(a, b, c) * orientation(a, b, d) < 0.0 and orientation(c, d, a) * orientation(c, d, b) < 0.0


def validate_route(points, center_heights, terrain_clearances):
    intersections = []
    for first in range(len(points) - 1):
        for second in range(first + 2, len(points) - 1):
            if second == first + 1:
                continue
            if segments_intersect(points[first], points[first + 1], points[second], points[second + 1]):
                intersections.append((first, second))

    grades = []
    steps = []
    for index in range(len(points) - 1):
        horizontal = (points[index + 1] - points[index]).length
        vertical = abs(center_heights[index + 1] - center_heights[index])
        steps.append(vertical)
        grades.append(vertical / max(horizontal, 0.001))

    if intersections:
        raise RuntimeError(f"Road centerline self-intersections detected: {intersections[:5]}")
    max_step_index = steps.index(max(steps))
    max_grade_index = grades.index(max(grades))
    print(
        "ROAD_GRADE_DIAGNOSTIC",
        f"max_step={max(steps):.3f}@{max_step_index}",
        f"max_grade={max(grades) * 100.0:.1f}%@{max_grade_index}",
        f"godot_xz=({points[max_grade_index].x:.2f},{-points[max_grade_index].y:.2f})",
    )
    steepest = sorted(range(len(grades)), key=lambda index: grades[index], reverse=True)[:8]
    print(
        "ROAD_STEEPEST_SAMPLES",
        [
            (round(points[index].x, 2), round(-points[index].y, 2), round(grades[index] * 100.0, 1))
            for index in steepest
        ],
    )
    if max(steps) > 2.0:
        raise RuntimeError(f"Road has an anomalous vertical step: {max(steps):.3f} m at sample {max_step_index}")
    if max(grades) > 0.45:
        raise RuntimeError(f"Road grade is too steep: {max(grades) * 100.0:.1f}% at sample {max_grade_index}")
    if min(terrain_clearances) < ROAD_BOTTOM_CLEARANCE - 0.001:
        raise RuntimeError(f"Road penetrates terrain: minimum top clearance {min(terrain_clearances):.3f} m")
    return {
        "self_intersection_count": len(intersections),
        "max_vertical_step_m": max(steps),
        "max_grade_percent": max(grades) * 100.0,
        "min_top_above_terrain_m": min(terrain_clearances),
        "max_top_above_terrain_m": max(terrain_clearances),
    }


def remove_imported_terrain(road_obj, curve_obj):
    for obj in list(bpy.context.scene.objects):
        if obj not in (road_obj, curve_obj):
            bpy.data.objects.remove(obj, do_unlink=True)


def blender_to_godot(point, y):
    return [round(point.x, 5), round(y, 5), round(-point.y, 5)]


def main():
    args = parse_args()
    terrain_path = str(Path(args.terrain).resolve())
    outputs = [Path(args.glb), Path(args.blend), Path(args.path_json), Path(args.report)]
    for output in outputs:
        output.parent.mkdir(parents=True, exist_ok=True)

    clean_scene()
    bpy.ops.import_scene.gltf(filepath=terrain_path)
    terrain_objects = find_terrain_meshes()
    terrain_data = [build_scaled_terrain_bvh(obj) for obj in terrain_objects]
    bvhs = [item[0] for item in terrain_data]
    terrain_vertices = sum(item[1] for item in terrain_data)
    terrain_polygons = sum(item[2] for item in terrain_data)
    points = route_points_2d()
    road_obj, center_heights, support_kinds, terrain_clearances, clearance_error = create_road_mesh(bvhs, points)
    curve_obj = create_centerline_curve(points, center_heights)
    metrics = validate_route(points, center_heights, terrain_clearances)

    path_points = [blender_to_godot(point, height + ROAD_CLEARANCE) for point, height in zip(points, center_heights)]
    path_payload = {
        "coordinate_system": "Godot world X/Y/Z, Y-up",
        "source": "Blender 4.3 bpy + Terrain-col BVH",
        "sample_spacing_m": SAMPLE_SPACING,
        "road_width_m": ROAD_HALF_WIDTH * 2.0,
        "points": path_points,
    }
    Path(args.path_json).write_text(json.dumps(path_payload, indent=2) + "\n", encoding="utf-8")

    report = {
        "status": "ROAD_VALIDATION_OK",
        "terrain_mesh": "Terrain + Terrain-col",
        "terrain_vertices": terrain_vertices,
        "terrain_polygons": terrain_polygons,
        "vertical_scale": VERTICAL_SCALE,
        "sample_spacing_m": SAMPLE_SPACING,
        "sample_count": len(points),
        "road_width_m": ROAD_HALF_WIDTH * 2.0,
        "target_clearance_m": ROAD_CLEARANCE,
        "max_support_clearance_error_m": clearance_error,
        "terrain_sample_count": sum(kind == "terrain" for kind in support_kinds),
        "bridge_sample_count": sum(kind == "bridge" for kind in support_kinds),
        "start_godot": path_points[0],
        "end_godot": path_points[-1],
        **metrics,
    }
    Path(args.report).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    remove_imported_terrain(road_obj, curve_obj)
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.blend).resolve()), compress=True)
    bpy.ops.object.select_all(action="DESELECT")
    road_obj.hide_viewport = False
    road_obj.hide_render = False
    road_obj.select_set(True)
    bpy.context.view_layer.objects.active = road_obj
    bpy.ops.export_scene.gltf(
        filepath=str(Path(args.glb).resolve()),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    print("ROAD_VALIDATION_OK", json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
