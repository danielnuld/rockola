## ADDED Requirements

### Requirement: Botón de letra
El Reproductor SHALL mostrar el botón "Letra" solo cuando la canción que suena tiene
letra en Jellyfin (`HasLyrics`). Tocarlo SHALL cambiar la portada por la letra, y
tocarlo otra vez volver a la portada. Con 900 px o más de ancho, portada y letra SHALL
verse lado a lado.

#### Scenario: Canción con letra
- **WHEN** suena una canción con letra y se toca "Letra"
- **THEN** en lugar de la portada se ve la letra

#### Scenario: Canción sin letra
- **WHEN** suena una canción sin letra
- **THEN** no hay botón "Letra"

#### Scenario: Cambia la canción
- **WHEN** la letra está abierta y empieza otra canción con letra
- **THEN** se ve la letra de la nueva

### Requirement: Letra sincronizada
Si las líneas traen tiempo de inicio, la línea que suena SHALL resaltarse en coral y
mantenerse centrada mientras avanza la canción, las ya cantadas SHALL verse atenuadas,
y tocar una línea SHALL saltar a su tiempo.

#### Scenario: Avanza la canción
- **WHEN** la posición pasa del inicio de la tercera línea
- **THEN** la tercera línea está resaltada y centrada

#### Scenario: Saltar a una línea
- **WHEN** se toca una línea que empieza en 1:02
- **THEN** la canción sigue desde 1:02

### Requirement: Letra sin tiempos
Si ninguna línea trae tiempo, la letra SHALL verse entera, sin resaltar, y tocar una
línea no SHALL hacer nada.

#### Scenario: Letra plana
- **WHEN** la letra de Highway to Hell no trae tiempos
- **THEN** se ven todas sus líneas del mismo color

### Requirement: Letra sin conexión
Al descargar un álbum o una lista SHALL guardarse también la letra de cada canción que
la tenga, y sin conexión la letra SHALL leerse de ahí.

#### Scenario: Modo avión
- **WHEN** suena sin red una canción descargada que tiene letra
- **THEN** el botón "Letra" funciona y muestra la letra guardada
