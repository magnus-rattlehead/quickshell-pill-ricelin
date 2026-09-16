.pragma library

// Walk the visual tree so feedback belongs to the pill on this monitor.
function trigger(item, click) {
    for (var owner = item; owner; owner = owner.parent) {
        if (typeof owner.triggerGlitch === "function") {
            owner.triggerGlitch(click);
            return;
        }
    }
}

function hover(item) { trigger(item, false); }
function click(item) { trigger(item, true); }
