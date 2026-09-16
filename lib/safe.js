// Serialization at process/IPC boundaries. Arguments are data, never code.
function shellQuote(value) {
    var s = String(value);
    if (s.indexOf("\0") !== -1) throw new Error("NUL in process argument");
    return "'" + s.replace(/'/g, "'\\''") + "'";
}

function luaQuote(value) {
    return '"' + String(value).replace(/[\\"\x00-\x1f\x7f]/g, function(c) {
        if (c === '\\') return '\\\\';
        if (c === '"') return '\\"';
        return '\\' + ('00' + c.charCodeAt(0)).slice(-3);
    }) + '"';
}

function commandString(argv) {
    return argv.map(shellQuote).join(" ");
}

function workspaceId(value) {
    var n = Number(value);
    return Number.isSafeInteger(n) && n > 0 ? n : 0;
}

function windowAddress(value) {
    return typeof value === "string" && /^0x[0-9a-fA-F]+$/.test(value) ? value : "";
}

function usageFromJson(text) {
    var out = Object.create(null);
    try {
        var data = JSON.parse(text);
        if (!data || typeof data !== "object" || Array.isArray(data)) return out;
        Object.keys(data).forEach(function(k) {
            var n = data[k];
            if (typeof n === "number" && Number.isSafeInteger(n) && n >= 0) out[k] = n;
        });
    } catch (_) {}
    return out;
}
