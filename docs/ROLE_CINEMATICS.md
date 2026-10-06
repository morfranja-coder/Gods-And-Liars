# Presentación de roles

La pantalla privada de asignación reproduce el video del rol correspondiente durante 10 segundos, en lugar del antiguo panel con botón. Al terminar confirma el rol una sola vez y devuelve la imagen al juego. La presentación completa ocupa aproximadamente 11 segundos, dentro del límite de 15 segundos de la autoridad.

Los cuatro videos proporcionados se guardan en `assets/videos/roles` como Ogg Theora de 1920×1080, 30 fps, con el audio original convertido a Vorbis estéreo de 48 kHz. Los MP4 originales permanecen intactos. Para volver a convertirlos: ejecutar `tools/import-role-videos.ps1 -SourceDirectory <carpeta> -FfmpegBinary <ffmpeg.exe>`. FFmpeg solo es necesario para importar material nuevo.

El título se dibuja en tiempo de ejecución con Cinzel y colores por rol; español, inglés, portugués y francés siguen el idioma del servidor de práctica. Sacerdote corresponde al rol interno HEALER. La descripción y el compañero hereje siguen siendo información privada del jugador.

La franja inferior sigue las dimensiones del video, incluidas las pantallas con bandas laterales o superiores, y cubre la marca inferior. Hay un fundido del juego a negro, entrada del video desde negro, salida del video hacia negro y regreso suave al juego. El audio usa SFX y respeta los ajustes de sonido.

Los mensajes repetidos de rol o de compañero no reinician el video. Cambiar de fase cancela la presentación. Las respuestas de confirmación tardías no se envían en otra fase. La cámara queda bloqueada durante la presentación y vuelve a habilitarse al terminar. Un fallo del recurso o del decodificador conserva el título y permite seguir jugando.

Validación: 294 pruebas en 57 suites sin fallos; reproducción de los cuatro roles, capturas de los fundidos y títulos en distintos idiomas. En el paquete exportado se verificaron video, audio activo, Cinzel, bloqueo/restauración de cámara y paso automático a GOD_INTRO.
