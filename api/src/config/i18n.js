const i18n = require('i18n');
const path = require('path');

i18n.configure({
    locales: ['en', 'tr'],
    directory: path.join(__dirname, '..', 'locales'),
    defaultLocale: 'en',
    header: 'accept-language',
    autoReload: true,
    syncFiles: true,
    cookie: 'lang',
    objectNotation: true,
});

module.exports = i18n;
