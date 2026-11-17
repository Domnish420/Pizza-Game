# Crust Empire (Godot 4)

A hands-on pizza-making and restaurant-management game for phones, played in landscape.
You start alone in a pop-up pizza van and grow it into a flagship trattoria.

Every system is built and playable. All artwork is placeholder shapes: see `ART_KEYS.md`.
`REPLIT_BRIEF.md` is the handoff for the art and polish pass.

## Run it

1. Install Godot 4.3 or newer (standard build, no C#).
2. Open `project.godot` and press Play.
3. On a computer the left mouse button is one finger and the right button (or Shift + left) is two fingers.

The project is 1280x720, landscape, Compatibility renderer, so it exports to Android, iOS and the web.

## A day

**Morning.** Check the Today page, choose where the van trades, top up from the cash & carry, open.

**Service.** Four places to switch between:
- **Front**: customers walk up to the hatch and queue (van, kiosk), or wait at the door to be seated, order at the
  table, eat and ask for the bill (shop and bigger). Tap anyone with a marker: ORDER, FOOD UP, SEAT, BILL, CLEAR.
- **Bench**: tap a ticket and open the dough ball. Hand-stretched bases: press out with one finger, leaving a rim,
  then spread two fingers to stretch and twist them to turn. Thin bases: roll with the pin. Deep pan: push into the pan.
  Then top it by weight against the recipe card.
- **Oven**: drag the pizza off the shelf onto the deck. Drag its edge to spin it. Drag it out when it is done.
- **Board**: swipe to slice, add anything that goes on after the oven, send it to the pass.

**Evening.** Make tomorrow's dough, place tomorrow's orders, lock up. Overnight, out-of-date stock is binned,
deliveries arrive in the morning, and invoices are paid when they fall due.

## Systems

- **Buying by weight.** 69 ingredients, each in up to five grades (Value to Artisan) and up to three pack sizes,
  all priced per kg or litre. Better grades cost more, keep differently, taste better and earn bigger tips.
- **Suppliers.** Ten businesses, opening as you level: cash & carry (collect now), wholesaler, greengrocer, butcher,
  dairy, miller, fishmonger, Italian importer, farm collective, and a packaging & firewood merchant. Each has its own
  range, grades, pack sizes, delivery days, minimum order, delivery fee and payment terms. Prices move daily,
  produce is cheaper in season, and each supplier runs weekly offers.
- **Stock.** Every delivery is a dated lot with a grade and a cost, used oldest first and binned when out of date.
  The fridge, freezer and dry store have a capacity; deliveries that do not fit are wasted.
- **Recipe cards.** 48 pizzas, each with grams per ingredient on a named dough. The card shows the cost to make
  and the food-cost percentage. Everything you put on a pizza is weighed out of stock as you apply it.
- **Stock control.** The Stores page has a par sheet (what today and tomorrow need against what you hold and have on
  order) and a usage report (what was used against what the recipe cards allow, and what was binned).
- **Dough.** Six recipes in baker's percentages. Weigh every ingredient, knead, ball. Made the night before;
  binned after three days. Its quality and flour grade carry into every pizza.
- **Ovens.** Electric deck (2 pizzas, even heat) to start, then twin-deck electric, gas (hotter at the back),
  wood-fired (live fire to feed, turn every pizza), and rotating hearths (they turn for you).
- **Customers.** Each party judges look, taste, service and value out of 5. Taste is lifted by ingredient grade
  against what your price level promises. Tips depend on all of it. Reviews move your rating, which moves footfall.
- **Menus.** 14 menus, each run for 14 days and booked in advance.
- **The van** trades at a different pitch each day: high street, business park, farmers' market, taproom, seafront.
- **Staff.** Pizzaioli (portion more accurately as they train), prep cook, oven tender, kitchen porter, head chef,
  counter staff, servers, drivers, host, bartender, general manager (orders stock for you).
- **Premises.** Van, market kiosk, takeaway shop, pizzeria, high street restaurant, flagship.

## Code map

| File | What it does |
| --- | --- |
| `data/*.json` | All game data: ingredients, suppliers, doughs, pizzas, menus, venues, upgrades and ovens, staff |
| `scripts/data.gd` | Loads the JSON (autoload `Data`) |
| `scripts/stock.gd` | Lots, storage, dough trays, waste and the books (autoload `Stock`) |
| `scripts/market.gd` | Supplier catalogues, prices, baskets, orders, deliveries, invoices, par sheet (autoload `Market`) |
| `scripts/game.gd` | Save file, calendar, money, XP, pitches, menus, upgrades, staff, the night (autoload `Game`) |
| `scripts/art.gd` | Art and sound lookup by key (autoload `Art`) |
| `scripts/pizza_base.gd` | The dough base being opened: press, stretch, rotate, roll, pan, sheet |
| `scripts/pizza.gd` | One pizza: weighed toppings, bake state, and how a customer judges it |
| `scripts/oven.gd` | Oven heat, fire, deck spots |
| `scripts/service.gd` | A day's trading: customers, tickets, staff, reviews, the day's accounts |
| `scripts/front_scene.gd`, `bench.gd`, `oven_view.gd`, `pizza_draw.gd` | Drawing and touch input for each part of service |
| `scripts/hub.gd`, `suppliers_page.gd`, `stores_page.gd`, `dough_game.gd` | The management screens |
| `scripts/kit.gd`, `main.gd`, `meter.gd` | UI helpers, screen switching, gauges |

`web-prototype/` holds the first HTML version, kept for reference only.
