// Force ALL DNS lookups to use IPv4
// Loaded via -r flag before the app starts
// Fixes ENETUNREACH errors on Render when connecting to Supabase over IPv6
const dns = require('node:dns')
const originalLookup = dns.lookup

dns.lookup = function (hostname, options, callback) {
    if (typeof options === 'function') {
        callback = options
        options = { family: 4 }
    } else if (typeof options === 'number') {
        options = { family: 4 }
    } else {
        options = Object.assign({}, options, { family: 4 })
    }
    return originalLookup.call(this, hostname, options, callback)
}
