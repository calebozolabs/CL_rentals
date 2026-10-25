# CL Rentals

Vehicle rental desks for **Qbox, QBCore and ESX**. You build every desk in-game: the agent, spawn points, categories, vehicles and the price of every rental period. Players pick a vehicle, rent it for 30 minutes, 1 hour or 3 hours, and get a signed rental contract.

Free release by Calebozo Labs.

## Requirements

- `ox_lib`, `oxmysql`, OneSync
- One of `qbx_core`, `qb-core` or `es_extended` (detected automatically)
- `ox_target` or `qb-target`, or set `Config.Interaction = 'textui'` and use [E]

## Install

1. Put `CL_rentals` in your resources folder and add `ensure CL_rentals` after your framework and inventory.
2. Give admins the ace: `add_ace group.admin cl.admin allow`
3. Optional: add the contract item. See [install/README_ITEMS.md](install/README_ITEMS.md).
4. Start the server. The tables are created automatically, and one example desk is added at Legion Square.

## Building a desk: `/rentaladmin`

**Rental desks → New desk** starts a desk where you stand.

- **General**: the name, open/closed, the agent's ped model and position, the return radius and the map blip. To position the agent, use *My position*, or *Aim* to place it with a live preview (scroll to rotate).
- **Categories**: the tabs players browse, for example Economy, Sport, Motorcycles or Boats. Each category has an icon, and can require a licence (driver, motorcycle, truck, boat or pilot).
- **Vehicles**: add vehicles by spawn name. The model is checked and its label filled in for you, and add-on vehicles work too. Give every vehicle its own price for each period, plus an optional deposit. Leave a period empty to not offer it for that vehicle.
- **Spawn points**: where rented vehicles appear, placed by aiming with a vehicle preview. Rentals use the first free spot.

The checklist shows what is still missing. **Save** applies the desk for every player straight away.

The admin panel also has **Live rentals** (time left, the contract, and ending a rental with a full deposit refund), **History**, and **Settings**.

## Renting

1. Third-eye the agent and choose **Rent a vehicle**.
2. Browse the categories, pick a vehicle and a period (30 min, 1 h or 3 h), and pay by bank or cash.
3. The vehicle appears on a spawn point with keys and a full tank, and the player gets the **rental contract**. It shows the renter's name, the vehicle, the plate, the period, the return time, the price, the deposit and the terms.

`/rentals` shows a player's active rentals with a live countdown, the contract, a GPS to the vehicle and **Extend**.

## When the time runs out

The renter is warned before the end (10 and 2 minutes by default). The warning says exactly what will happen next.

- **Charge again** (default): if the vehicle isn't returned in time, the renter is charged the same price again for another period, and the warning tells them so up front. The vehicle is repossessed and the deposit kept if they can't pay, are offline, or reach the renewal limit.
- **Repossess**: after a grace period the vehicle is taken and the deposit is kept.

## Returning

Drive the rental into a desk's return zone and press **[E]**, or ask the agent. The deposit is refunded minus the damage percentage, and the vehicle and contract are taken back. Returns are accepted at any desk, or only at the original one if you prefer.

## Configuration

- `shared/config.lua`: framework, target, keys, fuel, notifications, payment accounts, periods, deposits and expiry rules.
- `shared/config_advanced.lua`: the example desk, category icons, licence types and agent behaviour.
- `shared/theme.lua`: colours.
- `locales/en.lua`: every text. Copy it to add a language.

Most values can also be changed in-game under **/rentaladmin → Settings**.

Supported out of the box:

- **Vehicle keys**: qbx_vehiclekeys, p_vehiclekeys, qb-vehiclekeys, Renewed-Vehiclekeys, wasabi_carlock and qs-vehiclekeys.
- **Fuel**: ox_fuel, LegacyFuel, cdn-fuel, ps-fuel, lj-fuel, okokGasStation, lc_fuel, Renewed-Fuel and CL_fuel.

Anything else can be added in the open `bridge/` files.

## Good to know

- A server restart removes rental vehicles. The deposits of those rentals are refunded on the renter's next login (`Config.RefundOnRestart`).
- Deposits owed to players who were offline are paid on their next login.
- The server validates everything: prices, distances, money and ownership. A modified UI can only ask.
- The fonts are open-licence (SIL OFL), so the UI is free to share.
- Console commands: `rentaladmin debug` and `rentaladmin end <id>`.
