# FASE 8 — Steam 8-client acceptance checklist

Este gate valida el modo Mafia completo sobre Steam real con el target comercial actual de exactamente ocho jugadores.

## Preparación

1. Descargar `GodsAndLiars-Steam-Windows` del último Action verde.
2. Confirmar `GodsAndLiars.exe`, `steam_api64.dll` y `steam_appid.txt`.
3. Confirmar App ID de desarrollo `480`.
4. Usar ocho cuentas Steam distintas.
5. Iniciar cada cliente con QA logging y una etiqueta única: `host`, `client2` ... `client8`.

## Party + Quick Match

- [ ] Un solo jugador puede entrar a Quick Match como Party de 1.
- [ ] Un Party completo nunca es dividido para completar una partida.
- [ ] Composiciones exactas como 5+3 pueden formar 8/8.
- [ ] Composiciones múltiples como 4+2+1+1 pueden formar 8/8.
- [ ] Una composición que excedería 8 es rechazada.
- [ ] La búsqueda expande CLOSE -> DEFAULT -> FAR -> WORLDWIDE con el tiempo.
- [ ] Al encontrar 8/8, todos terminan en el mismo Match Lobby.
- [ ] Ningún noveno jugador puede entrar al Match Lobby.

## Match Lobby

- [ ] Los ocho clientes muestran exactamente los mismos ocho jugadores.
- [ ] Los `seat_id` son únicos y coinciden en todas las instancias.
- [ ] Los ocho pueden marcar READY mientras el flujo transicional siga usando READY.
- [ ] START permanece bloqueado con 7/8.
- [ ] Host puede iniciar con 8/8 READY.

## Mesa y roles

- [ ] Los ocho clientes cambian a `table.tscn`.
- [ ] Cada jugador ocupa el mismo seat en todas las instancias.
- [ ] Cada cliente recibe exactamente un rol privado.
- [ ] Ningún cliente muestra roles de otros jugadores.
- [ ] La distribución de 8 contiene 2 Herejes, 1 Sanador, 1 Inquisidor y 4 Fieles.
- [ ] Todos pueden confirmar la revelación.

## Noche

- [ ] Fases avanzan Hereje -> Sanador -> Inquisidor -> resolución.
- [ ] Solo el rol activo puede confirmar una acción.
- [ ] Hereje no puede seleccionar otro Hereje.
- [ ] Sanador puede proteger un objetivo válido.
- [ ] Inquisidor no puede investigarse a sí mismo.
- [ ] Muertes nocturnas coinciden en los ocho clientes.
- [ ] Resultado del Inquisidor aparece solo en su cliente.

## Voz

- [ ] Durante noche/revelación el voice routing queda silenciado según diseño.
- [ ] Durante día, vivos se oyen entre sí.
- [ ] Muertos pueden escuchar a vivos.
- [ ] Voz de muerto no llega a vivos.
- [ ] Muertos sí pueden hablar entre muertos.

## Día, voto y sacrificio

- [ ] Host abre votación.
- [ ] Solo vivos pueden votar.
- [ ] No se puede votar a un muerto ni a uno mismo.
- [ ] Votos válidos sincronizan y pueden corregirse antes del cierre del quorum.
- [ ] Empate produce cero sacrificios.
- [ ] Ganador único produce exactamente un sacrificado.
- [ ] Estado vivo/muerto coincide en los ocho clientes.

## Victoria y rematch

- [ ] Fieles ganan cuando no quedan Herejes.
- [ ] Herejes ganan al alcanzar paridad.
- [ ] Los ocho muestran el mismo ganador.
- [ ] Muertos permanecen como ghosts/espectadores lógicos.
- [ ] Solo host puede iniciar rematch.
- [ ] Rematch conserva Match Lobby, peers y seats.
- [ ] Rematch revive a todos y reparte roles nuevos.

## Desconexiones

- [ ] Cliente puede salir sin congelar ACK, noche o voto.
- [ ] Jugador desconectado queda fuera/muerto para quorum de la partida en curso.
- [ ] Steam ID puede volver en una sesión posterior tras desconexión limpia.
- [ ] Steam ID duplicado simultáneo sigue rechazado.
- [ ] Si sale el host, la sesión termina limpiamente; no hay host migration en el MVP.

## Logs

Comparar:

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

Privacidad:
- `local_role_received` puede diferir entre clientes.
- `local_investigation` debe aparecer únicamente en el Inquisidor.
- fases y resoluciones públicas deben coincidir en los ocho logs.
- ningún log de cliente debe contener el mapa completo de roles.

## Exit gate

FASE 8 humana queda VERDE solamente cuando la partida completa 8/8 termina y puede hacer rematch sin divergencias públicas ni filtraciones privadas.
