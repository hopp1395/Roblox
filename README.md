# Roblox

Ein kleines Roblox-Projekt für ein Arcade-Fahrspiel: Du steuerst ein Auto über eine Straße und sammelst Punkte, indem du zufällig platzierte Gegenstände umfährst.

## Inhalt

- `default.project.json`: Rojo-Projektdatei
- `src/ServerScriptService/RoadRampage.server.lua`: Weltaufbau, Fahrphysik, Hindernisse, Score
- `src/StarterPlayer/StarterPlayerScripts/CarController.client.lua`: Eingabe, Kamera, HUD
- `src/ReplicatedStorage/Shared/GameConfig.lua`: Balancing und Konstanten

## Starten

1. Rojo installieren
2. In diesem Ordner `rojo serve` starten
3. Roblox Studio öffnen und das Rojo-Plugin verbinden
4. Das Projekt synchronisieren und dann `Play` drücken

## Steuerung

- `W` / `Pfeil hoch`: Beschleunigen
- `S` / `Pfeil runter`: Bremsen
- `A/D` oder `Pfeile links/rechts`: Lenken

## Spielidee

Die Straße wird für jeden Spieler als eigene Spur aufgebaut. Hindernisse werden zufällig vor dem Auto erzeugt. Start- und Ziellinie markieren den Abschnitt der Strecke. Für jedes umgefahrene Objekt steigt der Score.