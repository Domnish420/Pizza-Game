"""The registry of models and the materials most of them share."""
from lib import mat

MODELS = {}


def model(*keys, **kw):
    """register a builder for one or more keys: @model("oven.gas", kind="gas")"""
    def deco(fn):
        for k in keys:
            MODELS[k] = (fn, kw)
        return fn
    return deco


# --- shared materials (made fresh for each model; lib.reset() clears them) ---
def steel(): return mat("steel", "#cfd4d6", rough=0.34, metal=0.6, tex="steel", uvs=0.6)
def steel_dark(): return mat("steel_dark", "#8f989d", rough=0.4, metal=0.65, tex="steel", uvs=0.6)
def chrome(): return mat("chrome", "#e3e7e9", rough=0.15, metal=0.85)
def black(): return mat("black", "#1d1f20", rough=0.55)
def rubber(): return mat("rubber", "#2a2a2a", rough=0.9)
def white(): return mat("white_plastic", "#f2f2ef", rough=0.45)
def marble(): return mat("marble", "#ffffff", rough=0.22, tex="marble", uvs=1.4)
def oak(): return mat("oak", "#ffffff", rough=0.6, tex="oak", uvs=0.5)
def walnut(): return mat("walnut", "#ffffff", rough=0.55, tex="walnut", uvs=0.5)
def kraft(): return mat("kraft", "#ffffff", rough=0.85, tex="kraft", uvs=0.5)
def glass(): return mat("glass", "#cfe6f0", rough=0.05, metal=0.0, alpha=0.18)
def dark_glass(): return mat("dark_glass", "#15191b", rough=0.08, metal=0.2)
def red(): return mat("red", "#c0392b", rough=0.45)
def emit_warm(): return mat("emit_warm", "#ffe2b0", rough=0.5, emit="#ffd9a0", emit_k=3.0)
def emit_cool(): return mat("emit_cool", "#f4fbff", rough=0.5, emit="#eaf6ff", emit_k=3.0)
