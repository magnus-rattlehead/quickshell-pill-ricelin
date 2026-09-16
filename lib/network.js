// nmcli --terse escapes both delimiters and backslashes.
function fields(line) {
    var out = [], value = "";
    for (var i = 0; i < line.length; i++) {
        var c = line[i];
        if (c === "\\") {
            if (++i >= line.length || (line[i] !== ":" && line[i] !== "\\")) return null;
            value += line[i];
        } else if (c === ":") {
            out.push(value);
            value = "";
        } else value += c;
    }
    out.push(value);
    return out;
}

function uuid(value) {
    return typeof value === "string" && /^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$/.test(value);
}

function mac(value) {
    return typeof value === "string" && /^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/.test(value);
}

function lineInput(value) {
    return typeof value === "string" && value.length > 0 && !/[\x00\r\n]/.test(value);
}
