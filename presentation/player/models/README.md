# Character-Modelle (.glb)

Hier kommt dein Character-Modell hin. Schritte zum Einbinden:

1. **Datei ablegen:** `.glb` (oder `.gltf`) in diesen Ordner kopieren, z.B.
   `presentation/player/models/character.glb`. Godot importiert es automatisch
   und erzeugt eine PackedScene.

2. **Im Player zuweisen:** `presentation/player/player.tscn` öffnen, den Knoten
   `Player` auswählen und im Inspector beim Script-Property **`Character Model`**
   die importierte `.glb`-Szene reinziehen.
   → Beim Start blendet `player.gd` automatisch die Platzhalter-Kapsel aus und
   hängt das Modell in den `Model`-Slot.

3. **Ausrichtung & Größe:**
   - Modell sollte mit den **Füßen auf y = 0** stehen (der `Model`-Slot sitzt am
     Boden-Ursprung des CharacterBody).
   - **Blickrichtung = +Z** (Vorderseite schaut nach +Z), damit die automatische
     Drehung in Laufrichtung stimmt. Falls das Modell anders orientiert ist, im
     Import-Dock oder über eine Root-Drehung von 180° korrigieren.
   - Maßstab grob an die Kapsel anpassen (ca. 1.4 Einheiten hoch). Die
     Kollisions-Kapsel in `player.tscn` bleibt unabhängig vom Modell.

4. **Kollision bleibt unberührt:** Bewegung und Kollision laufen über die
   `CollisionShape3D` (Kapsel) des `CharacterBody3D` — das Modell ist rein visuell.

Solange kein Modell zugewiesen ist, läuft alles mit der roten Platzhalter-Kapsel
weiter.
