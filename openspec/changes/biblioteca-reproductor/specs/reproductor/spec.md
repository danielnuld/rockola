## ADDED Requirements

### Requirement: Abrir el reproductor
Tocar el mini reproductor, o la canción de la barra del reproductor en la web, SHALL
abrir el Reproductor a pantalla completa por encima de las pestañas; la flecha de
arriba SHALL cerrarlo.

#### Scenario: Desde el mini reproductor
- **WHEN** suena algo y se toca el mini reproductor
- **THEN** se abre el Reproductor con la portada, el título y el artista de esa canción

### Requirement: Controles del reproductor
El Reproductor SHALL tener barra de progreso que se puede arrastrar con tiempo
transcurrido y restante, anterior, reproducir/pausar, siguiente, aleatorio y repetir.
Aleatorio y repetir encendidos SHALL verse en coral.

#### Scenario: Arrastrar el progreso
- **WHEN** se suelta la barra de progreso a la mitad
- **THEN** la canción sigue desde la mitad

#### Scenario: Repetir
- **WHEN** se toca repetir una vez
- **THEN** se repite toda la cola; otra vez, solo la canción; otra más, se apaga

### Requirement: Favorito de la canción
El corazón del Reproductor SHALL marcar o desmarcar como favorita la canción que suena,
con la misma regla de error que el favorito del álbum.

#### Scenario: Marcar la canción
- **WHEN** se toca el corazón con Reptilia sonando
- **THEN** Reptilia queda como favorita en Jellyfin

### Requirement: La cola
El Reproductor SHALL mostrar la cola con la canción actual marcada, y tocar otra SHALL
saltar a ella.

#### Scenario: Saltar en la cola
- **WHEN** se abre la cola y se toca la cuarta canción
- **THEN** empieza a sonar la cuarta canción
