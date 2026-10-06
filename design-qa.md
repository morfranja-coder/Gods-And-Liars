# Gods & Liars — HUD y menú

final result: passed

Fecha: 6 de octubre de 2026. Implementación nativa Godot en D:/Gods-And-Liars; no es un prototipo web.

Referencia: propuestas-hud/01-hud.png. Implementación: hud-debate-implementado.png, hud-votacion-implementado.png, hud-1280x720.png, menu-principal-implementado.png. Comparación normalizada: comparacion-hud.jpg; revisión ampliada de reloj y chat: comparacion-hud-detalles.jpg. Fuente generada 1672x941, captura real 1920x1080; comparación conserva la relación 16:9. También se revisó 1280x720.

## Revisión visual

- Distribución: ocho máscaras en la banda superior, reloj central integrado, chat inferior izquierdo, insignia privada inferior derecha. Centro de la escena libre. Nombres flotantes reducidos. Los campos y textos ya no se cruzan con los bordes.
- Tipografía: Georgia del sistema para encabezados y rol, tipografía legible del juego para nombres y conversaciones. Fallbacks serif declarados. El mensaje de chat se ajusta al ancho y el historial permite desplazamiento.
- Color: carbón, marfil y oro antiguo; colores originales de jugadores preservados. El último tramo del temporizador cambia de color sin perder la cifra visible. La muerte tiene texto además de atenuación.
- Imágenes: fondo del menú y marco generados; máscaras y icono de voz originales. Fondo escalado proporcionalmente, marco raster con nueve segmentos para conservar esquinas.
- Contenido: fase, tiempo, nombres y rol se alimentan del estado de la partida. RONDA sustituye DÍA del concepto para reflejar el contador real. La captura muestra el rol asignado por la práctica y mensajes auténticos de bots; estas diferencias con el concepto son intencionales.
- Menú: arte a la derecha y controles a la izquierda. Título, botones y foco visibles; la activación de práctica abre la mesa.
- Votación: marco coherente con el HUD y cuadrícula funcional existente. Las filas inferiores usan desplazamiento cuando exceden el panel.

## Validación funcional

- Cuatro pruebas existentes de máscaras e integración de mesa: 4 aprobadas, 0 fallos, 0 huérfanos. La prueba del antiguo temporizador se actualizó para comprobar el nuevo reloj central y evitar duplicación.
- Prueba gráfica: ocho jugadores, roles remotos ocultos, indicador de voz de un solo jugador y retirada tras silencio, foco del chat bloquea cámara, enviar vacía el campo.
- Importación Godot y ejecución gráfica sin errores de script. La ejecución de vista previa dejó una advertencia de un ObjectDB al salir; no se presenta como una limpieza completa del proceso.

## Ajustes menores pendientes

P3: el marco final tiene algo más de textura y ornamentación que el concepto. La insignia y el reloj pueden afinarse en otra iteración estética. No hay impedimentos de uso detectados en las resoluciones verificadas. No se probó una sesión online con ocho personas, ni relaciones de pantalla ultrapanorámicas.
