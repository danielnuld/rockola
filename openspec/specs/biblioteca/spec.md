# biblioteca Specification

## Purpose
Lista de álbumes y artistas, filtros, orden y página de artista.
## Requirements
### Requirement: Lista de la biblioteca
La pestaña Biblioteca SHALL mostrar una lista de álbumes o artistas según el filtro
elegido (Álbumes por defecto), cada fila con su portada de 56 px, nombre y una línea
secundaria ("Álbum · <artista>" o "Artista"), y el total al lado del orden.

#### Scenario: Abrir la biblioteca
- **WHEN** se entra a la pestaña Biblioteca
- **THEN** se ven los álbumes en lista con el filtro Álbumes marcado en coral y el total de álbumes

#### Scenario: Filtrar por artistas
- **WHEN** se toca el filtro Artistas
- **THEN** la lista pasa a los artistas de álbum de Jellyfin

### Requirement: Orden de la biblioteca
La lista SHALL ordenarse por "Escuchados hace poco" por defecto: primero lo que tenga
reproducciones recientes en el orden del historial, después el resto por nombre. Tocar
el orden SHALL alternar con "A–Z".

#### Scenario: Recientes primero
- **WHEN** lo último que sonó fue de Room on Fire y antes de Rumours
- **THEN** la lista empieza por Room on Fire, sigue Rumours y después los demás álbumes de la A a la Z

#### Scenario: Cambiar a A–Z
- **WHEN** se toca el orden
- **THEN** dice "A–Z" y la lista queda solo por nombre

### Requirement: Página de artista
Tocar un artista SHALL abrir su página con sus álbumes del más reciente al más
antiguo, dentro de la misma pestaña.

#### Scenario: Abrir un artista
- **WHEN** se toca The Strokes en Artistas
- **THEN** se ven sus siete álbumes empezando por el más reciente, y tocar uno abre el Álbum

### Requirement: Filtro Mezclas
La Biblioteca SHALL tener el filtro Mezclas, que lista las mezclas del día como filas
con su portada de cuatro álbumes y "Mezcla · <artistas>".

#### Scenario: Ver las mezclas
- **WHEN** se toca Mezclas
- **THEN** la lista muestra las mezclas del día y tocar una abre su página

### Requirement: Filtro Listas
La Biblioteca SHALL tener el filtro Listas, entre Artistas y Mezclas, con las listas
de Jellyfin como filas ("Lista · <n> canciones") y "Nueva lista" arriba.

#### Scenario: Ver las listas
- **WHEN** se toca Listas
- **THEN** se ven las listas del usuario y tocar una abre su página

#### Scenario: Ninguna lista
- **WHEN** no hay listas
- **THEN** se lee "Todavía no tienes listas" y "Nueva lista" sigue disponible

