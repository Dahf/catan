# Feature-Idee: Physisches Aufsammeln + Tragen statt abstraktem Lager (noch nicht umgesetzt)

## Ausgangslage
Aktuell ist Bauen rein menübasiert:
- [build_menu.gd](../build_menu.gd) zeigt eine linke Sidebar-Liste aller Bautypen mit Kosten-Chips.
- Klick auf einen Bautyp setzt `_active_def` und emittiert `EventBus.build_mode_requested`.
- [game_board.gd](../../board/game_board.gd) reagiert darauf (`_on_build_mode_requested`), der Spieler klickt dann
  auf einen Vertex/Tile in der Welt, `GameState.place_settlement()` /
  Bau-Logik prüft `GameState.can_afford()` gegen ein **abstraktes globales Lager**
  (`GameState.storage: Dictionary`, siehe [game_state.gd](../../../autoload/game_state.gd) `can_afford`/`spend`/`add_resource`).
- Ressourcen werden in [production_system.gd](../../../core/systems/production_system.gd) (`collect_resources`,
  `run_factories`) automatisch ins Lager gebucht, keine physische Repräsentation in der 3D-Welt.
- Der Spieler-Charakter ([player.gd](../../player/player.gd)) ist bereits frei begehbar (WASD, `CharacterBody3D`)
  und es gibt schon ein **Proximity-Interaktionsmuster** in `game_board.gd`
  (`_nearest_vertex`, `_interact_target`, `_unhandled_input`) — der Spieler läuft in die Nähe eines Vertex
  und interagiert per Klick. Dieses Muster lässt sich für Pickup-Interaktion wiederverwenden.

## Die neue Idee (von Silas, 2026-06-19)
Wie in echt: Ressourcen liegen als **physische Objekte auf dem Boden** in der Welt (z. B. neben Extraktoren/
auf Feldern). Der Spieler **läuft hin, hebt sie auf** (begrenzte Tragekapazität statt unendlichem Lager),
läuft zum Ziel-Vertex/Tile und **platziert das Gebäude dort**, wodurch die getragenen Ressourcen verbraucht
werden. Kein Klick-Bau aus einem Menü heraus mehr — was du bauen kannst, ergibt sich daraus, was du **gerade
in den Händen/im Inventar trägst**.

Das ersetzt/ergänzt auch das aktuelle Catan-Universe-artige Bau-UI-Konzept (Klick auf Bautyp → markierte
gültige Punkte) durch eine physische Trage-Mechanik mit limitierter Kapazität als Kernspielmechanik.

## Offene Design-Entscheidungen (für die nächste Session zu klären/entscheiden)
1. **Produktion → Pickup-Spawn**: Produzieren Extraktoren/Fabriken weiterhin passiv ins abstrakte
   `GameState.storage`, das dann periodisch physische Pickup-Objekte in der Nähe spawnt? Oder spawnen
   Gebäude direkt bei Rezept-Abschluss (`production_system.gd: run_factories`) einen Pickup statt eine
   Storage-Buchung?
2. **Ersetzt `GameState.storage` komplett?** Falls ja: `can_afford`/`spend`/`add_resource` müssen auf
   ein neues `PlayerInventory` (carry slots) umgestellt werden, nicht mehr auf ein globales Lager.
   Falls nein (Hybrid): Lager bleibt als Late-Game-Mechanik, Pickup-Tragen ist nur Early-Game/Transportweg
   vom Produzenten zur Baustelle.
3. **Tragekapazität**: feste Slot-Zahl (z. B. 1 Ressourcentyp x N Stück, oder N Slots beliebig gemischt)?
   Muss balanciert werden gegen Baukosten (z. B. Siedlung braucht 4 verschiedene Ressourcentypen gleichzeitig
   — reicht die Kapazität für einen Trip, oder sind mehrere Trips nötig?).
4. **Visuelle Repräsentation**: Pickup-Objekte in der Welt brauchen einfache Platzhalter-Meshes pro
   Ressourcentyp (Projekt hat aktuell nur prozedurale 2D-Icons in [resource_icon.gd](../components/resource_icon.gd),
   keine 3D-Modelle — analog zur Platzhalter-Kapsel in `player.gd` als Vorbild für "Platzhalter, später Asset").
   Getragene Items sollten am Charakter sichtbar sein (z. B. simpler Mesh-Slot am Rücken/Hand, ähnlich
   `$Model`-Slot in `player.gd`).
5. **Build-Menü-UI**: [build_menu.gd](../build_menu.gd) als Klick-Liste entfällt vermutlich komplett.
   Stattdessen: HUD zeigt, was der Spieler aktuell trägt (Inventar-Leiste statt/zusätzlich zur
   Ressourcen-Pille in [hud.gd](../hud.gd)), und beim Stehen an einem gültigen Vertex mit passender
   Ladung erscheint ein Bau-Prompt ("E zum Bauen" o. ä.), kein Auswahlmenü mehr nötig.
6. **Pickup-Interaktion**: neues System analog zum Vertex-Interaktionsmuster in `game_board.gd`
   (Area3D/Proximity-Check + Tasteninput), das Pickup-Objekte erkennt und ins Inventar verschiebt.

## Reihenfolge-Vorschlag für die Umsetzung
1. `PlayerInventory`-Datenstruktur (Slots/Kapazität, add/remove/has) — Daten-Layer, kein UI.
2. Pickup-Objekt-Szene (Platzhalter-Mesh + Area3D + Resource-ID) + Spawn-Punkt-Logik.
3. Pickup-Interaktion am Spieler (Proximity + Tasteninput, wiederverwendet das Vertex-Pattern aus `game_board.gd`).
4. `GameState.can_afford`/`spend` (oder neue Äquivalente) auf `PlayerInventory` umstellen.
5. Bauen am Vertex: Prüfung gegen getragenes Inventar statt globalem Lager; Build-Menü-Sidebar entfernen.
6. HUD: Ressourcenanzeige unten auf "aktuell getragen" umstellen (oder zusätzliche Inventar-Leiste).
7. Production System: entscheiden ob/wie Pickups statt/zusätzlich zu Storage-Buchungen gespawnt werden.

## Wichtig für die nächste Session
Dies ist **nur eine Idee/Spec, noch nichts implementiert**. Vor dem Start unbedingt Punkt 1–3 der offenen
Entscheidungen mit dem User klären (Hybrid vs. Vollersatz des Lagers, Tragekapazität), da das die gesamte
Spielbalance und mehrere Systeme (`production_system.gd`, `demand_system.gd`, `game_state.gd`) betrifft —
das ist kein reines UI-Styling-Thema mehr, sondern ein Gameplay-Mechanik-Umbau.
