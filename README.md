# Crust Empire (Godot 4)

A hands-on pizza-making and restaurant-management game for phones, played in landscape.
You start alone in a pop-up pizza van and grow it into a flagship trattoria.

Every system is built and playable, in a 3D first-person kitchen with generated models (`tools/models/`).
`DESIGN.md` has the owner's vision, the art style and how the code is split; `ART_KEYS.md` lists every image and
model the game asks for; `ROADMAP.md` is what is built and what is next.

## Run it

1. Install Godot 4.3 or newer (standard build, no C#).
2. Open `project.godot` and press Play.
3. On a computer the left mouse button is one finger and the right button (or Shift + left) is two fingers.

The project is 1280x720, landscape, Compatibility renderer, so it exports to Android, iOS and the web.

## Test it

Bots play the real game and check that it behaves: `tests/run.sh` runs them all (about 16 minutes without a GPU),
`tests/run.sh wood_oven look_stick` runs just those. Each writes its log and screenshots to `tests/out/<name>/`. See
`tests/README.md` for what each one covers and how to write one. `gdlint scripts/ tests/` lints the GDScript (`pip
install gdtoolkit`; the rules are in `gdlintrc`).

## The title screen

The game opens on the owner's painting of the van (`assets/ui/title.jpg`), brought to life in code
(`scripts/title_screen.gd`): smoke and sparks rise from the oven's chimney, the fairy lights twinkle, the oven
flickers and lights the cobbles, a shine crosses the sign every few seconds, and the picture drifts slowly. Tap the
sign for a puff from the chimney. The menu is a chalkboard: **Continue** (your saved day, with its day, place and
cash), **New game** (the story or free play; it asks before replacing a save), **Settings** (the 3D kitchen, looking
by turning the phone, the retro look) and **Quit** on a computer. The phone's home page has a Title screen button.

## The crew

At Bella Napoli you can see the people you work with: Marco, the boss, stands out past the pass in his toque
while you are his pizzaiolo, watching every pizza go out, tapping his rolling pin and waving you on through your
training day; once you are senior, Luca works at the end of the prep counter. They turn their heads to follow you.

## Story or free play

**New game** offers two starts. **Story** starts you as a pizzaiolo at Bella Napoli, under Marco
(`scripts/story.gd`, `Story.PLAN`). Your first week builds the job up a piece at a time:

| Day | You | Marco | How busy |
| --- | --- | --- | --- |
| 1 | stretch the bases | tops, bakes, cuts and sends them | very quiet |
| 2 | stretch and top | bakes, cuts and sends | quiet |
| 3 | top and work the oven | stretches them first; cuts and sends | quiet |
| 4 | whole pizzas, ticket to pass | makes his own beside you | slow |
| 5 to 7 | whole pizzas | the same | busier every day |

On days 1 to 3 Luca does the morning prep and sets up the counter, and Marco only picks up a ticket himself if it has
waited too long; from day 4 the prep and the counter are yours. Each shift is reviewed (how many pizzas for how busy
the day was, how good they were, the portions, the checklists) and paid into your savings. After day 7, if your days
4 to 7 averaged 55 or more, you are promoted to senior pizzaiolo, and the next day is a training day on the back of
house. Your first senior shift (day 8) is still quieter, the next busier, and from day 10 it is a normal restaurant
service. Seven senior shifts averaging 70 and a good hygiene inspection, and your savings buy a van: you go it alone.
**Free play** starts straight away in the van.

**Marco guides you** (`scripts/tutor.gd`, autoload `Tutor`). Your first shift is guided and counts: he has you look
around, open, take the first ticket, press and stretch the dough, and hand it to him at the oven, then leaves you to
it. On the mornings of days 2 to 4 he briefs you on what has changed, and the recipe card says what is yours today.
A box at the top says what to do next and a yellow marker floats over the thing to touch (or a button lights up);
each step finishes when you have actually done it. The senior's training day covers the fridge and freezer
temperatures, the delivery at the back door, a sprung trap, the counter, the phone, then the evening: cleaning down,
washing up, the dough, the order, tomorrow's prep sheet and the evening temperature. That one does not count: when it
ends (or you skip it) the game goes back to exactly how it was, ready for the real shift.

## A day

The day runs on a clock. You start at 07:00 and the venue opens at its opening time (11:30 for the van).

**Morning (Jobs page).** Deliveries arrive at the back door at their own times and wait there until someone checks
them in: unpack them by hand onto the shelves (new stock behind the old), or stack them in front to save time and let
the old stock go off at the back. Do the prep list by hand (slice, grate, pick, pour, stir) into 2 and 4 litre tubs
with day-dot labels, then set up the counter: fill the gastro pans on the rail from the tubs. Clean by hand, lay traps,
set the fridge and dry-store vents, wash up the tubs. Every job takes minutes; run past opening time and you open late.

`ROADMAP.md` has the story mode (starting as an employed pizzaiolo) and everything still to come.

**The whole day is 3D and first person.** Between services you are in the same kitchen (`scripts/fp/kitchen_screen.gd`)
and every job is something in the room: the crates at the back door (put the delivery away), the tubs on the prep
counter (prep), the sink (wash up), the pans on the rail (set up the counter), the mixer (make dough), the proving
trays, the mop and the spray (clean), the box of traps (pest control on the floor plan), the pizza boxes on the shelf
(fold them), the fridge thermometer (the temperature log), the fridge and dry store (stores and vents), the clipboard
(the checklist) and the clock above the hatch (clock in to open, clock out to lock up and go home). Labels over them
say how each stands; the sign at the hatch tells the customers whether you are open. Ordering, KitBox, the menu, staff and premises are on your phone (the Phone button).

**You clock in and out on the clock.** Every scene has a clock on the wall above the hatch (above the pass in a
restaurant), and its hands show the time. Tap it in the morning to clock in and open ("Clock in · open at 11:30"
beside it), during service to clock out early (it asks first; at closing time the day ends by itself), and at night to
clock out, lock up and go home. There are no open or close buttons: the time on the screen and on the phone is only a
readout. (The classic 2D layout, kept for testing, has no room to look round, so there its time is the button.)

**Sound.** Every action has its own sound (the dough's pat, the ladle, cheese going on, the peel on the stone, the
pizza wheel, the pass bell, the till), and the kitchen has a background: the extractor's hum, the wood fire
crackling (louder at the oven) and the customers' murmur. A gentle waltz plays on the title screen and between
services. On a phone, the game vibrates: a tick as you press the dough, a buzz when a pizza starts to burn. The sounds
and music are generated by `tools/sfx/`; Sound, Music and Vibration each switch off in Settings or on the phone.

**Looking around.** A thumb stick in the bottom-left corner turns your head (push further to turn faster); let go
near a station and you settle on it, tap it to look back at your station. It never touches the work, so looking and
making a pizza do not fight. The station buttons beside it still jump straight to each station, dragging on the room
still looks around, and turning the phone still turns your head.

**A quiet screen.** Your hands are just hands (no arms reaching into the work). The recipe card is short by default:
the pizza, its size, the grams and the one thing to do next; More opens the full card (with the explanations, the
cost so far and today's served and dough counts). Names over things show only when they matter: the pans' names at
the counter, the pass when a pizza is ready to go, the bin when you have a pizza in hand, a table when it needs
clearing or someone is waiting to be seated.

**Service is 3D and first person** (`scripts/fp/`): you stand at the counter in the van or the kitchen, seen from a
chest-mounted wide camera, with the hatch or the pass ahead, the oven and cutting board on your right and the prep
station on your left. The stick and the station buttons turn your head (see Looking around above). Tap
customers, tickets on the ticket rail, the pans on the rail and the ladles on their rack where they are; the bench,
board, oven and prep tablet take your fingers directly, so two-finger stretching happens on the marble in front of
you. The classic 2D layout can be switched back on from the Today page.

The stations (the same in both layouts):
- **Front**: customers walk up to the hatch and queue (van, kiosk), or wait at the door to be seated, order at the
  table, eat and ask for the bill (shop and bigger). Tap anyone with a marker: ORDER, FOOD UP, SEAT, BILL, CLEAR.
- **Bench**: the marble top of the pizza counter, with the rail of gastro pans above it. Tap a ticket and the dough ball
  is on the bench. There are no steps and no "base is ready" button: shape it, top it and take it to the oven in
  whatever order you like.
  - With an empty hand, one finger presses the dough out (leave a rim) and two fingers stretch and twist it. Thin
    bases: roll with the pin (or tap the sheeter). Deep pan: push into the pan. Two fingers always stretch, even
    while you hold a topping.
  - Tap a pan on the rail to pick that topping up; one finger then puts it on, anywhere, any time. Tap the pan again
    to put it back and have your hands free.
  - Sauce goes on with a portion ladle: tap the sauce pan to scoop (a 2 oz ladle holds exactly 2 oz), drop it in the
    middle, spread it out with the back of the ladle in circles. Pick the size on the ladle rack; tap the ladle you
    hold to hang it back. A standard pizza takes 2 oz, a New York one 3 oz.
  - The moment the dough is on the bench it can go in the oven: turn to the oven and it comes with you on the peel
    (turn back without loading it and it comes back). Starting the next ticket sends the one on the bench to the shelf
    by the oven.
- **Oven**: drag the pizza off the shelf onto the deck: it goes in on the peel. Drag its edge to spin it with the
  turning peel. Drag it out when it is done. Wood ovens: put it where you like on the floor (hot by the fire, gentler
  by the mouth), turn it so it colours evenly, and tap the stack of logs beside the mouth when the Oven button says
  FEED THE FIRE.
- **Board**: swipe across with an empty hand to slice; anything you pick up goes on wherever you put it (sauce or
  cheese after the oven is judged as uncooked; finishing toppings belong here). Tap the pass behind the board to send
  it out. The bin is at the end of the counter.
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
  chemicals. Pests come in when it is dirty, when the dry store is over-ventilated and in cold weather; pest proofing
  keeps them out. Every premises has a floor plan (`data/floorplans.json`) with the ways mice get in: gaps under
  doors, drains, pipe holes, air bricks. You place each trap on the plan: one flat against a wall close to a way in
  that mice use catches them; one in the open catches almost nothing. Droppings build up where they are getting in.
  Sprung traps need resetting. Mice chew the dry stock and customers who see one leave.
  An inspector visits every couple of weeks and gives a 0-5 hygiene rating that changes footfall; 0 or 1 closes you.
- **Prep.** Toppings have to be prepped before service (grated, sliced, cooked, drained), with a yield and a short
  life once prepped, into 2 and 4 litre tubs that take fridge space and need washing once empty. Doing it by hand
  well is quicker and gives a better yield and a better-looking pizza.
- **The counter.** Every topping comes out of a gastro pan on the counter rail. The rail grows with the prep-station
  upgrades (6 pans on a folding table up to 28 across two marble-top pizza counters); a bigger menu needs a bigger rail.
  An unchilled rail goes back into tubs every night.
- **Recipe cards.** 48 pizzas, each with grams per ingredient on a named dough. The card shows the cost to make
  and the food-cost percentage. Everything you put on a pizza is weighed out of stock as you apply it.
- **The waste log.** The Stores page keeps the last week: each day's food used, what was binned, its share (a
  well-run kitchen keeps it under 3%) and the main reason (pizzas binned, out of date, overproofed dough, frozen in
  the fridge, damp, mice, left out too long, no room, dough mistakes), then the week's total and where it went.
- **The allergen chart.** The Menu page shows the 14 allergens UK law asks you to declare against everything you sell
  tonight, worked out from each ingredient's allergens and the dough it is made on (the gluten-free dough has none).
- **Stock control.** The Stores page has a par sheet (what today and tomorrow need against what you hold and have on
  order) and a usage report (what was used against what the recipe cards allow, and what was binned).
- **Dough.** Six recipes in baker's percentages. Weigh every ingredient, knead, ball. Made the night before;
  binned after three days. Its quality and flour grade carry into every pizza.
- **Ovens.** Electric deck (2 pizzas, even heat) to start, then twin-deck electric, gas (hotter at the back),
  wood-fired (live fire to feed, turn every pizza), and rotating hearths (they turn for you). A wood oven is lit in the
  morning (tap it: about two hours to reach 450 °C) and kept fed; logs catch, burn down and leave coals, the deck is
  hottest by the fire, and each pizza bakes from the spot it sits on.
- **Customers.** Each party judges look, taste, service and value out of 5. Taste is lifted by ingredient grade
  against what your price level promises. Tips depend on all of it. Reviews move your rating, which moves footfall.
- **Pizza boxes.** Boxes come flat. Fold a stack before you open (by hand, four folds a box, or quickly); takeaway
  pizzas and baked sides go into a folded box at the pass. With none folded, one is folded on the spot while the
  customer waits. The kitchen porter or prep cook folds them in the morning, counter staff in quiet moments.
- **Sides, desserts and drinks** (`data/extras.json`). Garlic bread (with or without mozzarella) and a chocolate
  hazelnut pizzetta are made on the bench and baked like a pizza, spread with a ladle of garlic butter or finished
  on the board. A rocket and parmesan salad, tiramisu and ice cream (with a scoop) are plated cold. Drinks need the
  drinks upgrades: cans and bottled water from the fridge, espresso and cappuccino made at the machine, lager and wine
  by the glass, spritz and Negroni at the bar. Customers add them to their order; at a table, dessert is ordered after
  the meal. Each one uses stock you buy (a drinks wholesaler opens at level 3) and can be switched off on the Menu page.
- **Delivery app** (`data/delivery_app.json`, a fictional app called Hungrr). Join from the kiosk on. During service
  orders ping on a tablet: accept them in time or they count as missed. A rider is booked to collect each one, waits a
  short while, and leaves without it if it is not ready. The app keeps 30% of every order, and its rating of you
  (moved by reviews, lateness, missed and cancelled orders) sets how many orders it sends. Counter staff accept
  orders for you, but not when the kitchen is swamped. Pause it on the Front page or from the service screen.
- **Menus.** 14 menus, each run for 14 days and booked in advance.
- **The van** trades at a different pitch each day: high street, business park, farmers' market, taproom, seafront.
- **Staff.** Pizzaioli (portion more accurately as they train, and prep when there is no prep cook), prep cook (checks
  in deliveries, does the prep, preps mid-shift, makes the dough), oven tender, kitchen porter (puts deliveries away,
  keeps the kitchen clean, resets traps), head chef, counter staff, servers (and clean the dining room), drivers,
  host, bartender, general manager (orders tomorrow's stock).
- **Premises.** Van, market kiosk, takeaway shop, pizzeria, high street restaurant, flagship.
- **Utensils and small equipment (KitBox).** Every utensil is bought, one at a time or by the pack, from KitBox, the
  in-game catering-supplies website (`data/equipment.json`, 53 products at typical catering-supplier prices): checkout
  is paid by card and a courier delivers the next working day, free over $50. You own a count of each, everyone working
  at once needs their own, and each one matters:
  portion ladles in every size (1 to 8 oz; see sauce above); a pizza peel to load and pull pizzas (staff wait for one
  if there are too few); a turning peel to turn pizzas in gas and wood ovens; a pizza wheel or rocking cutter (with
  only a knife the slices are ragged); a bench scraper (even dough balls); a rolling pin for thin bases unless a sheeter
  does it; a dough docker (no bubbles in rolled bases); deep pan tins (one per deep-pan pizza from bench to board);
  proving trays (12 dough balls each: no tray space, no dough); an oven brush (no ash on wood-fired bases); an infrared
  thermometer (the exact oven heat); serving boards (dine-in pizzas look better).
  For prep, a chef's knife and the right colour-coded chopping board (green veg, brown roots, white dairy, yellow cooked
  meat, red raw meat, blue fish; the inspector checks), a box or rotary grater (rotary is much quicker), a colander,
  a frying pan or saucepan for cooked prep, a stick blender (sauce takes far longer without one), a mixing bowl (mixing
  dough with no mixer), a measuring jug and scales (without them you weigh by eye), a probe thermometer for cooked food,
  and the purple allergen board and knife (staff rarely get allergy orders wrong with them).
  Gastronorm pans for the counter rail (a new counter needs its own size of pan), a thermometer per fridge and freezer
  (no thermometer, no temperature log), day-dot labels (one per tub; unlabelled tubs fail inspections), mops for the
  kitchen and dining room, spray bottles and cleaning cloths (used up as you clean). Plates, cutlery and glasses (you
  can only seat as many guests as you can lay places for; some get broken), insulated delivery bags (one per driver or
  deliveries arrive cold), and the first aid kit, fire blanket, extinguisher and hand-wash station the inspector checks.
  The KitBox page has a "What you need" tab worked out from your counter, menu and staff.

## Code map

| File | What it does |
| --- | --- |
| `data/*.json` | All game data: ingredients, suppliers, doughs, pizzas, sides/desserts/drinks (extras), menus, venues, floor plans, upgrades and ovens, staff, equipment (KitBox), the delivery app |
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
| `scripts/title_screen.gd` | The animated title screen and its chalkboard menu |
| `scripts/hub.gd`, `jobs_page.gd`, `suppliers_page.gd`, `stores_page.gd`, `dough_game.gd` | The management screens |
| `scripts/prep_task.gd`, `clean_task.gd`, `shelf_task.gd` | Prepping, cleaning and unpacking by hand |
| `scripts/rail_view.gd` | The rail of gastro pans above the bench (2D layout) |
| `scripts/fp/fp_world.gd`, `fp_view.gd`, `fp_surface.gd` | The 3D first-person kitchen: room, camera, look, touch, 3D props and job props, and the station surfaces |
| `scripts/fp/pizza_3d.gd`, `shaders/pizza.gdshader` | The pizza in 3D on the bench, in the oven and on the board, built live from its data (dough, sauce, cheese, toppings, browning, cuts, steam) |
| `scripts/fp/kitchen_screen.gd` | Between services in 3D: the jobs you tap in the room, the checklist, the phone with the management screens |
| `scripts/orders.gd` | Order notes and allergies turned into a recipe card per ticket |
| `scripts/checks.gd` | Opening and closing checklists, the temperature log (autoload `Checks`) |
| `scripts/story.gd` | The career: the employer, the crew, shift reviews, promotions, going solo (autoload `Story`) |
| `tools/models/` | The Blender scripts that generate every 3D model into `assets/models/` (see `tools/models/README.md`) |
| `scripts/tutor.gd` | The training days before the first pizzaiolo and first senior shift: Marco's steps, the marker, put the game back after (autoload `Tutor`) |
| `scripts/equip.gd` | Utensils and small equipment: what you own, what each one does, what you need, KitBox orders and parcels (autoload `Equip`) |
| `scripts/shop_page.gd` | The KitBox catering-supplies website |
| `scripts/trap_task.gd`, `fold_task.gd` | Laying traps on the floor plan, folding boxes by hand |
| `scripts/kit.gd`, `main.gd`, `meter.gd` | UI helpers, screen switching, gauges |

`web-prototype/` holds the first HTML version, kept for reference only.
