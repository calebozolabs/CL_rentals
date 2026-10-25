fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'CL_rentals'
author 'Calebozo Labs'
version '1.0.0'
description 'CL Rentals — vehicle rental desks built in-game: categories, per-vehicle prices for 30 min / 1 h / 3 h, rental contracts, deposits and automatic re-billing'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/config_advanced.lua',
    'shared/theme.lua',
    'locales/*.lua',
    'shared/locale.lua',
    'shared/utils.lua',
}

client_scripts {
    'bridge/client.lua',
    'bridge/target.lua',
    'client/main.lua',
    'client/placement.lua',
    'client/locations.lua',
    'client/rentals.lua',
    'client/nui.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/db.lua',
    'server/main.lua',
    'server/settings.lua',
    'server/locations.lua',
    'server/rentals.lua',
    'server/admin.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/notify.css',
    'web/app.js',
    'web/desk.js',
    'web/admin.js',
    'web/notify.js',
    'web/fonts/*.woff2',
}

dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
}
