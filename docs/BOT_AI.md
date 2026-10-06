# Bots de práctica: debate por texto

Los bots conversan solamente por escrito. No hay síntesis de voz, perfiles de voz ni modelos Kokoro. El chat de voz de jugadores humanos conserva sus controles existentes.

## Instalación y exportación

Ejecutar `powershell -File tools/setup-bot-ai.ps1` y reiniciar Godot. Godot 4.7 Windows x64 y NobodyWho 12.0.0 son la configuración validada. El modelo local Qwen3 1.7B Q4_K_M se descarga en `.tools/bot-models`; el complemento se instala en `addons/nobodywho`. Ambos están excluidos de Git. No requiere una cuenta, clave API ni servicio de pago.

`tools/build-windows.ps1` instala las dependencias, importa, exporta y empaqueta el modelo en `ai_models`, junto con los avisos y fuentes correspondientes en `ai`. Una exportación fallida no se presenta como compilación exitosa.

## Conversación y decisiones

Los bots simulan personas que ya saben jugar, no personajes que viven la ficción. Entienden que los avatares no se desplazan y que las acciones nocturnas son decisiones abstractas resueltas por las reglas. No inventan persecuciones, escondites, desplazamientos ni encuentros físicos. Argumentan a partir del chat, los votos, los resultados públicos y la información de su propio rol; conservan la incertidumbre cuando esos datos no bastan.

Durante la discusión hablan los bots vivos. Cada jugador simulado tiene nombre y personalidad, y responde en español, inglés, portugués o francés según el idioma seleccionado para el servidor de práctica. El chat muestra quién está escribiendo. Nombrar un bot prioriza su respuesta; un mensaje humano nuevo interrumpe una respuesta pendiente para evitar contestaciones fuera de contexto.

El director conserva hasta 18 intervenciones, 64 afirmaciones públicas y 32 votos. Compara intenciones con votos realizados, detecta cambios de candidato y reclamaciones incompatibles de roles únicos. Distingue las acusaciones de las pruebas y responde preguntas sobre confianza, suficiencia de una acusación y cambio de opinión. Las acusaciones repetidas por una misma persona no acumulan peso ilimitado.

Cada respuesta recibe únicamente el rol propio, los descubrimientos del propio bot y los hechos públicos. No obtiene los roles secretos de otros jugadores. Los resultados de investigación propios pesan más que rumores. Las acciones siguen pasando por la autoridad existente y se mantiene la protección tutorial del humano en la primera ronda.

La IA redacta respuestas breves siguiendo un plan de conversación. Si no está disponible, repite una intervención reciente, inventa un encuentro o evita una respuesta directa, se utiliza un respaldo coherente con ese plan. Las respuestas tardías se descartan al cambiar de fase o abandonar la partida.

## Alcance

La conversación está integrada en la práctica local; todavía no implementa bots de conversación para servidores Steam ni transcripción del micrófono humano. El modelo pequeño puede producir respuestas genéricas y no garantiza estrategia humana. La lógica de votos usa evidencia disponible y personalidad, y puede seguir mejorándose con partidas reales.
