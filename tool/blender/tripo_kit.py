"""Dùng chung cho mô hình Tripo3D (ảnh → 3D, art_src/tripo/*.glb): nạp,
đặt đúng tỉ lệ/vị trí trên sân khấu, làm mượt trọng số xương. Xem
rules/dohoa.md mục 10.
"""

import bpy
import numpy as np
from mathutils import Matrix, Vector

from boss_kit import S


def import_tripo(path, nose_x, span, grow=1.0, flip=False):
    """Nạp mô hình Tripo, đặt mũi ở [nose_x] (đơn vị vẽ), bề dài mũi–đuôi
    [span]×[grow], chân chạm đất, giữa chiều sâu ở 0; áp biến đổi vào lưới
    (Rig tính trọng số trên toạ độ đỉnh). [flip]: mô hình quay mặt sang phải
    thì xoay 180° cho quay trái như sân khấu."""
    bpy.ops.import_scene.gltf(filepath=path)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("tripo"))
    for o in list(bpy.context.scene.objects):
        if o.type == "EMPTY" and mesh.parent == o:
            mesh.matrix_world = o.matrix_world @ mesh.matrix_local
            mesh.parent = None
            bpy.data.objects.remove(o)
    if flip:
        mesh.matrix_world = Matrix.Rotation(3.14159265, 4, "Z") @ mesh.matrix_world
    bpy.context.view_layer.update()
    ws = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
    lo_x = min(p.x for p in ws)
    hi_x = max(p.x for p in ws)
    lo_z = min(p.z for p in ws)
    mid_y = (min(p.y for p in ws) + max(p.y for p in ws)) / 2
    k = span * S / (hi_x - lo_x) * grow
    mesh.matrix_world = Matrix.Translation(Vector((nose_x * S - lo_x * k, -mid_y * k, -lo_z * k))) @         Matrix.Scale(k, 4) @ mesh.matrix_world
    bpy.context.view_layer.update()
    mesh.data.transform(mesh.matrix_world)
    mesh.matrix_world = Matrix.Identity(4)
    # Texture Tripo đã "vẽ sẵn" ánh sáng: bề mặt mờ, ít bóng loáng.
    for slot in mesh.material_slots:
        bsdf = next(n for n in slot.material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Roughness"].default_value = 0.85
        bsdf.inputs["Specular IOR Level"].default_value = 0.25
    return mesh


def smooth_weights(mesh, islands_below=400, iterations=6):
    """Trọng số theo khoảng cách đổi đột ngột giữa các đỉnh kề nhau: lọn bờm
    (mảnh lưới rời) bị chia cho xương chân và thân, chân vung là lọn bị kéo
    thành sợi dài. Mỗi mảnh rời nhỏ dùng chung trọng số trung bình (cứng như
    một lọn), rồi làm mượt theo cạnh và chuẩn hoá lại.

    GLB tách đỉnh ở mọi đường nối UV: làm việc trên các điểm HÀN theo vị trí
    (đỉnh trùng chỗ là một điểm), nếu không mỗi mảnh UV thành một "mảnh rời"
    và lưới bị xé khi cử động."""
    verts = mesh.data.vertices
    groups = list(mesh.vertex_groups)
    weld = {}
    canon = np.array([weld.setdefault(tuple(round(c, 5) for c in v.co), len(weld)) for v in verts])
    n = len(weld)
    w = np.zeros((n, len(groups)))
    count = np.bincount(canon, minlength=n).astype(float)
    for v in verts:
        for g in v.groups:
            w[canon[v.index], g.group] += g.weight
    w /= count[:, None]
    edges = canon[np.array([e.vertices[:] for e in mesh.data.edges])]
    edges = edges[edges[:, 0] != edges[:, 1]]
    # Mảnh rời: hợp nhất theo cạnh.
    parent = np.arange(n)

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for a, b in edges:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb
    roots = np.array([find(i) for i in range(n)])
    for r in np.unique(roots):
        idx = np.nonzero(roots == r)[0]
        if len(idx) < islands_below:
            w[idx] = w[idx].mean(axis=0)
    # Làm mượt theo cạnh (Laplace).
    deg = np.bincount(edges.ravel(), minlength=n).astype(float)
    deg[deg == 0] = 1
    for _ in range(iterations):
        acc = np.zeros_like(w)
        np.add.at(acc, edges[:, 0], w[edges[:, 1]])
        np.add.at(acc, edges[:, 1], w[edges[:, 0]])
        w = 0.5 * w + 0.5 * acc / deg[:, None]
    w /= np.maximum(w.sum(axis=1, keepdims=True), 1e-6)
    for gi, g in enumerate(groups):
        for v in verts:
            x = w[canon[v.index], gi]
            if x > 1e-4:
                g.add([v.index], float(x), "REPLACE")
            else:
                g.remove([v.index])
