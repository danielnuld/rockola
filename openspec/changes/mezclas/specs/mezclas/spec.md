## ADDED Requirements

### Requirement: Familias de género
Los géneros de Jellyfin SHALL agruparse en familias antes de armar mezclas; los que
no encajen en ninguna quedan con su propio nombre y las canciones sin género no
entran en mezclas de género.

#### Scenario: Variantes de rap
- **WHEN** hay canciones con "Hip Hop", "Rap/Hip Hop", "Hip-Hop/Rap", "Pop Rap" y "Gangsta Rap"
- **THEN** todas caen en la familia Rap

### Requirement: Tipos de mezcla
La app SHALL armar, con las canciones de la biblioteca: una mezcla por cada una de
las dos familias de género con más peso, una por cada una de las dos décadas con más
peso, "Lo más tuyo: <artista>" si ya hay escuchas, y "Lo que casi no tocas". El peso
de una familia, década o artista es la suma de las escuchas de sus canciones; sin
escuchas, cuántas canciones tiene.

#### Scenario: Sin historial
- **WHEN** ninguna canción tiene escuchas
- **THEN** hay mezclas de las dos familias y las dos décadas con más canciones y "Lo que casi no tocas", y no hay "Lo más tuyo"

#### Scenario: Con historial
- **WHEN** The Cranberries suma más escuchas que cualquier otro artista
- **THEN** existe "Lo más tuyo: The Cranberries"

### Requirement: Qué entra en una mezcla
Cada mezcla SHALL tener hasta 25 canciones y como máximo 3 del mismo artista, sin
dos del mismo artista seguidas si se puede evitar. Las canciones SHALL elegirse al
azar con más probabilidad para las más escuchadas y las favoritas y menos para las
saltadas; una canción saltada 3 veces o más sin ninguna escucha no SHALL entrar.

#### Scenario: Tope por artista
- **WHEN** una década tiene 40 canciones de The Strokes y 10 de otros
- **THEN** la mezcla de esa década lleva 3 de The Strokes como mucho

#### Scenario: Saltada muchas veces
- **WHEN** una canción se saltó 3 veces y nunca se escuchó
- **THEN** no aparece en ninguna mezcla

### Requirement: Estables durante el día
Las mezclas SHALL ser las mismas durante todo el día y cambiar al día siguiente.

#### Scenario: Volver a abrir
- **WHEN** se abre la app por la mañana y otra vez por la tarde el mismo día
- **THEN** las mezclas tienen las mismas canciones en el mismo orden

### Requirement: Página de mezcla
Tocar una mezcla SHALL abrir su página con la portada de cuatro álbumes, el nombre,
de qué va ("Rock de tu biblioteca, sobre todo lo que más escuchas"), reproducir,
aleatorio y la lista de canciones.

#### Scenario: Reproducir una mezcla
- **WHEN** se toca reproducir en la página de "Dosmilera"
- **THEN** suena la mezcla desde la primera canción y la cola son sus canciones
