## ADDED Requirements

### Requirement: Lo descargado suena del teléfono
Una canción descargada SHALL reproducirse desde su archivo local, haya o no conexión.

#### Scenario: Con conexión
- **WHEN** se reproduce Room on Fire descargado con Wi-Fi
- **THEN** suena del archivo y no se pide nada a Jellyfin para el audio

### Requirement: Arrancar sin red
Sin conexión con Jellyfin, la app SHALL abrir con la sesión guardada, y las secciones
que dependen del servidor SHALL mostrar su error en una línea sin bloquear lo demás.

#### Scenario: Modo avión
- **WHEN** se abre la app en modo avión
- **THEN** se ven las pestañas, Inicio muestra que no hay conexión, y el filtro Descargado de Biblioteca lista y reproduce lo descargado

### Requirement: Álbum descargado sin red
Abrir un álbum descargado sin conexión SHALL mostrarlo con los datos guardados al
descargarlo (nombre, artista, año, canciones y portada).

#### Scenario: Abrir sin red
- **WHEN** no hay conexión y se abre Room on Fire desde Descargado
- **THEN** se ven su portada, su cabecera y sus canciones, y tocar una la reproduce
