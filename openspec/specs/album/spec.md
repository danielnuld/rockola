# album Specification

## Purpose
La página de un álbum y cómo se reproduce desde ella.
## Requirements
### Requirement: Cabecera del álbum
La página de un álbum SHALL mostrar la portada grande, el nombre, el artista (que
lleva a su página) y la línea "Álbum · <año> · <n> canciones · <m> min", contando
canciones y minutos a partir de la lista de canciones.

#### Scenario: Álbum completo
- **WHEN** se abre Room on Fire (2003, 11 canciones, 33 minutos)
- **THEN** la línea dice "Álbum · 2003 · 11 canciones · 33 min"

#### Scenario: Sin año
- **WHEN** Jellyfin no tiene año del álbum
- **THEN** la línea omite el año sin dejar un separador de más

### Requirement: Reproducir desde el álbum
El botón coral de reproducir SHALL poner el álbum entero desde la primera canción; el
de aleatorio SHALL ponerlo en orden aleatorio; tocar una canción SHALL poner el álbum
desde esa canción.

#### Scenario: Tocar la segunda canción
- **WHEN** se toca Reptilia en Room on Fire
- **THEN** suena Reptilia y la cola sigue con el resto del álbum

#### Scenario: Aleatorio
- **WHEN** se toca aleatorio
- **THEN** suena el álbum con el modo aleatorio encendido

### Requirement: La canción que suena
En la lista del álbum, la canción que está sonando SHALL verse en coral.

#### Scenario: Cambio de canción
- **WHEN** termina Reptilia y empieza Automatic Stop
- **THEN** Automatic Stop pasa a coral y Reptilia vuelve al color normal

### Requirement: Favorito del álbum
El corazón SHALL marcar o desmarcar el álbum como favorito en Jellyfin y reflejar el
estado que devuelva el servidor.

#### Scenario: Marcar favorito
- **WHEN** se toca el corazón vacío
- **THEN** se llena en coral y Jellyfin guarda el álbum como favorito

#### Scenario: Falla el servidor
- **WHEN** Jellyfin rechaza el cambio
- **THEN** el corazón vuelve a como estaba y aparece un aviso breve

