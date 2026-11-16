# Art keys

Drop a PNG at `assets/<file>` and the game uses it in place of the placeholder. Sizes are in game units
(the front scene is 640x320, the bench is 320x320); supply images at 3x those sizes or larger.

## Front of house (`scripts/front_scene.gd`)

| Key | File | Size | What it is |
| --- | --- | --- | --- |
| `bg.van` | `bg-van.png` | 640x320 | Street with the van on the left, hatch facing right at about (232,170). Queue runs right from x=285 at y=228 |
| `bg.kiosk` | `bg-kiosk.png` | 640x320 | Covered market, kiosk on the left, same layout as the van |
| `bg.shop` | `bg-shop.png` | 640x320 | Top-down room: pass along the left wall (x<54), door bottom right, tables in x 195-625, y 22-257 |
| `bg.pizzeria` | `bg-pizzeria.png` | 640x320 | Same layout, pizzeria dining room |
| `bg.restaurant` | `bg-restaurant.png` | 640x320 | Same layout, large restaurant |
| `bg.flagship` | `bg-flagship.png` | 640x320 | Same layout, grand trattoria |
| `customer.0` .. `customer.5` | `customer-0.png` .. | 30x52 | Standing customer, front view, six variants |
| `seated.0` .. `seated.5` | `seated-0.png` .. | 18x18 | Seated guest from above, six variants |
| `table.clean` / `table.food` / `table.dirty` | `table-clean.png` etc. | 44x34 | Table from above: laid, with pizzas, with dirty plates |
| `bubble.order` / `bubble.food` / `bubble.seat` / `bubble.bill` / `bubble.clear` | `bubble-order.png` etc. | 30x30 | Marker over a customer or table that needs you |

## Kitchen (`scripts/bench.gd`)

| Key | File | Size | What it is |
| --- | --- | --- | --- |
| `bench.bg` | `bench-bg.png` | 320x320 | Floured steel prep bench, top-down |
| `board.bg` | `board-bg.png` | 320x320 | Wooden cutting board, top-down |
| `pan` | `pan.png` | 220x220 | Round deep pizza pan, top-down |
| `pin` | `pin.png` | 150x26 | Rolling pin, top-down, horizontal |
| `top.<ingredient id>` | `top-<id>.png` | 24x24 | One piece of a topping, top-down. Ids: basil, pepperoni, mushroom, pepper, onion, olive, ham, pineapple, sausage, chicken, prawn, prosciutto, rocket, gorgonzola, parmesan, ricotta, chilli, artichoke, anchovy, nduja |
| `dough.blob` | `dough-blob.png` | 180x180 | Ball of dough for the kneading step |

Dough, sauce and cheese on the pizza are drawn by code (they change shape as you work) - see `Bench._draw`.

## Icons (`scripts/kit.gd`)

| Key | File | Size | What it is |
| --- | --- | --- | --- |
| `icon.<ingredient id>` | `icon-<id>.png` | 22x22 | Ingredient icon used in the market and the topping palette (all 30 ingredient ids in `data/game_data.json`) |

## Sound (`scripts/art.gd`)

`assets/sfx/ding.wav` (new order), `cash.wav` (paid), `bad.wav` (customer left), `tap.wav`, `up.wav` (level up, dough done).
