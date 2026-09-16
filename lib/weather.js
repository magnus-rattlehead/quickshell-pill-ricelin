function coordinates(lat, lon) {
    return typeof lat === "number" && isFinite(lat) && lat >= -90 && lat <= 90
        && typeof lon === "number" && isFinite(lon) && lon >= -180 && lon <= 180;
}
function number(n, lo, hi) { return typeof n === "number" && isFinite(n) && n >= lo && n <= hi; }
function dateKey(d) {
    return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2);
}
function location(text, query) {
    try {
        var data = JSON.parse(text);
        var r = data.results && data.results[0];
        if (r && typeof r.name === "string" && coordinates(r.latitude, r.longitude))
            return { query: query, city: r.name, lat: r.latitude, lon: r.longitude };
    } catch (_) {}
    return null;
}
function cachedLocation(text, query) {
    try {
        var r = JSON.parse(text);
        if (query && r && r.query === query && typeof r.city === "string" && coordinates(r.lat, r.lon)) return r;
    } catch (_) {}
    return null;
}
function forecast(text, today) {
    try {
        var d = JSON.parse(text), c = d.current;
        if (!c || !number(c.temperature_2m, -100, 70) || !number(c.weather_code, 0, 99)
            || !number(c.relative_humidity_2m, 0, 100) || (c.is_day !== 0 && c.is_day !== 1)) return null;
        var hourly = [], daily = [], h = d.hourly, days = d.daily;
        if (h && Array.isArray(h.time) && Array.isArray(h.temperature_2m) && Array.isArray(h.weather_code)) {
            for (var i = 0; i < Math.min(24, h.time.length); i++) {
                if (typeof h.time[i] !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(h.time[i])
                    || !number(h.temperature_2m[i], -100, 70) || !number(h.weather_code[i], 0, 99)) continue;
                hourly.push({ hour: h.time[i].slice(11, 13), temp: Math.round(h.temperature_2m[i]), code: h.weather_code[i] });
            }
        }
        if (days && Array.isArray(days.time) && Array.isArray(days.weather_code)
            && Array.isArray(days.temperature_2m_max) && Array.isArray(days.relative_humidity_2m_mean)) {
            for (var j = 0; j < Math.min(8, days.time.length); j++) {
                var key = days.time[j];
                if (typeof key !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(key) || key < today
                    || !number(days.weather_code[j], 0, 99) || !number(days.temperature_2m_max[j], -100, 70)
                    || !number(days.relative_humidity_2m_mean[j], 0, 100)) continue;
                var parts = key.split('-'), date = new Date(+parts[0], +parts[1] - 1, +parts[2]);
                if (dateKey(date) !== key) continue;
                daily.push({ day: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][date.getDay()],
                    code: days.weather_code[j], temp: Math.round(days.temperature_2m_max[j]), rh: Math.round(days.relative_humidity_2m_mean[j]) });
            }
        }
        return { tempNow: Math.round(c.temperature_2m), codeNow: c.weather_code,
            humidity: Math.round(c.relative_humidity_2m), isDay: c.is_day === 1, hourly: hourly, daily: daily };
    } catch (_) { return null; }
}
