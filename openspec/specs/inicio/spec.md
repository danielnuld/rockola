# inicio Specification

## Purpose
Contenido de la pantalla Inicio y de dónde sale cada sección.
## Requirements
### Requirement: Saludo según la hora
Inicio SHALL saludar con "Buenos días" de 6:00 a 11:59, "Buenas tardes" de 12:00 a
18:59 y "Buenas noches" el resto, según la hora local del equipo.

#### Scenario: De noche
- **WHEN** se abre Inicio a las 23:10
- **THEN** el título dice "Buenas noches"

#### Scenario: Al mediodía
- **WHEN** se abre Inicio a las 12:00
- **THEN** el título dice "Buenas tardes"

### Requirement: Tarjeta de Rockola FM
Inicio SHALL mostrar la tarjeta ámbar de Rockola FM con el botón "Sintonizar", que
lleva a la pestaña Radio.

#### Scenario: Sintonizar
- **WHEN** se toca "Sintonizar"
- **THEN** la app cambia a la pestaña Radio

### Requirement: Volver a escuchar
Inicio SHALL mostrar hasta seis álbumes, del más reciente al más antiguo, sacados de
las últimas canciones reproducidas en Jellyfin, sin repetir álbum. Tocar uno SHALL
abrirlo dentro de la pestaña Inicio.

#### Scenario: Historial con varios álbumes
- **WHEN** en Jellyfin las últimas canciones escuchadas son de Room on Fire, Rumours y otra vez Room on Fire
- **THEN** la sección muestra Room on Fire y después Rumours, una vez cada uno

#### Scenario: Sin historial
- **WHEN** Jellyfin no tiene ninguna reproducción registrada
- **THEN** la sección no se muestra y el resto de Inicio sí

#### Scenario: Jellyfin no responde
- **WHEN** falla la consulta del historial
- **THEN** la sección muestra el error en una línea con opción de reintentar, y la tarjeta de Rockola FM sigue visible

