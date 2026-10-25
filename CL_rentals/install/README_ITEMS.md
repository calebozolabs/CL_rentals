# Rental contract item (optional)

Renters always see their contract on screen, and can open it again with `/rentals`. The item adds a physical copy to their inventory that they can use or hand to someone, for example a police officer. Skip this page if you don't want the item, and set `Config.Contract.item = false`.

Copy `rental_contract.png` into your inventory's image folder, then add the item for your inventory.

## ox_inventory (Qbox, or QBCore / ESX running ox_inventory)

`ox_inventory/data/items.lua`:

```lua
['rental_contract'] = {
    label = 'Rental Contract',
    weight = 10,
    stack = false,
    close = true,
    description = 'A vehicle rental agreement.',
    client = { image = 'rental_contract.png', export = 'CL_rentals.useContract' },
},
```

Image folder: `ox_inventory/web/images/`

## qb-inventory, ps-inventory and lj-inventory (QBCore)

In `qb-core/shared/items.lua`, use the format your qb-core version already uses:

```lua
rental_contract = { name = 'rental_contract', label = 'Rental Contract', weight = 10, type = 'item', image = 'rental_contract.png', unique = true, useable = true, shouldClose = true, description = 'A vehicle rental agreement.' },
```

Image folder: `qb-inventory/html/images/`

## ESX default inventory

```sql
INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES ('rental_contract', 'Rental Contract', 1);
```

The ESX inventory has no item metadata. Using the paper opens the newest contract of the player using it.
