# FASE 8 — Steam 4-client acceptance checklist

Este gate valida el MVP completo sobre Steam real. Usar cuatro cuentas Steam diferentes.

## Preparación

1. Descargar el artifact `GodsAndLiars-Steam-Windows` del último Action verde.
2. Confirmar que contiene:
   - `GodsAndLiars.exe`
   - `steam_api64.dll`
   - `steam_appid.txt`
3. Confirmar que `steam_appid.txt` contiene `480` durante desarrollo.
4. Ejecutar Steam en las cuatro máquinas/cuentas.
5. Para generar logs QA, iniciar cada cliente desde PowerShell:

```powershell
$env:GODS_LIARS_QA_LOG = "1"
.\GodsAndLiars.exe
```

El log de cada instancia queda en el directorio de datos de usuario de Godot como `qa-session.log`.

## PASS / FAIL

Marcar cada punto con `[x] PASS` o `[ ] FAIL` y anotar el cliente afectado.

### Lobby

- [ ] Host crea lobby.
- [ ] Clientes B, C y D pueden entrar.
- [ ] Los cuatro clientes muestran exactamente los mismos cuatro jugadores.
- [ ] Los `seat_id` son únicos y coinciden en todas las instancias.
- [ ] Los cuatro jugadores pueden marcar READY.
- [ ] START permanece bloqueado con menos de cuatro jugadores.
- [ ] Host puede iniciar con cuatro jugadores READY.

### Mesa y roles

- [ ] Los cuatro clientes cambian a `table.tscn`.
- [ ] Cada jugador ocupa el mismo seat en todas las instancias.
- [ ] Cada cliente recibe exactamente un rol privado.
- [ ] Ningún cliente muestra roles de otros jugadores.
- [ ] Todos pueden confirmar la revelación.

### Noche

- [ ] Fases avanzan en orden: Hereje → Sanador → Inquisidor → resolución.
- [ ] Solo el rol activo puede confirmar una acción.
- [ ] Hereje no puede seleccionar otro Hereje.
- [ ] Sanador puede proteger un objetivo válido.
- [ ] Inquisidor no puede investigarse a sí mismo.
- [ ] Muertes nocturnas coinciden en los cuatro clientes.
- [ ] Resultado del Inquisidor aparece solo en su cliente.

### Voz

- [ ] Durante noche/revelación el voice routing está silenciado según diseño.
- [ ] Durante día, vivos se oyen entre sí.
- [ ] Muertos pueden escuchar a vivos.
- [ ] Voz de muerto no llega a vivos.
- [ ] Muertos sí pueden hablar entre muertos.

### Día, voto y sacrificio

- [ ] Host abre votación.
- [ ] Solo vivos pueden votar.
- [ ] No se puede votar a un muerto.
- [ ] Todos los votos válidos se aceptan una sola vez por jugador.
- [ ] Empate produce cero sacrificios.
- [ ] Ganador único produce exactamente un sacrificado.
- [ ] Estado vivo/muerto coincide en los cuatro clientes.

### Victoria y rematch

- [ ] Victoria de fieles se resuelve cuando no quedan Herejes.
- [ ] Victoria de Herejes se resuelve al alcanzar paridad.
- [ ] Los cuatro clientes muestran el mismo ganador.
- [ ] Muertos permanecen como ghosts/espectadores.
- [ ] Solo host puede iniciar rematch.
- [ ] Rematch conserva lobby, peers y seats.
- [ ] Rematch revive a todos.
- [ ] Rematch reparte roles nuevos.

### Desconexiones

- [ ] Cliente puede salir sin corromper roster de los demás.
- [ ] Un Steam ID puede volver después de su desconexión previa.
- [ ] Steam ID duplicado simultáneo sigue rechazado.
- [ ] Si sale el host, todos los clientes vuelven al lobby con estado limpio.
- [ ] Tras caída del host, un cliente puede crear/unirse a otro lobby sin reiniciar el juego.

## Comparación de logs

Cada `qa-session.log` es JSON Lines. Comparar especialmente estos eventos entre clientes:

```text
lobby_state
peer_updated
local_role_received
phase_synced
night_resolution
local_investigation
vote_resolution
match_end
rematch
```

Reglas de privacidad:

- `local_role_received` puede diferir entre clientes: eso es correcto.
- `local_investigation` debe existir únicamente en el cliente Inquisidor.
- `phase_synced`, `night_resolution`, `vote_resolution` y `match_end` deben coincidir entre los cuatro clientes.
- El log nunca debe contener un diccionario con los roles completos de la partida.

## Exit gate

FASE 8 humana queda VERDE solamente si todos los puntos críticos anteriores pasan y no hay divergencias entre los cuatro logs públicos.

Si falla un paso, conservar los cuatro `qa-session.log`, anotar el paso exacto y el cliente afectado, y corregir antes de declarar el MVP cerrado.
