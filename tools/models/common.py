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


# --- the palette: warm, saturated, taken from the ingredients (see REPLIT_BRIEF.md, "The art style") ---
TOMATO = "#e0533a"
BASIL = "#4caf50"
CHEESE = "#f4c64f"
CREAM = "#f6efe0"
CRUST = "#e3a35c"
TERRACOTTA = "#c8643a"
WOOD = "#c98b52"
WOOD_DARK = "#8a5a36"
OLIVE = "#6b8f3a"
TEAL = "#2fb39a"
SKY = "#8fc9e8"
NAVY = "#2f4a6b"
CHARCOAL = "#33383b"
STEEL = "#cfd6da"


# --- shared materials (made fresh for each model; lib.reset() clears them) ---
# Steel is painted-looking and light, not a dark mirror; wood and marble have soft, low-detail textures.
def steel(): return mat("steel", STEEL, rough=0.42, metal=0.25)
def steel_dark(): return mat("steel_dark", "#a7b1b7", rough=0.45, metal=0.25)
def chrome(): return mat("chrome", "#e6ebee", rough=0.32, metal=0.3)
def black(): return mat("black", CHARCOAL, rough=0.55)
def rubber(): return mat("rubber", "#3a3e41", rough=0.9)
def white(): return mat("white_plastic", "#f6f4ee", rough=0.45)
def marble(): return mat("marble", "#ffffff", rough=0.62, tex="marble", uvs=1.4)
def oak(): return mat("oak", "#ffffff", rough=0.6, tex="oak", uvs=0.6)
def walnut(): return mat("walnut", "#ffffff", rough=0.55, tex="walnut", uvs=0.6)
def kraft(): return mat("kraft", "#ffffff", rough=0.85, tex="kraft", uvs=0.5)
def glass(): return mat("glass", "#cfe6f0", rough=0.05, metal=0.0, alpha=0.22)
def dark_glass(): return mat("dark_glass", "#253036", rough=0.35, metal=0.1)
def red(): return mat("red", TOMATO, rough=0.45)
def emit_warm(): return mat("emit_warm", "#ffe2b0", rough=0.5, emit="#ffd9a0", emit_k=3.0)
def emit_cool(): return mat("emit_cool", "#f4fbff", rough=0.5, emit="#eaf6ff", emit_k=3.0)
def paint(name, col, rough=0.5): return mat(name, col, rough=rough)


# where the game puts each prop (FPWorld), for baking a room with its fixtures standing in it
PLACES = [("pass", (1.5, 0.92, -1.02)), ("bin", (-0.62, 0.92, -0.78)), ("crates", (-1.2, 0, 0.75)),
          ("fridge", (-0.62, 0, 0.97)), ("freezer", (1.3, 0, 1.08)), ("drystore", (0.42, 0, 1.08)),
          ("mop", (-1.28, 0, 0.25)), ("trapbox", (-1.3, 0, 1.12)), ("boxes", (1.32, 1.8, -1.0)),
          ("mixer", (-1.38, 0.92, -1.0)), ("dough_trays", (1.47, 0.92, -0.38)), ("clipboard", (-0.98, 1.55, -1.08))]
