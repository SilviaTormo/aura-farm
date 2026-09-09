# 🎮 CÓMO JUGAR — Guía para personas

## La regla de oro (solo esto hay que saber)

> **Para jugar SIEMPRE haz doble clic en "JUGAR AURA FARM" del Escritorio.**
> Nunca abras `AuraFarmPilot.rbxl` directamente.

¿Por qué? Porque Studio no recarga el archivo si ya lo tenía abierto:
seguirías viendo un **mapa viejo, blanco y sin suelo**, aunque el juego
esté corregido mil veces. El acceso directo cierra lo viejo, construye
el nuevo y abre la versión buena. Siempre.

## Tu rutina completa (30 segundos)

1. Doble clic en **JUGAR AURA FARM** (Escritorio).
   - Se abre una ventana negra, hace cosas, y se abre Studio. Todo normal.
2. En Studio, pulsa **PLAY** (el botón ▶ azul de arriba, o F5).
   - Si sale "Roblox crashed / Seguro que quieres continuar": pulsa **Omitir**.
3. Ya estás dentro. Usa:
   | Tecla | Qué hace |
   |-------|----------|
   | **P** | Posar: los NPCs te vitorean y ganas aura. Para DEJAR de posar: P otra vez y vuelve a tocar tu pose actual |
   | **T** | Entrenar (ronda de poses con jurado, también vale pisar el pad verde TRAIN) |
   | **1-9** | Durante el entrenamiento: elegir la pose numerada (cada botón muestra su número) |
   | **B** | Tienda (comprar poses nuevas con aura) |
   | **M** | MOG / duelos (contra otros jugadores O contra NPCs; para jugar solo) |
   | **P** (otra vez) | Cerrar la rueda de poses |

4. Para salir de la partida: **ESC → Stop** (o Mayús+F5).

## ¿Quieres probar el modo 2 jugadores (duelos)?

En Studio: pestaña **TEST (Prueba)** → sección **Clients and Servers** →
elige **2 Players** → **Start**. Se abren dos ventanas jugando en el mismo
servidor: desafía a tu otro yo con **M**.

## Si algo va mal

- **Veo el mapa blanco otra vez** → cerraste Studio y abriste el .rbxl a mano.
  Vuelve al doble clic de **JUGAR AURA FARM**. Solucionado.
- **Algo no funciona dentro del juego** → pulsa **F9** (consola), haz captura
  de lo que salga en rojo y pásasela a la IA.
- **La ventana negra dice "LA CONSTRUCCIÓN FALLO"** → captura y a la IA.

## Para la IA (no para humanos)

- `PLAY.bat` = cerrar Studio + `rojo build` + abrir el .rbxl nuevo.
- `TEST.bat` = suite offline (node tests/bundle.js + luau tests/run_tests.lua).
- Los prints `[SMOKE]`/`[TRAIN]`/`[PROBE]` en la salida van al log de Studio
  (`%LOCALAPPDATA%/Roblox/logs/*_last.log`): SmokeTest y ClientProbe son
  piloto-único y hay que quitarlos antes de publicar.
