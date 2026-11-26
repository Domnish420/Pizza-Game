# Crust Empire roadmap

What is built, what is next, and the order we are doing it in. The owner's priorities come first. Everything is built
in this repo; the vision and the art style are in `DESIGN.md`.

## Story mode (the tutorial and career)

The game starts as a job in someone else's pizzeria and works up to running your own.

1. **Pizzaiolo.** You only make pizzas and do prep, to a checklist the senior pizzaiolo has set: prep these tubs,
   fill these gastros, make these pizzas to the recipe card. You learn stretching, topping by weight, the oven and the
   counter without having to run anything.
2. **Senior pizzaiolo.** You take on the back-of-house jobs: opening and closing checks, fridge temperature logs,
   stock check and rotation, ordering, cleaning the kitchen down for the next day, and setting the prep checklist for
   the other pizzaiolos. You are now running a kitchen, but not paying for it.
3. **Your own pop-up van.** You leave to go solo: the sandbox game as it is today, starting in the van, doing everything
   yourself.
4. **Your own restaurant.** Kiosk, shop, pizzeria, high street restaurant, flagship.

Each stage has goals to pass before promotion and a boss who checks your work. The checklists reuse the jobs below.

- [x] Start screen: Story or Free play
- [x] The first week builds the job up: day 1 stretching for Marco, day 2 stretching and topping, day 3 topping and
      the oven, from day 4 whole pizzas beside him, busier each day; senior from day 8, a normal service by day 10
- [x] Pizzaiolo at Bella Napoli: the boss's opening and closing checklist, prep and counter, making pizzas;
      the boss makes the dough, orders and keeps the temperature log; a wage into your savings every shift
- [x] Shift reviews from the boss (pizzas, portions against the recipe cards, checklists) and promotion goals
      (5 shifts averaging 70)
- [x] Senior pizzaiolo: the full opening and closing checklists, temperature logs, deliveries, rotation, cleaning down,
      dough, ordering, and tomorrow's prep list that the junior preps before you get in; reviewed on checklists,
      waste, customers and hygiene; promotion needs 6 good shifts and a hygiene inspection of 3 or better
- [x] Going solo: your savings buy the van, your level comes with you, career goals up to the flagship
- [x] Training day before the first pizzaiolo shift: Marco walks you through prep, the counter, opening and making a
      Margherita from the ticket to the pass, then two on your own; a marker shows what to touch; nothing counts
- [x] Training day before the first senior shift: temperatures, the delivery, a sprung trap, the counter, the phone,
      then the evening close (cleaning, washing up, dough, the order, the prep sheet, the evening temperature)
- [ ] Cut scenes and character art for the boss and crew; more story beats between promotions

## 1. Hands-on jobs

- [x] Prep into 2 L and 4 L tubs with day-dot labels and use-by dates
- [x] Gastronorm pans on the pizza counter's chilled glass rail, filled from the tubs; toppings come off the rail;
      the marble top is the bench you stretch on
- [x] Empty tubs go to the wash-up
- [x] Prep by hand: knife work, grating, picking leaves, draining and pouring, stirring
- [x] Cleaning by hand: scrub the kitchen and the front
- [x] Putting deliveries away by hand: each line behind or in front of the old stock
- [x] Traps placed on a floor plan where the mice actually come in
- [x] Folding and boxing takeaways
- [x] Fridge and freezer temperature logs (the inspector checks them) and opening/closing checklists
- [x] Sauce with portion ladles: scoop an exact amount, drop it, spread it; every size bought separately
- [x] Every utensil and piece of small equipment bought from KitBox, the catering-supplies site, and used in play:
      peels, turning peels, cutters, scrapers, pins, dockers, tins, proving trays, knives and colour-coded boards,
      graters, blenders, pans, scales, thermometers, gastronorm pans, day-dots, mops, cloths, tableware, delivery bags,
      safety equipment

## 2. Customers as people

- [x] Changes to orders: no X, extra X, add X, well done
- [x] Allergies, with real consequences if you get it wrong
- [x] Complaints you handle: remake, refund, free drink, or apologise
- [x] Paying by cash or card, and giving the right change
- [x] Regulars who come back for "the usual" and remember how you treated them
- [x] Phone orders for collection
- [x] Incognito food critics
- [x] Drinks, sides and desserts you make
- [x] Delivery-app tickets

## 3. Running a real kitchen

- [x] Allergen chart (the 14 allergens, from the ingredients) and a waste log with the reasons, on the phone
- [ ] Defrosting frozen stock the day before; freezer frost
- [ ] Oven preheating, ash clearing, maintenance; fridges and mixers breaking down
- [ ] Driving the van to its pitch and setting up

## 4. Running a business

- [ ] Staff rotas, hours, breaks, morale, sick days, people quitting; training that takes shifts
- [ ] Weather, local events, holidays, competitors
- [ ] VAT and tax, loans, rent reviews, a weekly profit and loss

## 5. Look, sound and feel

- [x] 3D first-person service world (GoPro angle): room, stations, look and gyro, touch on 3D objects and surfaces
- [x] First-pass models for every `fp.*` key, generated in Blender (`tools/models/`): rooms, street, dining room,
      counters, ovens, back of house, props, customers that sit at tables, hands
- [x] The art style: chunky, toy-like, warm ingredient colours, painted-in shadows, cartoon customers
      (DESIGN.md, "The art style"); a Retro (PS2) look as an option on the phone
- [x] The pizza in 3D on the bench and the board, built live from its data: dough ball to stretched base with a
      puffy rim, glossy sauce, cheese shreds that melt and blister, toppings, browning with leopard spots, cuts, steam
- [x] The pizza in 3D in the oven: hollow ovens with a visible deck and their heat source, the deck map laid on
      it, real pizzas browning as they bake, a peel, live flames, READY / TURN labels
- [x] A title screen from the owner's painting: smoke, sparks, fairy lights, the oven's glow, a shine on the sign;
      a chalkboard menu (Continue, New game, Settings, Quit)
- [x] A real wood fire: lit in the morning two hours before opening, logs that catch, burn down and leave coals, a
      dome that heats and cools slowly, a deck hotter by the fire than by the mouth that cools under each pizza, every
      pizza baking from where it sits; launching and turning peels in your hand; a round firebrick dome
- [x] Customers that move: walking, standing, ordering, impatient, sitting down, eating (procedural, on joints)
- [x] The cast as soft clay toys after the owner's reference: big wide heads, round noses, ears, open smiles, sculpted
      hair, a kid, a granny, a ginger, a teen, a businessman, a papa and the rider, clothes with their details,
      four-finger hands
- [x] Marco and Luca in the kitchen (the boss by the pass, the junior at the prep counter), alive and watching you
- [x] Proper oven doors between services; the prep list on the prep tablet; the 2D layout can light the wood oven
- [x] Each person is one mesh per joint (about half the draw calls)
- [x] Lower-detail versions of the people for far tables (Godot's automatic LOD: about 2,500 triangles past 8 m)
- [x] Fewer draw calls: plain colours merged into vertex colours (a person 36 draw calls to 12, the restaurant's pass
      500 to 250); a performance overlay and a Graphics setting for phones
- [x] Controls: look speed, invert, the stick on either side, bigger buttons, a put-it-down button, cut assist,
      station buttons that pulse when they need you
- [x] A look stick for the camera; hands without arms; a sparse HUD (a short recipe card, labels only when they
      matter)
- [x] The phone is your head: moving the phone looks round and picks the station you face (no snapping, steady
      while a thumb works); both thumbs are hands, each independent (left thumb, left hand; the hand that picks a
      topping up holds it)
- [x] A game controller as two hands: the sticks move them, the triggers put them down, the stick clicks are the
      thumbs (let go), the shoulders turn to the next station; dialogs answerable with A
- [x] Phone VR (a Cardboard-style viewer): two eyes bent for the lens, head tracking, the controller's hands (or the
      viewer's button at the middle of your view), the game's screens on a panel in the room, dialogs where you look
- [x] Every mechanic with a controller: the 2D screens (sheets, phone, dialogs, menus) take the controller's hands
      as fingers (rings, press, drag, scroll), in the kitchen, the menus and VR
- [x] Android: an APK build (tools/android), the ARCore plugin built for the game
- [x] AR (ARCore): walking round the kitchen for real (on the screen and in VR), and the kitchen in your room
      (the camera's picture behind the counters) — to be tried on a phone
- [ ] AR: put the kitchen down on your floor (plane detection), scale it, light it like the room
- [x] The Quest (OpenXR): a Quest build (Meta's plugin, hand tracking); real head (walking), real hands: fingertips
      on the dough, pinch at things out of reach and at the panel's buttons, the thumbstick turns, B/Y put down,
      controller buzz — to be tried on the headset
- [x] Quest: passthrough (AR's "the kitchen in your room": the room through the headset's cameras)
- [x] Quest: the counters at their real height for your height (standing), or brought down to a desk (seated);
      the dough held, tossed and caught in your real hands
- [ ] Quest: hand-made hand poses on the tracked joints, sounds placed in the room, picking things up with a fist
- [ ] VR (OpenXR, Quest): the same kitchen with tracked hands
- [x] A clock on the wall in each scene to clock in and out on (open, close early, lock up), its hands keeping time
- [x] Hands that change pose with what they hold (open, pinch, grip)
- [ ] Hand-made models to replace the generated ones; keyframed animation (waving, paying, leaving with a box)
- [x] The morning and evening in the same 3D kitchen: every job a prop you tap (deliveries, prep, wash-up, counter,
      dough, cleaning, traps, boxes, temperatures, stores, checklist, open / lock up); management on a phone
- [ ] The hands-on minigames (prep, cleaning, unpacking, traps, folding, dough) done on the 3D props instead of 2D sheets
- [ ] A modelled phone in the hand for the management screens

- [ ] Art for every screen, animated customers and staff in a visible kitchen
- [x] Every way of opening a base by hand there from the first one, on a phone, a controller and a headset: pressing,
      stretching, the slap, lifting it onto your knuckles and turning it, tossing it spinning (flops, tears, catches)
- [x] Thickness across the base, not only round the edge: every technique thins or evens it, pressed through it
      tears; it shows in 3D and 2D, and it is scored and reviewed
- [ ] Dough that looks like dough as it is worked: flour, the stretch under the fingers
- [ ] Leopard-spotted crusts, a living fire
- [ ] The counter, tubs and stores drawn as the real things
- [x] Sound: a sound for every action and a background in the kitchen (hum, fire, the dining room), generated
      by `tools/sfx/`
- [x] Music (a generated waltz for the title and between services) and haptics (ticks and buzzes on a phone)

## 6. Finishing

- [x] Story mode (above)
- [ ] Settings and save slots
- [ ] Balance and progression pass
- [ ] Testing on real phones: two-finger stretching, performance at the flagship
