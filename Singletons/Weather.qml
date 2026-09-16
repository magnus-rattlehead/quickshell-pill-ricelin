pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/weather.js" as Parse

Singleton {
    id: root
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ricelin"
    readonly property string query: Flags.weatherCity.trim()
    property int tempNow: 0
    property int codeNow: 0
    property int humidity: 0
    property bool isDay: true
    property string city: ""
    property var hourly: []
    property var daily: []
    property bool ready: false
    property string status: "Set a city for weather"
    property real lat: 0
    property real lon: 0
    property bool located: false
    property int revision: 0

    function glyphFor(code, day) {
        if (code === 0)
            return day ? "sun" : "moon";
        if (code <= 3)
            return "cloud";
        if (code === 45 || code === 48)
            return "cloud-fog";
        if (code >= 95)
            return "cloud-lightning";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "cloud-snow";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "cloud-rain";
        return "cloud";
    }


    function labelFor(code) {
        if (code === 0)
            return "Clear";
        if (code <= 3)
            return "Cloudy";
        if (code === 45 || code === 48)
            return "Fog";
        if (code >= 95)
            return "Thunder";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "Snow";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "Rain";
        return "Cloudy";
    }


    function setLocation(loc) {
        city = loc.city;
        lat = loc.lat;
        lon = loc.lon;
        located = true;
    }

    function resetLocation() {
        revision++;
        ready = false;
        located = false;
        city = "";
        hourly = [];
        daily = [];
        status = query ? "Loading weather…" : "Set a city for weather";
        refresh();
    }

    function refresh() {
        if (!query || geoProc.running || wxProc.running) return;
        if (located) {
            wxProc.revision = revision;
            wxProc.running = true;
        } else {
            geoProc.revision = revision;
            geoProc.requestQuery = query;
            status = "Finding city…";
            geoProc.running = true;
        }
    }

    onQueryChanged: resetLocation()
    Component.onCompleted: {
        var cached = Parse.cachedLocation(locCache.text(), query);
        if (cached) setLocation(cached);
        refresh();
    }

    FileView {
        id: locCache
        path: root.cacheDir + "/weather-loc.json"
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: geoProc
        property int revision: -1
        property string requestQuery: ""
        command: ["curl", "-q", "-fsS", "--max-time", "8", "--max-filesize", "1048576", "-G",
            "https://geocoding-api.open-meteo.com/v1/search",
            "--data-urlencode", "name=" + requestQuery, "--data-urlencode", "count=1"]
        stdout: StdioCollector { id: geoOutput }
        stderr: StdioCollector {}
        onExited: (code) => {
            if (revision !== root.revision) { Qt.callLater(root.refresh); return; }
            var loc = code === 0 ? Parse.location(geoOutput.text, requestQuery) : null;
            if (!loc) { root.status = code === 0 ? "City not found — edit city" : "Weather unavailable — retry later"; return; }
            root.setLocation(loc);
            locCache.setText(JSON.stringify(loc));
            root.status = "Loading weather…";
            Qt.callLater(root.refresh);
        }
    }

    Process {
        id: wxProc
        property int revision: -1
        command: ["curl", "-q", "-fsS", "--max-time", "10", "--max-filesize", "1048576",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon
            + "&current=temperature_2m,weather_code,is_day,relative_humidity_2m"
            + "&hourly=temperature_2m,weather_code&forecast_hours=24"
            + "&daily=weather_code,temperature_2m_max,relative_humidity_2m_mean&forecast_days=4&past_days=0&timezone=auto"]
        stdout: StdioCollector { id: weatherOutput }
        stderr: StdioCollector {}
        onExited: (code) => {
            if (revision !== root.revision) { Qt.callLater(root.refresh); return; }
            var forecast = code === 0 ? Parse.forecast(weatherOutput.text, Parse.dateKey(new Date())) : null;
            if (!forecast) {
                root.ready = false;
                root.hourly = [];
                root.daily = [];
                root.status = "Weather unavailable — retry later";
                return;
            }
            root.tempNow = forecast.tempNow;
            root.codeNow = forecast.codeNow;
            root.humidity = forecast.humidity;
            root.isDay = forecast.isDay;
            root.hourly = forecast.hourly;
            root.daily = forecast.daily;
            root.ready = true;
            root.status = "";
        }
    }
    Timer { interval: 1200000; running: root.query.length > 0; repeat: true; onTriggered: root.refresh() }
}
