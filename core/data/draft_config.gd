class_name DraftConfig
extends RefCounted
## Zentrale Konfiguration des Relic-Drafts. EIN Schalter (MODE) entscheidet über
## den Draft-Modus; die Konstanten justieren Takt und Auswahlgröße.

enum DraftMode { SNAKE, CATCHUP }

## Standard: SNAKE = gemeinsamer Ring, Rückstand wählt zuerst → Verknappung
## (der Letzte muss nehmen, was übrig ist). Auf CATCHUP umstellen für ein eigenes
## Angebot pro Spieler mit Auswahlpuffer für Zurückliegende (kein Wegschnappen).
## Pro Stage zieht jeder Spieler GENAU EIN Relic.
const MODE := DraftMode.SNAKE

## Anzahl voller Runden zwischen zwei Stages (Draft-Auslöser).
const ROUNDS_PER_STAGE := 2

## Auswahlpuffer im CATCHUP-Modus (zusätzliche Relics im Ring, damit auch der
## letzte Spieler noch echte Auswahl hat). Im SNAKE-Modus ungenutzt.
const CHOICES_PER_PICK := 3
