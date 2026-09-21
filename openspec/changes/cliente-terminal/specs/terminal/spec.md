## ADDED Requirements

### Requirement: Sesión
`rockola login <url> <usuario>` SHALL pedir la contraseña sin mostrarla, iniciar sesión
en Jellyfin y guardar URL, usuario y token (nunca la contraseña). Los servidores del
locutor y de huellas SHALL configurarse con `rockola ajustes locutor <url>` y
`rockola ajustes huellas <url>`.

#### Scenario: Primera vez
- **WHEN** se corre `rockola login http://100.102.40.65:8096 daniel` con la contraseña correcta
- **THEN** los comandos siguientes funcionan sin volver a pedirla

#### Scenario: Sin sesión
- **WHEN** se corre cualquier otro comando sin haber iniciado sesión
- **THEN** dice cómo iniciarla y termina

### Requirement: Elegir qué suena
`rockola <búsqueda>` SHALL listar numeradas las canciones, álbumes y artistas que
encuentra Jellyfin y reproducir el que se elija por número: una canción sigue con el
resto de su álbum, un álbum suena entero y un artista suena mezclado.
`rockola mezclas` SHALL listar las mezclas del día y `rockola radio` SHALL empezar la
radio.

#### Scenario: Buscar y elegir
- **WHEN** se corre `rockola reptilia` y se elige la canción
- **THEN** suena Reptilia y después el resto de Room on Fire

### Requirement: Pantalla "Suena"
Mientras suena, la terminal SHALL mostrar título, artista y álbum, el progreso, la línea
de la letra que se canta y la siguiente, y el visualizador, y SHALL responder a las
teclas: espacio pausa, `n` siguiente, `p` anterior, flechas ±10 s, `v` cambia entre
color y ASCII, `l` muestra u oculta la letra, `q` sale. Al salir SHALL dejar la terminal
como estaba.

#### Scenario: Pausa
- **WHEN** se pulsa espacio
- **THEN** la música se pausa y el visualizador se queda quieto

#### Scenario: Salir
- **WHEN** se pulsa `q` o Ctrl+C
- **THEN** mpv se cierra y la terminal vuelve a su estado normal, con el cursor visible

### Requirement: Visualizador en texto
El visualizador SHALL dibujar las 16 bandas del cuadro de la huella que corresponde a
la posición de mpv, con bloques Unicode y degradado de coral a ámbar; con `--ascii` (o
la tecla `v`), solo caracteres ASCII y sin color. Sin servidor de huellas o sin huella,
SHALL moverse con el patrón sintético, sin errores en pantalla.

#### Scenario: Con huella
- **WHEN** suena una canción con huella en el servidor
- **THEN** las barras siguen a la música y saltan con ella al adelantar

#### Scenario: Consola sin Unicode
- **WHEN** se corre con `--ascii`
- **THEN** las barras usan solo caracteres ASCII y no hay secuencias de color

### Requirement: Radio con locutora
`rockola radio` SHALL armar la hora de radio con las mezclas del día, como la web, e
intercalar entre canciones las entradas del servidor del locutor. Sin servidor o si no
responde, SHALL sonar solo la música.

#### Scenario: Con locutora
- **WHEN** se corre `rockola radio` con el servidor del locutor configurado
- **THEN** entre canciones suena la voz de la locutora y su texto aparece en pantalla

### Requirement: Escuchas
Cada canción SHALL avisar a Jellyfin al empezar y al terminar, como la app, para que
cuente en las mezclas.

#### Scenario: Una canción entera
- **WHEN** una canción suena hasta el final desde la terminal
- **THEN** su número de escuchas en Jellyfin sube en uno
