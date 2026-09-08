# Run doc — AURA FARM (Roblox pilot)

Proyecto independiente: `C:\Users\Silvia\Desktop\repos\aura-farm` (repo git
propio, movido fuera de `gogame` el 2026-09-08). Juego de Roblox: farmear
aura con poses, multitud NPC, duelos juzgados best-of-5 con robo de aura.

## Layout

- `src/shared` — Config, Remotes, Util (comunes server/client).
- `src/server` — 13 servicios Luau (Map, Data, Aura, Crowd, Pose, PoseAnimator,
  Judge, Duel, Training, Leaderboard, Monetization, CapturePrompt) +
  `init.server.lua` (bootstrap en orden fijo).
- `src/client` — Hud, PoseController, ShopUi, DuelUi, TrainingUi, ChallengeUi,
  MogFx.
- `tools/` — rojo 7.7.0 + luau/luau-analyze (descargados, NO globales),
  instalador de Studio usado una vez.
- `tests/` — harness Luau que ejecuta los módulos REALES del juego bajo un
  entorno Roblox mockeado (reloj manual para duelos/cooldowns).

## Comandos (desde la raíz del proyecto)

- **Tests (14/14 verde)**:
  ```
  node tests/bundle.js
  tools/luau/luau.exe tests/run_tests.lua
  ```
  (bundle.js regenera `tests/bundle_data.luau` desde `src/` — correrlo tras
  editar cualquier módulo).
- **Rebuild del place**: doble clic a `build.bat`, o
  `tools/rojo/rojo.exe build default.project.json -o AuraFarmPilot.rbxl`.
- **Analyzer** (ruido esperado: todos los globals de Roblox salen como
  "Unknown"; filtrar con `grep -iE "syntax|shadow|never"`):
  `tools/luau/luau-analyze.exe src`.

## Probar en Studio

Doble clic a `AuraFarmPilot.rbxl` → Studio → **Play (F5)**. P = pose wheel,
B = tienda, M = MOG/duelo, pad verde TRAIN 🥋 = ronda en solitario. Duelo en
solitario: Test → Clients and Servers → 2 Players. Para persistencia
DataStore: Game Settings → Security → "Studio Access to API Services".

## Pasada "poses visibles + NPCs + MOG en solitario" (2026-09-08, noche)

La usuaria reportó: no se ven las poses, hay que crearlas, y que se vean los
NPCs; el MOG solo cuando haya unioplayer (2 players vendrá después).

- **Poses invisibles (causa raíz)**: PoseAnimator multiplicaba `C0 * Angles`
  con los signos de Z invertidos — ambos brazos giraban HACIA el torso
  (clipping, parecía que no pasaba nada) y un re-pose acumulaba el giro
  (double-apply). **v2**: C0 ABSOLUTO desde el pivote de reposo del joint
  (rest cacheado la primera vez), signos correctos (Z negativo sube el brazo
  derecho, positivo el izquierdo), codos añadidos a moai/kata/modelwalk,
  transiciones con TweenService (0.25s Quad). Alias R6 (Right/Left/Head/
  Torso→Torso/Root) para avatares R6. Test de regresión nuevo verifica que
  el C0 rota de verdad y que re-posar no deriva.
- **NPCs medio enterrados (causa raíz)**: el torso (2 de alto) se colocaba con
  su CENTRO en el suelo → 1 stud de piernas bajo tierra. Fix: torso a
  `groundY + piernas + mitad del torso`. Además: nametags (BillboardGui
  AlwaysOnTop) para TODOS los NPCs.
- **MOG en solitario**: 3 rivales NPC (Config.NPC_RIVALS: Tomás el Faker
  tier1/100, Luna Hype tier3/400, GIGACHAD tier4/1200) junto al arena con
  tag "MOG ME ⚔️". M → ChallengeUi los lista con bounty; RequestNpcDuel
  (remote nuevo) → DuelService modore BOT: mismo best-of-5 juzgado, el bot
  elige pose al buzzer limitada por maxTier del rival, 35% de acertar el
  timing, sin robo de aura — el premio es el BOUNTY (pago único al ganar).
  Empate a 5 rondas vs bot = gana el jugador. Showdown 6s antes de volver.
  El rival se teletransporta al arena (teleportRival recoloca TODOS los
  limbs — los rivales no corren el loop de animación) y vuelve a su sitio
  al terminar. OJO bug arreglado: rondas empatadas puntuaban al bot
  (`winner == playerB` con playerB nil era true) y el majoriy-win se robaba
  aura a sí mismo.
- **Harness de tests**: CFrame con matriz de rotación real (fromEulerAnglesXYZ
  estilo Roblox), TweenService stub (aplica el valor final), IsA en el mock
  Instance, C0/C1/Transform por defecto, players con .Parent (como en real).
- **16/16 tests verde** (antes 14), analyzer sin avisos nuevos, place
  reconstruido (AuraFarmPilot.rbxl 56 KB).
- Pendiente para la usuaria: abrir el .rbxl en Studio y Probar — las poses
  ahora se ven (T-pose brazos fuera, wave saludando arriba, sigma V final),
  los NPCs caminan SOBRE el suelo con nombre, y M muestra a los 3 bots.
- **5 poses míticas nuevas** (misma pasada): zombie 🧟 (free), salute 🫡 (750),
  dab 🕺 (2500), double biceps 💪 (2500) y SIGMA Lean 🕴️ (2ª mítica, 15000,
  lean 22º hacia atrás con Root). Total 11 poses — el bot GIGACHAD puede
  soltar dabs en los duelos. UI/wheel/shop/pickers/pools: cero cambios
  (todo lee Config.POSES).

## Pasada "aura HUD instantáneo" (2026-09-08, noche)

La usuaria compró una pose de 2000 y el contador del HUD tardó mucho en bajar
(el dinero SÍ se descontaba, solo no se veía).

- **Causa raíz**: comprar NUNCA disparaba `AuraChanged` (el HUD solo escucha
  ese remote) y el contador solo se actualizaba al GANAR aura (tick de
  multitud, bounty, training). El panel de personas (leaderstats) sí se
  actualizaba vía el poll de 2s de AuraService → por eso ahí se veía 4.221.
- **Fix doble**:
  1. `DataService.addAura/spendAura` ahora sincronizan `leaderstats.Aura`
     en CADA mutación (antes cada llamador lo hacía a mano y el buy path se
     olvidó — pattern bug clásico). Test nuevo lo cubre.
  2. `PoseService.onBuyPose` dispara `AuraChanged(newAura, -cost)` al instante
     → el HUD muestra la compra en el momento.
- **Hud.client**: `AuraChanged` con delta negativo muestra `"-2K 🛒"` en vez
  de un falso earn; y el contador grande también escucha
  `leaderstats.Aura.Changed` como red de seguridad.
- **17/17 tests verde** (antes 16; nuevo: compra refleja leaderstats +
  AuraChanged negativo al instante), analyzer sin avisos nuevos, place
  reconstruido.

## Pasada "stale place" (2026-09-09, 0:40)

La usuaria veía el mundo BLANCO sin texturas y el HUD con la barra vieja de 4
poses → estaba jugando un place VIEJO: su sesión de Studio abría el .rbxl
cargado a las 19:21, pero los rebuilds de Rojo (último 23:57) NO hot-reloadan
en un Studio ya abierto. Además el diálogo de Recuperación Automática puede
restaurar un snapshot aún más viejo (Omitir = cargar el fresh de disco).

- **Regla de oro**: tras CUALQUIER `rojo build`, cerrar Studio y reabrir el
  .rbxl (o usar el diálogo de recuperación con Omitir). El .rbxl de disco
  siempre manda; el Studio abierto no se entera.
- Reabierta la sesión: kill del Studio viejo (pid), borrado .rbxl.lock,
  relanzado, Omitir en Recuperación, Continuar en "Migración de tecnología
  de iluminación" (sale en places viejos; conviene aceptarlo).
- **Kit de clicks, lección nueva (DPI)**: con pantalla 2560×1440 al 150%,
  los rects de UIA son PÍXELES FÍSICOS; un proceso PowerShell DPI-unaware
  virtualiza mouse_event/SetCursorPos (×1.5) y el click cae en la esquina.
  `tools/clickplay-dpi.ps1` nuevo llama SetProcessDPIAware antes de
  realclick — pero dentro de una sesión ya arrancada no siempre pega; si
  falla, ejecutarlo desde un shell fresco. F5 por keybd_event/SendKeys
  TAMBIÉN falló esta vez (sin modal que lo bloquee — sospecha: focus interno
  del dock). Pendiente: investigar el focus del viewport antes de F5.
- Mientras tanto: para Play, la usuaria pulsa F5/Ejecutar a mano (1 tecla).

## Pasada "UX P/B/M + detector de place viejo" (2026-09-09, 1:00)

Feedback "solo van T y B": los logs lo confirmaron — la sesión segía siendo
la vieja (6 poses, sin bots; la rueda nueva tiene 11). Aun así la rueda P
tenía problemas reales con 11 poses:

- **Rueda P rediseñada**: panel 340×480 con ScrollingFrame (11 botones caben,
  scroll si crece), orden por TIER descendente (no alfabético — se lee como
  progresión), botones cortos "🔒2000" (antes el texto desbordaba).
- **Click en pose bloqueada YA NO cierra la rueda en silencio**: footer
  muestra "🔒 X costs N aura — press B to buy it!" 2.5s. Antes parecía "este
  botón no va". Necesitó tracked `ownedPoses` client-side (SyncUnlocked +
  PoseUnlocked lo alimentan; defaults tpose/wave).
- **Detector de place viejo**: Config.VERSION (0.6.0) + stamp "v0.6.0 · AURA
  FARM pilot" abajo-izquierda del HUD. Si no lo ves → sesión stale, reabrir.
- Hint de controles resaltado (píldora con fondo, texto dorado, "bots!").
- 17/17 verde, place rebuilt (01:00), Studio relanzado en limpio.
- Regla para la usuaria: tras cada rebuild, CERRAR y REABRIR Studio. La
  versión v0.6.0 debe verse abajo a la izquierda; si no, es sesión vieja.

## Pasada "rueda solo con poses owned" (2026-09-09, 1:05, v0.6.1)

Feedback: "en la rueda no deberían salir las que no tienes" — correcto, y
concuerda con el patrón "parece que no funcionan": una pared de botones
bloqueados se lee como botones rotos.

- La rueda P ahora lista SOLO poses owned (los candados viven en la tienda,
  que ya los lista con su BUY). Se reconstruye al vuelo cuando llega
  SyncUnlocked (join) o PoseUnlocked (compra) → compras en la tienda y la
  pose aparece en la rueda sin reabrir nada. Fondo verde = gratis, violeta =
  comprada. Si no tienes ninguna: "no poses yet — press B to buy".
- DuelUi y TrainingUi YA filtraban por owned (verificado) — solo la rueda
  mostraba todo.
- 17/17 verde, rebuild v0.6.1, Studio relanzado (sin diálogo de recuperación
  esta vez).

## Estado (2026-09-08, 17:30)

- 14/14 tests de integración VERDE (boot, spots, join/sync, pose+aura,
  bloqueos, cooldown, tienda ok/fallo, duelo best-of-5 completo por remotes
  con conservación de aura + floor newbie, rematch post-cleanup, training,
  save/load + segundo save, multitud).
- Bug de economía arreglado: los duelantes ya NO ganan aura de la multitud
  (atributo `InDuel` que marca DuelService; evita ciclo de requires).
- `AuraFarmPilot.rbxl` reconstruido y abierto en Studio.
- Deuda conocida: poses procedurales (no animaciones reales — drop-in vía
  `Config.POSE_ANIMATIONS`), receipts de compras en memoria (re-grant tras
  restart, aceptable en piloto), sin UI de invitación entrante con temporizador
  visible (DuelUi la dibuja al recibir DuelInvited), sin git commit inicial
  (el repo está inicializado pero vacío — primer commit pendiente).

## Lecciones técnicas (runtime standalone luau.exe)

- `io` NO existe en el CLI (por eso el bundle vía Node); `_G` y `os` son
  readonly (instalar globals vía chunk de `loadstring`); `require("./x")`
  resuelve a `x.luau`; los globals no cruzan chunks del CLI (env inyectado
  como parámetros de función vía header compilado).
- Trampa Lua clásica: self-referencia dentro del constructor de una `local`
  ve el GLOBAL (nil) — usar una única forward declaration.
- `CFrame.new(x,y,z)` NO existe (solo 0/1/2 args, Vector3s).
- En Studio el jugador puede entrar antes del require del script de servidor →
  TODO servicio con PlayerAdded necesita backfill en `init()`.

## Historia (migrada del run doc de gogame)

- Pilot v0.1: plaza+arena por código (MapService), multitud NPC con decaimiento
  de atención (CrowdService), aura server-authoritative con leaderstats,
  tienda de poses, duelos best-of-5 con 3 jueces NPC y stamps 🔥/mid/💀, MOG FX
  (confeti 💀, orbs, camera shake), robo del 15% con cap y protección newbies,
  leaderboard OrderedDataStore all-time + weekly.
- Pasada "implement in full": PoseAnimator server-side (poses visibles para
  todos), bonus de timing de jueces, monetización completa (4 passes + 3
  productos, receipts con dedupe), VIP rooftop 2.5x, MOGGED billboard 60s,
  multitud con cuerpos completos y animación procedural.
- Pasada "crash sweep": CFrame.new inválido en pad VIP, carrera de PlayerAdded
  (backfill en init), head.Shape en MeshPart R15, contador de filas de la
  board semanal, picks tardíos que farmeaban bonus de timing, cleanup de
  duelos, BindToClose sin API, CapturePromptService protegido.
- Features nuevas: ChallengeUi (tecla M — antes los duelos eran inalcanzables
  desde UI) y TrainingService/TrainingUi (pad verde, ronda juzgada real contra
  bot, +10 aura × tier).
- Diseño y protocolo de playtest (10 personas, encuesta de 5 preguntas) en
  `DESIGN.md`; guía de montaje y checklist en `README-PILOT.md`.

## Pasada "live Studio smoke test" (2026-09-08, tarde)

- **Primera ejecución REAL del juego en Studio, con evidencia**: 13/13 checks
  [SMOKE] PASS en sesión Play en vivo (log `0.737...8A10C_last.log`), CERO
  errores de script. El avatar real de la usuaria (FicusTus, 621002908) entró,
  spawneó, posó y ganó 535 aura en 5 s con la multitud NPC (12 NPCs).
- **Evidencia**: `TEST-REPORT.md` + `evidence/` (smoke-final.mp4 70s verde,
  smoke-live.mp4, 3 vídeos de depuración, 3 frames PNG).
- **Smoke test**: `tests/studio/SmokeTest.server.lua` (pilot-only, fuera de
  src/), cableado al build vía `default.project.json`
  (ServerScriptService.SmokeTest → $path). QUITAR esa entrada del tree para
  builds de producción. Server-side: mundo + llamadas directas a servicios
  (la capa de remotes ya está probada por la suite Luau 14/14).
- **Kit de automatización Studio** (en `tools/`): winrect.ps1 (SetForeground +
  SendKeys F5 = Play), movewin.ps1 (ventana al monitor primario — ¡estaba en
  un segundo monitor y la grabación no la veía!), clickbtn/clickid/realclick.ps1
  (UI Automation: diálogos y cinta), dumpui/listwins.ps1, ffmpeg gdigrab para
  vídeo (ffmpeg ya estaba en PATH).
- Lecciones: `Players.LocalPlayer` NO existe en server scripts (usar
  GetPlayers()); los Motor6D de R15 viven DENTRO de los limbs
  (FindFirstChild recursivo); Studio en español: Play = "Ejecutar"
  (AutomationId `multiLineRunButtonContainer.commandBarRunButton`), diálogos de
  recuperación tras taskkill (Continuar/Abrir/Omitir/Eliminar — Omitir = cargar
  el build fresco); invocar InvokePattern de Qt NO funciona — click real con
  mouse_event sí; el log de Studio en vivo:
  `%LOCALAPPDATA%/Roblox/logs/*_last.log` (líneas [SMOKE] en FLog::CreatorOutput).
- Fallos del run 1 (11/13) eran bugs del TEST, no del juego: R15 motor anidado
  y aserción exacta de 500 cuando la multitud pagó 533.
- **Pendiente para producción**: quitar SmokeTest del project.json; duelo en
  vivo requiere 2 clientes (Test → Clients and Servers → 2 Players).

## Pasada "texturas" (2026-09-08, tarde — tras feedback visual de la usuaria)

- La usuaria reportó "no se ven texturas": TODO era Plastic blanco y el mundo
  eran losas flotando sobre el cielo (sin suelo).
- **MapService**: añadido `buildGround` (512×512 Grass en y=-0.5) + Material por
  pieza: Marble (fuente), Slate (arena), WoodPlanks/Wood (jueces), Neon (escenario
  y VipPad), Concrete (muro graffiti), Metal/DiamondPlate (rooftop/escalera),
  Cobblestone (spawn). 12 materiales en total.
- **CrowdService**: NPCs con SmoothPlastic (no clay mate).
- Re-validado: 14/14 suite + rebuild + sesión Studio en vivo 13/13 [SMOKE] PASS
  (log ...46A23_last.log). Evidencia visual: evidence/textured-map.mp4 +
  textured-gameplay.png / textured-plaza.png.
- NOTA: el SmokeTest corre en cada Play (inofensivo, imprime [SMOKE]); quitar
  `SmokeTest` de default.project.json antes de publicar el juego real.

## Pasada "pad touch + client pick live" (2026-09-08, 17:21)

- ClientProbe.client.lua (pilot-only, en StarterPlayerScripts): suelta el
  avatar real en el pad a los 10s y dispara TrainingPick 1.5s tras cada
  TrainingRound. MISMA sesion: PAD TOUCH open x2 (re-entry tras cooldown ok),
  pick aceptado (locked a 6.5s left), resultados juzgados (1.6 vs 6.6),
  SMOKE 13/13, 0 errores. Video pad-pick-proof.mp4 + frame pad-moment.png.
- PRODUCCION: quitar SmokeTest Y ClientProbe de default.project.json.

## 2026-09-09 — Capa human-usability probada en su superficie real
- Guía contra código: bindings reales son P/B/M/T (ContextActionService). La guía documentaba Q-stop INEXISTENTE → corregida (parar = P otra vez y re-tocar tu pose actual, que es lo que hace PoseController). M documentado también con duelos NPC (RequestNpcDuel existe).
- TEST.bat ejecutado de verdad (cmd //c, path absoluto): 17/17 PASS + ALL GREEN + "Presione una tecla para continuar" (pausa humana verificada). Ojo: invocarlo con ruta RELATIVA desde bash falla ("no se reconoce") — desde Explorer doble clic funciona (ShellExecute resuelve el cwd).
- .url del Escritorio lanzado vía `start` (equivalente a doble clic): mató Studio viejo (PID 30048), rebuildeó (build 00:51:27), abrió sesión nueva (PID 27136, log 00:51:41) cuya command line carga AuraFarmPilot.rbxl — la cadena completa del humano probada.
- Pendiente conocido: el Play AUTOMATIZADO en esta sesión no llegó (F5 sintético y UIA-invoke no afectan a esta build de Qt con DPI mixto; UIA devuelve rects viejos tras mover la ventana). No es defecto del juego: pulsar Play es el paso que hace el humano (guía paso 2). Las sesiones previas con Play real dieron 13/13.

## 2026-09-09 — Repo listo para el primer commit
- Eliminados restos: fixguide.py (raíz) y 6 probe*.lua (tools/luau) de sesiones de debugging.
- .gitignore con política real: fuera AuraFarmPilot.rbxl (regenerable por PLAY.bat), *.rbxl.lock, tests/bundle_data.luau (lo genera bundle.js), evidence/ (57 MB de vídeos/frames regenerables), tools/*.zip y RobloxStudioInstaller.exe (duplican lo necesario). DENTRO del repo: tools/rojo/luau exes + scripts del kit (PLAY.bat y TEST.bat los necesitan — la política antigua tools/ entero rompía un clone fresco), src, tests, docs y bats.
- Re-verificado tras la limpieza: TEST.bat 17/17 ALL GREEN, rojo build OK, git status solo con intencionales. SmokeTest sigue en default.project.json (quitar antes de publicar).
- COMMIT BASELINE: root commit en main con todo el estado auditado (56 archivos). Forma elegida: commit único en main (la alternativa root-commit vacío + rama feature exigía cambiar de rama, vetado). Nada pushed: el paso siguiente es dueño del remoto y del PR.
- ENTREGA: repo privado github.com/SilviaTormo/aura-farm (gh auth SilviaTormo). Forma: main = e01e2f0 (raíz chore vacía) + pilot-baseline = b30b7c6 (baseline completa, árbol idéntico al commit auditado 687a758). PR #1 abierto base main ← head pilot-baseline (diff = 56 archivos). Nada mergeado; checks y merge son del siguiente paso.
- CI: workflow offline-tests anadido (mismos comandos que TEST.bat, windows-latest). Los runs mueren con "account is locked due to a billing issue": bloqueo de facturacion en la cuenta GitHub, solo la propietaria puede levantarlo en github.com/settings/billing. El repo paso a PUBLICO para descartar el gate del free plan; sigue bloqueado a nivel cuenta.
