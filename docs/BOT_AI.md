# Bots de práctica: IA y voces locales

Instalar con `powershell -File tools/setup-bot-ai.ps1`, luego reiniciar Godot. Requiere Godot 4.6+; validado aquí con 4.7 Windows x64. NobodyWho se fija en 12.0.0 (API RefCounted asíncrona); los ejemplos de nodos publicados en algunas páginas corresponden a versiones anteriores.

Se usa Qwen3 1.7B Q4_K_M para conversación y Kokoro para voz. Descargas en `.tools/bot-models`, complemento en `addons/nobodywho`, ambos excluidos de Git. Son dependencias locales que el instalador reproduce; no se incluyen automáticamente en una exportación. NobodyWho: EUPL 1.2; Kokoro: Apache 2.0. Consultar también la licencia del modelo Qwen antes de distribuir.

Durante DAY_DISCUSSION el director da turnos a los bots vivos, conserva hasta 18 intervenciones, entrega solo el rol propio y las investigaciones del propio bot junto a los hechos públicos. Cada respuesta reemplaza el contexto del modelo compartido para evitar transferir información privada entre personajes. La IA genera diálogo; las acciones pasan por la autoridad existente. El voto usa descubrimientos privados y votos públicos, con desempate por personalidad. La primera ronda conserva la protección tutorial del humano.

Nombres y personalidades están definidos en BotDirector. Subtítulos e ingreso de texto aparecen durante debate. Audio por el bus Voice, respetando silenciamiento individual, con indicador de máscara mientras suena. Una respuesta tardía se descarta al cambiar de fase o salir. Si la IA o voz falla, la partida conserva respuestas de respaldo y subtítulos.

Opciones permite seleccionar español, inglés, portugués o francés para el servidor de práctica antes de iniciar. Esto está integrado en práctica local; no implementa todavía negociación de idioma ni transmisión de audio de bots en servidores Steam. Tampoco transcribe aún el micrófono humano: se puede conversar con los bots escribiendo. Kokoro ofrece tres voces españolas, no siete timbres independientes; velocidades y personalidades distinguen los personajes.

Validación local: 267 casos en 56 suites, sin fallos ni errores de pruebas. Partida renderizada con cuatro intervenciones habladas distintas y respuesta prioritaria al bot mencionado. Qwen3 1.7B respondió en 1,7–2,6 segundos en esta prueba. Captura y registros disponibles en el informe de la sesión. El diálogo usa contribuciones propuestas por la lógica del juego y reformuladas por la IA; no constituye todavía una estrategia autónoma completa.
