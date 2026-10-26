"""Đóng atlas sprite (numpy thuần, không cần Blender): cắt khung, xếp trang,
ghi json — dùng chung cho tool/blender/sprite_kit.py (lúc render) và
tool/repack_sprites.py (đóng lại từ khung đã render, không phải render lại).

Cắt khung theo phần THÂN ĐỤC (alpha > 0,6) cộng lề, không theo mọi điểm có
alpha: bóng đổ trên mặt sàn nhận bóng (nắng xiên) trải dài hết ảnh làm khung
không cắt được chút nào. Bóng ở mép cắt được làm mờ dần cho khỏi lộ vết cắt.
"""

import json
import os

import numpy as np

PAGE = 2048
BODY_ALPHA = 0.6
MARGIN = 0.06  # lề quanh thân, theo cạnh dài của thân
FEATHER = 24  # điểm ảnh làm mờ bóng ở mép cắt


def resize(px, scale):
    """Thu nhỏ khung (trung bình vùng) — float RGBA premultiply cho mép sạch."""
    if scale == 1:
        return px
    from PIL import Image
    h, w = px.shape[:2]
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    a = px[:, :, 3:4]
    pre = np.concatenate([px[:, :, :3] * a, a], axis=2)
    chans = [np.asarray(Image.fromarray(pre[:, :, c].astype(np.float32), "F").resize((nw, nh), Image.BOX))
             for c in range(4)]
    out = np.stack(chans, axis=2)
    a = out[:, :, 3:4]
    rgb = np.where(a > 1e-4, out[:, :, :3] / np.maximum(a, 1e-4), 0)
    return np.concatenate([rgb, a], axis=2).astype(np.float32)


def crop(px):
    """(khung đã cắt, x0, y0) — theo thân đục + lề; bóng mờ dần ở mép."""
    h, w = px.shape[:2]
    alpha = px[:, :, 3]
    ys, xs = np.nonzero(alpha > BODY_ALPHA)
    if len(xs) == 0:
        ys, xs = np.nonzero(alpha > 0.004)
    if len(xs) == 0:
        return px[:1, :1].copy(), 0, 0
    m = int(MARGIN * max(xs.max() - xs.min(), ys.max() - ys.min())) + 2
    x0, x1 = max(xs.min() - m, 0), min(xs.max() + m + 1, w)
    y0, y1 = max(ys.min() - m, 0), min(ys.max() + m + 1, h)
    out = px[y0:y1, x0:x1].copy()
    # Làm mờ bóng sát mép cắt. Bóng đậm (alpha ≥ BODY_ALPHA, nắng xiên dưới
    # chân) cũng phải mờ, không thì lộ mép chữ nhật; thân thật luôn cách mép
    # ít nhất lề [m] nên dải mờ ≤ m không chạm thân.
    ch, cw = out.shape[:2]
    feather = max(2, min(FEATHER, m))
    gx = np.minimum(np.arange(cw), np.arange(cw)[::-1]) / feather
    gy = np.minimum(np.arange(ch), np.arange(ch)[::-1]) / feather
    edge = np.clip(np.minimum(gx[None, :], gy[:, None]), 0, 1)
    soft = out[:, :, 3] < BODY_ALPHA
    out[:, :, 3] = np.where(soft, out[:, :, 3] * edge, out[:, :, 3] * np.maximum(edge, 0.0))
    out[:, :, 3][out[:, :, 3] < 0.004] = 0
    return out, x0, y0


def pack(name, frames, anchor, ppu, extra, pages_dir, json_dir, save):
    """[frames]: [(chuỗi, khung đã cắt, x0, y0)] theo toạ độ ảnh render;
    [anchor] (x, y) điểm neo trên ảnh, [ppu] điểm ảnh / đơn vị sân khấu.
    [save](mảng, đường dẫn) ghi trang PNG. Trả (đường dẫn json, số trang)."""
    order = sorted(range(len(frames)), key=lambda i: -frames[i][1].shape[0])
    pad = 2
    pages = [[]]
    x = y = shelf = 0
    place = {}
    for i in order:
        h, w = frames[i][1].shape[:2]
        if w > PAGE or h > PAGE:
            raise SystemExit(f"Khung {frames[i][0]} {w}×{h} lớn hơn trang {PAGE}: giảm độ phân giải")
        if x + w > PAGE:
            x, y, shelf = 0, y + shelf + pad, 0
        if y + h > PAGE:
            pages.append([])
            x = y = shelf = 0
        place[i] = (len(pages) - 1, x, y)
        pages[-1].append(i)
        x += w + pad
        shelf = max(shelf, h)

    os.makedirs(pages_dir, exist_ok=True)
    os.makedirs(json_dir, exist_ok=True)
    for old in os.listdir(pages_dir):
        if old.rsplit("_", 1)[0] == name:
            os.remove(os.path.join(pages_dir, old))
    for p, idx in enumerate(pages):
        height = max(place[i][2] + frames[i][1].shape[0] for i in idx)
        height = 1 << (int(height - 1).bit_length())  # luỹ thừa 2
        sheet = np.zeros((height, PAGE, 4), dtype=np.float32)
        for i in idx:
            _, c, _, _ = frames[i]
            _, ax, ay = place[i]
            sheet[ay : ay + c.shape[0], ax : ax + c.shape[1]] = c
        save(sheet, os.path.join(pages_dir, f"{name}_{p}.png"))
    meta = {"unitsPerPixel": round(1 / ppu, 5), "pages": len(pages), "anims": {}}
    if extra:
        meta.update(extra)
    for i, (anim, c, x0, y0) in enumerate(frames):
        p, ax, ay = place[i]
        meta["anims"].setdefault(anim, []).append({
            "p": p, "x": int(ax), "y": int(ay), "w": int(c.shape[1]), "h": int(c.shape[0]),
            "dx": round((x0 - anchor[0]) / ppu, 2), "dy": round((y0 - anchor[1]) / ppu, 2),
        })
    path = os.path.join(json_dir, f"{name}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(meta, f, separators=(",", ":"))
    return path, len(pages)
