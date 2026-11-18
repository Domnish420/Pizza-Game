# Crust Empire roadmap

What is built, what is next, and the order we are doing it in. The owner's priorities come first; the code side is
built in this repo and the look, sound and feel are for the Replit art pass (see `REPLIT_BRIEF.md`).

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

- [ ] Allergen chart and waste log (the data is already tracked)
- [ ] Defrosting frozen stock the day before; freezer frost
- [ ] Oven preheating, ash clearing, maintenance; fridges and mixers breaking down
- [ ] Driving the van to its pitch and setting up

## 4. Running a business

- [ ] Staff rotas, hours, breaks, morale, sick days, people quitting; training that takes shifts
- [ ] Weather, local events, holidays, competitors
- [ ] VAT and tax, loans, rent reviews, a weekly profit and loss

## 5. Look, sound and feel (Replit)

- [x] 3D first-person service world (GoPro angle): room, stations, look and gyro, touch on 3D objects and surfaces
- [x] First-pass models for every `fp.*` key, generated in Blender (`tools/models/`): rooms, street, dining room,
      counters, ovens, back of house, props, customers that sit at tables, hands
- [x] The art style: chunky, toy-like, warm ingredient colours, painted-in shadows, cartoon customers
      (REPLIT_BRIEF.md, "The art style"); a Retro (PS2) look as an option on the phone
- [ ] The pizza in 3D as the hero of the style: deforming dough, glossy sauce, melting cheese, char, steam
- [ ] Hand-made models to replace the generated ones, rigged hands and customers with animations
- [x] The morning and evening in the same 3D kitchen: every job a prop you tap (deliveries, prep, wash-up, counter,
      dough, cleaning, traps, boxes, temperatures, stores, checklist, open / lock up); management on a phone
- [ ] The hands-on minigames (prep, cleaning, unpacking, traps, folding, dough) done on the 3D props instead of 2D sheets
- [ ] A modelled phone in the hand for the management screens

- [ ] Art for every screen, animated customers and staff in a visible kitchen
- [ ] Dough that deforms properly for every stretching technique
- [ ] Leopard-spotted crusts, a living fire
- [ ] The counter, tubs and stores drawn as the real things
- [ ] Sound, music, haptics

## 6. Finishing

- [x] Story mode (above)
- [ ] Settings and save slots
- [ ] Balance and progression pass
- [ ] Testing on real phones: two-finger stretching, performance at the flagship
