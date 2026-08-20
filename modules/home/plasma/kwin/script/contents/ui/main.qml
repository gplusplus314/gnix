import QtQuick
import org.kde.kwin

Item {
    Component.onCompleted: {
        function wire(handler, idx) {
            handler.activated.connect(function() {
                var desktops = Workspace.desktops;
                if (idx >= desktops.length) return;
                var target = desktops[idx];
                var win = Workspace.activeWindow;
                if (win) win.desktops = [target];
                Workspace.currentDesktop = target;
            });
        }
        wire(h1, 0); wire(h2, 1); wire(h3, 2); wire(h4, 3); wire(h5, 4);
        wire(h6, 5); wire(h7, 6); wire(h8, 7); wire(h9, 8); wire(h10, 9);
    }

    // Bindings are declared in plasma/default.nix under
    // programs.plasma.shortcuts ("kwin". "move-to-desktop-N"), which writes
    // them to kglobalshortcutsrc.
    ShortcutHandler { id: h1;  name: "move-to-desktop-1";  text: "gnix: Move to Desktop 1 and Follow" }
    ShortcutHandler { id: h2;  name: "move-to-desktop-2";  text: "gnix: Move to Desktop 2 and Follow" }
    ShortcutHandler { id: h3;  name: "move-to-desktop-3";  text: "gnix: Move to Desktop 3 and Follow" }
    ShortcutHandler { id: h4;  name: "move-to-desktop-4";  text: "gnix: Move to Desktop 4 and Follow" }
    ShortcutHandler { id: h5;  name: "move-to-desktop-5";  text: "gnix: Move to Desktop 5 and Follow" }
    ShortcutHandler { id: h6;  name: "move-to-desktop-6";  text: "gnix: Move to Desktop 6 and Follow" }
    ShortcutHandler { id: h7;  name: "move-to-desktop-7";  text: "gnix: Move to Desktop 7 and Follow" }
    ShortcutHandler { id: h8;  name: "move-to-desktop-8";  text: "gnix: Move to Desktop 8 and Follow" }
    ShortcutHandler { id: h9;  name: "move-to-desktop-9";  text: "gnix: Move to Desktop 9 and Follow" }
    ShortcutHandler { id: h10; name: "move-to-desktop-10"; text: "gnix: Move to Desktop 10 and Follow" }
}
