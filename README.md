# Crust Empire

A hands-on pizza-making and restaurant-management game for phones (landscape) and desktop browsers.

Start alone in a pop-up pizza van. Mix, knead and proof your own dough, buy ingredients at the market,
then work the service: stretch each dough ball, sauce it, cheese it, top it, bake it, slice it and serve it.
Earn money, reputation and XP, then hire a kitchen and front-of-house team, upgrade your equipment and
buy bigger premises, all the way to a flagship trattoria.

## Play

Open `index.html` in a browser. There is no build step and no dependencies.
On a phone, hold it sideways. If rotation is locked the game turns itself.
Progress saves automatically in the browser.

## What is in it

- **Dough**: measure flour and water, knead, proof. Dough quality feeds into every pizza's score.
- **Market**: 19 ingredients, spoilage overnight depending on your refrigeration.
- **Service**: live tickets with patience timers; takeaway, dine-in and delivery orders.
- **Menu**: 12 pizzas unlocked by level, three price levels.
- **Kitchen upgrades**: ovens, mixers, proofing, refrigeration, prep stations, dishwashing, suppliers.
- **Front-of-house upgrades**: POS, signage, marketing, drinks, delivery, furniture, ambience, comfort, tables.
- **Staff**: pizzaioli, prep cooks, oven tender, kitchen porters, head chef, counter staff, servers, drivers, host, bartenders, general manager. Hire, train, let go.
- **Premises**: van, market kiosk, takeaway shop, neighbourhood pizzeria, high street restaurant, flagship trattoria.

## Code

- `js/data.js` ingredients, recipes, venues, upgrade tiers, staff roles
- `js/game.js` save state, economy, derived stats
- `js/ui.js` management screens, dough making, day summary
- `js/service.js` the live service and pizza bench
- `build.py` bundles everything into one HTML file (`dist/crust-empire.html`)
