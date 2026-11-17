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

## Story or free play

The game opens on a choice. **Story** starts you as a pizzaiolo at Bella Napoli: the boss sets your checklist, you
prep, set up the counter and make pizzas, and each shift is reviewed and paid into your savings. Promotion to senior
pizzaiolo hands you the back of house (temperature logs, deliveries, rotation, cleaning down, dough, ordering and the
junior's prep list). Then your savings buy a van and you go it alone. **Free play** starts straight away in the van.

## A day

The day runs on a clock. You start at 07:00 and the venue opens at its opening time (11:30 for the van).

**Morning (Jobs page).** Deliveries arrive at the back door at their own times and wait there until someone checks
them in: unpack them by hand onto the shelves (new stock behind the old), or stack them in front to save time and let
the old stock go off at the back. Do the prep list by hand (slice, grate, pick, pour, stir) into 2 and 4 litre tubs
with day-dot labels, then set up the counter: fill the gastro pans on the rail from the tubs. Clean by hand, lay traps,
set the fridge and dry-store vents, wash up the tubs. Every job takes minutes; run past opening time and you open late.

`ROADMAP.md` has the story mode (starting as an employed pizzaiolo) and everything still to come.

**Service.** Four places to switch between:
- **Front**: customers walk up to the hatch and queue (van, kiosk), or wait at the door to be seated, order at the
  table, eat and ask for the bill (shop and bigger). Tap anyone with a marker: ORDER, FOOD UP, SEAT, BILL, CLEAR.
- **Bench**: the marble top of the pizza counter, with the rail of gastro pans above it. Tap a ticket and open the dough ball. Hand-stretched bases: press out with one finger, leaving a rim,
  then spread two fingers to stretch and twist them to turn. Thin bases: roll with the pin. Deep pan: push into the pan.
  Then top it by weight against the ticket's recipe card, taking each topping from its pan on the rail.
- **Oven**: drag the pizza off the shelf onto the deck. Drag its edge to spin it. Drag it out when it is done.
- **Board**: swipe to slice, add anything that goes on after the oven, send it to the pass.
- **Prep**: the rail and the tubs. Refill an empty pan from the tubs; when the tubs run out, prep more (you are tied
  up while you do it), let a prep cook or pizzaiolo do it, or 86 the pizzas that need it. Deliveries that turn up
  mid-shift wait here at the back door.

Customers ask for changes ("no basil", "extra mozzarella", "add olives", "well done") and some have allergies:
the ticket becomes its own recipe card, and getting an allergy wrong is serious (refund, a hit to your rating and an
early inspection). Unhappy customers complain at the hatch or the table: remake, refund, free drink or apologise.
Some pay cash and you count out the change. Phone orders are collected later. Regulars come back for their usual and
remember how you treated them. Now and then a food critic eats incognito.

**Evening.** Clean down, make tomorrow's dough, order tomorrow's stock, lock up. Work past midnight and you start late.
Overnight the fridge and dry store climate does its work, pests come in or get caught, out-of-date stock is binned,
and invoices are paid when they fall due.

## Systems

- **Buying by weight.** 71 lines, each in up to five grades (Value to Artisan) and pack sizes, all priced per kg or
  litre. Bigger packs are always cheaper per kg. Flour only comes in 25 kg sacks. Better grades cost more, keep
  differently, taste better and earn bigger tips.
- **Suppliers.** Ten businesses, opening as you level: cash & carry (click and collect at 7), wholesaler, greengrocer,
  butcher, dairy, miller, fishmonger, Italian importer, farm collective, and a packaging, fuel & hygiene merchant.
  Everything is ordered the day before. Each supplier has its own range, grades, pack sizes, delivery days, arrival
  window (later in winter, on Mondays, in summer traffic...), minimum order, delivery fee and payment terms.
  Prices move daily, produce is cheaper in season, and each supplier runs weekly offers.
- **Stock.** Every delivery is a dated lot with a grade and a cost, used in shelf order: anything stacked in front
  first, then oldest first. Out-of-date stock is binned. The fridge, freezer and dry store hold so many litres;
  whatever does not fit when it is put away is wasted. Chilled deliveries left at the back door spoil.
- **Ventilation.** The fridge and dry store each have vents. The fuller a store, the more airflow it needs. Too little:
  the fridge runs warm and food spoils days early, the dry store gets damp and flour goes mouldy. Too much: the fridge
  freezes leaves and soft cheese, and the dry store lets bugs and mice in.
- **Hygiene and pests.** The kitchen and front of house get dirty through service and are cleaned with time and
  chemicals. Pests come in when it is dirty, when the dry store is over-ventilated and in cold weather; traps catch
  them and need resetting; pest proofing keeps them out. Mice chew the dry stock and customers who see one leave.
  An inspector visits every couple of weeks and gives a 0-5 hygiene rating that changes footfall; 0 or 1 closes you.
- **Prep.** Toppings have to be prepped before service (grated, sliced, cooked, drained), with a yield and a short
  life once prepped, into 2 and 4 litre tubs that take fridge space and need washing once empty. Doing it by hand
  well is quicker and gives a better yield and a better-looking pizza.
- **The counter.** Every topping comes out of a gastro pan on the counter rail. The rail grows with the prep-station
  upgrades (6 pans on a folding table up to 28 across two marble-top pizza counters); a bigger menu needs a bigger rail.
  An unchilled rail goes back into tubs every night.
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
- **Staff.** Pizzaioli (portion more accurately as they train, and prep when there is no prep cook), prep cook (checks
  in deliveries, does the prep, preps mid-shift, makes the dough), oven tender, kitchen porter (puts deliveries away,
  keeps the kitchen clean, resets traps), head chef, counter staff, servers (and clean the dining room), drivers,
  host, bartender, general manager (orders tomorrow's stock).
- **Premises.** Van, market kiosk, takeaway shop, pizzeria, high street restaurant, flagship.

## Code map

| File | What it does |
| --- | --- |
| `data/*.json` | All game data: ingredients, suppliers, doughs, pizzas, menus, venues, upgrades and ovens, staff |
| `scripts/data.gd` | Loads the JSON (autoload `Data`) |
| `scripts/stock.gd` | Lots, rotation, the makeline, the back door, storage and ventilation, dough trays, the books (autoload `Stock`) |
| `scripts/market.gd` | Supplier catalogues, prices, baskets, orders and arrival times, invoices, par sheet, the manager's ordering (autoload `Market`) |
| `scripts/day.gd` | The clock outside service, arrivals, prep list, staff morning and close-down work (autoload `Day`) |
| `scripts/hygiene.gd` | Cleanliness, traps, pests, mouse sightings, inspections (autoload `Hygiene`) |
| `scripts/game.gd` | Save file, calendar, money, XP, pitches, menus, upgrades, staff, the night (autoload `Game`) |
| `scripts/art.gd` | Art and sound lookup by key (autoload `Art`) |
| `scripts/pizza_base.gd` | The dough base being opened: press, stretch, rotate, roll, pan, sheet |
| `scripts/pizza.gd` | One pizza: weighed toppings, bake state, and how a customer judges it |
| `scripts/oven.gd` | Oven heat, fire, deck spots |
| `scripts/service.gd` | A day's trading: customers, tickets, staff, reviews, the day's accounts |
| `scripts/front_scene.gd`, `bench.gd`, `oven_view.gd`, `pizza_draw.gd` | Drawing and touch input for each part of service |
| `scripts/hub.gd`, `jobs_page.gd`, `suppliers_page.gd`, `stores_page.gd`, `dough_game.gd` | The management screens |
| `scripts/prep_task.gd`, `clean_task.gd`, `shelf_task.gd` | Prepping, cleaning and unpacking by hand |
| `scripts/rail_view.gd` | The rail of gastro pans above the bench |
| `scripts/orders.gd` | Order notes and allergies turned into a recipe card per ticket |
| `scripts/checks.gd` | Opening and closing checklists, the temperature log (autoload `Checks`) |
| `scripts/story.gd` | The career: the employer, the crew, shift reviews, promotions, going solo (autoload `Story`) |
| `scripts/kit.gd`, `main.gd`, `meter.gd` | UI helpers, screen switching, gauges |

`web-prototype/` holds the first HTML version, kept for reference only.
