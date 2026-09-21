# navegacion Specification

## Purpose
Pestañas, barra inferior con mini reproductor y el diseño ancho para la web.
## Requirements
### Requirement: Cuatro pestañas
La app SHALL tener cuatro pestañas: Inicio, Buscar, Biblioteca y Radio, con Inicio
elegida al abrir.

#### Scenario: Abrir la app con sesión
- **WHEN** la app arranca con una sesión de Jellyfin guardada
- **THEN** muestra la pestaña Inicio

#### Scenario: Pestañas aún vacías
- **WHEN** se elige Radio en el iPhone
- **THEN** se ve un estado vacío que dice que la radio llega pronto, sin errores; en la web se ve la radio

### Requirement: Cada pestaña guarda su recorrido
Cada pestaña SHALL conservar su pila de pantallas al cambiar a otra pestaña y volver.

#### Scenario: Volver a Biblioteca
- **WHEN** se entra a un álbum desde Biblioteca, se cambia a Inicio y se vuelve a Biblioteca
- **THEN** sigue abierto el mismo álbum

#### Scenario: Tocar la pestaña activa
- **WHEN** se toca la pestaña en la que ya se está
- **THEN** vuelve a la primera pantalla de esa pestaña

### Requirement: Barra inferior con mini reproductor
Mientras haya algo en la cola, SHALL verse encima de las pestañas un mini reproductor
con portada, título, artista, botón de pausa/reproducir y una línea de progreso. Sin
cola, SHALL verse solo la fila de pestañas.

#### Scenario: Empieza a sonar algo
- **WHEN** se toca una canción
- **THEN** aparece el mini reproductor con esa canción y su progreso avanza

#### Scenario: Pausar desde la barra
- **WHEN** se toca el botón de pausa del mini reproductor
- **THEN** la música se detiene y el botón pasa a reproducir

### Requirement: Diseño ancho para la web
Con la ventana de 900 px o más de ancho, la app SHALL cambiar las pestañas de abajo
por un lateral con las mismas cuatro secciones, y el mini reproductor por una barra
del reproductor a todo lo ancho abajo.

#### Scenario: Navegador de escritorio
- **WHEN** la app se abre en una ventana de 1440 px
- **THEN** se ven el lateral, el panel principal y la barra del reproductor, sin pestañas abajo

#### Scenario: Estrechar la ventana
- **WHEN** la ventana baja de 900 px
- **THEN** vuelven las pestañas y el mini reproductor, sin perder lo que estaba sonando

