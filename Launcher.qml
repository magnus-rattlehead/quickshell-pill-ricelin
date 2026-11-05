pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "Singletons"

SearchSurface {
    id: root
    leftPadding: 11 * s; rightPadding: 11 * s
    readonly property var allEntries: DesktopEntries.applications.values.filter(
        entry => entry && !entry.noDisplay && !entry.runInTerminal)
    results: {
        var needle = query.trim().toLowerCase();
        return allEntries.filter(entry => [entry.name, entry.genericName, entry.comment]
            .some(text => (text || "").toLowerCase().includes(needle)))
            .sort((a, b) => a.name.localeCompare(b.name));
    }
    onActivated: (entry) => { entry.execute(); root.requestClose(); }
    search.placeholderText: "Search apps"
    counterText: results.length + " / " + allEntries.length
    emptyText: query.length ? "No matches" : "No apps found"
    list.spacing: 5 * s

    list.delegate: ResultDelegate {
        id: appRow
        height: 38 * root.s
        readonly property var entry: root.results[index]
        horizontalPadding: 11 * root.s
        spacing: 10 * root.s
        text: entry ? entry.name : ""
        font.pixelSize: 13 * root.s
        font.weight: selected ? Font.DemiBold : Font.Normal
        palette.text: Theme.text
        icon.source: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
        icon.width: 22 * root.s
        icon.height: 22 * root.s
        icon.color: "transparent"
    }
}
