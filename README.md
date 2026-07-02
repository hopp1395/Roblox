# Roblox

Ein kleines Roblox-Projekt fuer ein Arcade-Fahrspiel mit klarer Mission: Du steuerst einen Evakuierungs-Racer durch eine ausfallende Neon-Stadt, bringst einen Energiekern zum Evakuierungstor, weichst Truemmern aus und sammelst Versorgungspunkte.

## Inhalt

- `default.project.json`: Rojo-Projektdatei
- `src/ServerScriptService/RoadRampage.server.lua`: Weltaufbau, Fahrphysik, Hindernisse, Crash-Logik
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

Die Strasse wird fuer jeden Spieler als eigene Evakuierungsspur aufgebaut. Die Strecke fuehrt durch mehrere Stadtsektoren mit eigenem Look: Neon Quarter, Transit Ring, Industrial Belt und den finalen Evac Corridor. Auf dem Weg liegen Quarantaene-Barrieren, Fracht und Stromknoten als Hindernisse. Fuer jede erfolgreich passierte Gefahr gibt es Punkte; Akkuzellen und Reparaturkits liefern Bonuspunkte. Start-Hub, Missionsbeschilderung und Evakuierungstor geben der Fahrt einen klaren Kontext, und bei einem Zusammenstoss ist der Konvoi verloren.