# terminal Specification

## Purpose
TBD - created by archiving change cliente-terminal. Update Purpose after archive.
## Requirements
### Requirement: Configuración y sesión
La configuración SHALL leerse de un JSON escrito a mano: `rockola.json` junto al
ejecutable o, si no existe, `%APPDATA%\Rockola\config.json`, con `url` y `usuario` de
Jellyfin y, opcionales, `huellas`, `locutor` y `mpv`. Sin token guardado, SHALL pedir
la contraseña sin mostrarla, iniciar sesión y guardar en el mismo archivo solo el token
(nunca la contraseña), sin tocar lo demás. Si Jellyfin rechaza el token, SHALL
olvidarlo para pedir la contraseña la siguiente vez.

#### Scenario: Primera vez
- **WHEN** existe `rockola.json` con `url` y `usuario` y se corre `rockola`
- **THEN** pide la contraseña una vez y las siguientes ejecuciones ya no la piden

#### Scenario: Sin configuración
- **WHEN** no existe ninguno de los dos archivos
- **THEN** dice dónde crearlo y muestra un ejemplo

#### Scenario: Llevarlo en una memoria
- **WHEN** hay `rockola.json` junto al ejecutable y también el de `%APPDATA%`
- **THEN** usa el que está junto al ejecutable

### Requirement: Interfaz
`rockola` SHALL abrir una interfaz a pantalla completa como la web: barra lateral con
Inicio, Buscar, Biblioteca, Mezclas, Listas, Radio y Cola; la lista de la sección en el
centro; y abajo lo que suena (título, un visualizador de una línea, el tiempo y la línea
de la letra). SHALL manejarse con el teclado: ↑↓ mover, Enter abrir o tocar, Tab entre
la barra y la lista, Esc atrás, `/` buscar escribiendo, espacio pausa, `n`/`p`
siguiente y anterior, ←/→ ±10 s, `v` visualizador a pantalla completa, `a` color o
ASCII, `q` salir. `rockola <búsqueda>`, `rockola mezclas` y `rockola radio` SHALL abrirla
en esa sección. Al salir SHALL dejar la terminal como estaba.

#### Scenario: Buscar y tocar
- **WHEN** se pulsa `/`, se escribe «reptilia», Enter, y Enter sobre la canción
- **THEN** suena Reptilia y después el resto de Room on Fire, y abajo se ven su título y su letra

#### Scenario: Navegar la biblioteca
- **WHEN** en Biblioteca se elige Room on Fire con Enter y luego una canción
- **THEN** suena esa canción y sigue el álbum; Esc vuelve a la lista de álbumes

#### Scenario: Salir
- **WHEN** se pulsa `q` o Ctrl+C
- **THEN** mpv se cierra y la terminal vuelve a su estado normal, con el cursor visible

### Requirement: La música no sobrevive a la ventana
Si Rockola termina sin cerrar mpv (se cierra la ventana, se mata el proceso), mpv SHALL
cerrarse solo en pocos segundos.

#### Scenario: Cerrar la ventana
- **WHEN** se cierra la ventana de la terminal mientras suena
- **THEN** la música para en unos 6 segundos

### Requirement: Visualizador en texto
El visualizador SHALL dibujar las 16 bandas del cuadro de la huella que corresponde a
la posición de mpv, con bloques Unicode y degradado de coral a ámbar, en una línea
abajo de la interfaz y a pantalla completa con `v`; con `--ascii` (o la tecla `a`), sin
color ni símbolos Unicode. Sin servidor de huellas o sin huella, SHALL moverse con el
patrón sintético, sin errores en pantalla.

#### Scenario: Con huella
- **WHEN** suena una canción con huella en el servidor
- **THEN** las barras siguen a la música y saltan con ella al adelantar

#### Scenario: Consola sin Unicode
- **WHEN** se corre con `--ascii`
- **THEN** los bordes, las barras y los símbolos son ASCII y no hay secuencias de color

### Requirement: Radio con locutora
En la sección Radio, Enter sobre Sintonizar SHALL armar la hora de radio con las mezclas
del día, como la web, e intercalar entre canciones las entradas del servidor del
locutor; "Cambiar el rumbo" SHALL armar otra con otras canciones. Sin servidor o si no
responde, SHALL sonar solo la música y decirlo.

#### Scenario: Con locutora
- **WHEN** se sintoniza con el servidor del locutor configurado
- **THEN** entre canciones suena la voz de la locutora y su texto aparece abajo

### Requirement: Escuchas
Cada canción SHALL avisar a Jellyfin al empezar y al terminar, como la app, para que
cuente en las mezclas.

#### Scenario: Una canción entera
- **WHEN** una canción suena hasta el final desde la terminal
- **THEN** su número de escuchas en Jellyfin sube en uno

