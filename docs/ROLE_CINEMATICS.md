# PresentaciÃ³n de roles

La pantalla privada de asignaciÃ³n reproduce el video del rol correspondiente durante 10 segundos, en lugar del antiguo panel con botÃ³n. Al terminar confirma el rol una sola vez y devuelve la imagen al juego. La presentaciÃ³n completa ocupa aproximadamente 11 segundos, dentro del lÃ­mite de 15 segundos de la autoridad.

Los cuatro videos proporcionados se guardan en `assets/videos/roles` como Ogg Theora de 1920Ã—1080, 30 fps, con el audio original convertido a Vorbis estÃ©reo de 48 kHz. Los MP4 originales permanecen intactos. Para volver a convertirlos: ejecutar `tools/import-role-videos.ps1 -SourceDirectory <carpeta> -FfmpegBinary <ffmpeg.exe>`. FFmpeg solo es necesario para importar material nuevo.

El tÃ­tulo se dibuja en tiempo de ejecuciÃ³n con Cinzel y colores por rol; espaÃ±ol, inglÃ©s, portuguÃ©s y francÃ©s siguen el idioma del servidor de prÃ¡ctica. Sacerdote corresponde al rol interno HEALER. La descripciÃ³n y el compaÃ±ero hereje siguen siendo informaciÃ³n privada del jugador.

La franja inferior sigue las dimensiones del video, incluidas las pantallas con bandas laterales o superiores, y cubre la marca inferior. Hay un fundido del juego a negro, entrada del video desde negro, salida del video hacia negro y regreso suave al juego. El audio usa SFX y respeta los ajustes de sonido.

Los mensajes repetidos de rol o de compaÃ±ero no reinician el video. Cambiar de fase cancela la presentaciÃ³n. Las respuestas de confirmaciÃ³n tardÃ­as no se envÃ­an en otra fase. La cÃ¡mara queda bloqueada durante la presentaciÃ³n y vuelve a habilitarse al terminar. Un fallo del recurso o del decodificador conserva el tÃ­tulo y permite seguir jugando.

ValidaciÃ³n: 294 pruebas en 57 suites sin fallos; reproducciÃ³n de los cuatro roles, capturas de los fundidos y tÃ­tulos en distintos idiomas. En el paquete exportado se verificaron video, audio activo, Cinzel, bloqueo/restauraciÃ³n de cÃ¡mara y paso automÃ¡tico a GOD_INTRO.

El video de Hereje usa la nueva fuente «Selección Hereje HD.mp4» y calidad Theora 10. El importador prefiere automáticamente esta versión si está disponible; conserva el archivo original como alternativa.
