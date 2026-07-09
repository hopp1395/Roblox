# Roblox

Ein kleines Roblox-Projekt fuer ein Arcade-Fahrspiel: Du steuerst ein Auto ueber eine Strasse, weichst entgegenkommendem Verkehr aus und sammelst dabei Punkte.

## Inhalt

- `default.project.json`: Rojo-Projektdatei
- `src/ServerScriptService/RoadRampage.server.lua`: Weltaufbau, Fahrphysik, Gegenverkehr, Crash-Logik
- `src/StarterPlayer/StarterPlayerScripts/CarController.client.lua`: Eingabe, Kamera, HUD
- `src/ReplicatedStorage/Shared/GameConfig.lua`: Balancing und Konstanten

## Rojo installieren

```powershell
winget install Rojo-rbx.Rojo
```

Danach das Studio-Plugin einmalig installieren:

```powershell
rojo plugin install
```

---

## Starten

1. Rojo installieren (siehe oben)
2. In diesem Ordner `rojo serve` starten
3. Roblox Studio öffnen und das Rojo-Plugin verbinden
4. Das Projekt synchronisieren und dann `Play` drücken

## Steuerung

- `W` / `Pfeil hoch`: Beschleunigen
- `S` / `Pfeil runter`: Bremsen
- `A/D` oder `Pfeile links/rechts`: Lenken

## Spielidee

Die Strasse wird fuer jeden Spieler als eigene Spur aufgebaut. Entgegenkommende Fahrzeuge werden zufaellig vor dem Auto erzeugt und rasen dem Spieler entgegen; sie muessen umfahren werden. Fuer jedes erfolgreich passierte Fahrzeug gibt es Punkte; bei Kollision endet das Spiel mit einem Crash. Start- und Ziellinie markieren einen festen Streckenabschnitt, und am Ziel endet die Strasse sichtbar.