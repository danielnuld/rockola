## ADDED Requirements

### Requirement: Lo descargado suena del teléfono
Una canción descargada SHALL reproducirse desde su archivo local, haya o no conexión.

#### Scenario: Con conexión
- **WHEN** se reproduce Room on Fire descargado con Wi-Fi
- **THEN** suena del archivo y no se pide nada a Jellyfin para el audio

### Requirement: Arrancar sin red
Sin conexión con Jellyfin, la app SHALL abrir con la sesión guardada, y las secciones
que dependen del servidor SHALL mostrar su error en una línea sin bloquear lo demás.
Al abrir y con cada cambio de red la app SHALL preguntar al servidor (3 s como
mucho); si no responde, las peticiones a Jellyfin SHALL fallar al momento en lugar
de esperar, e Inicio y Biblioteca SHALL abrir en lo descargado.

#### Scenario: Modo avión
- **WHEN** se abre la app en modo avión
- **THEN** se ven las pestañas, Inicio muestra que no hay conexión, y el filtro Descargado de Biblioteca lista y reproduce lo descargado

#### Scenario: Servidor inalcanzable con red
- **WHEN** hay Wi-Fi pero no se llega al servidor (Tailscale apagado)
- **THEN** en unos 3 s la app muestra lo descargado, sin pantallas cargando

### Requirement: Radio sin red
Sin conexión, las mezclas SHALL salir de las canciones descargadas (una mezcla "Lo
descargado"), y la radio SHALL armar la hora con ellas.

#### Scenario: Sintonizar en modo avión
- **WHEN** en modo avión, con álbumes descargados, se toca Sintonizar
- **THEN** suena una hora de canciones descargadas; en el iPhone, con la locutora del teléfono

### Requirement: Álbum descargado sin red
Abrir un álbum descargado sin conexión SHALL mostrarlo con los datos guardados al
descargarlo (nombre, artista, año, canciones y portada).

#### Scenario: Abrir sin red
- **WHEN** no hay conexión y se abre Room on Fire desde Descargado
- **THEN** se ven su portada, su cabecera y sus canciones, y tocar una la reproduce

### Requirement: Buscar sin red
Sin conexión, Buscar SHALL buscar en lo descargado: álbumes y canciones cuyo nombre,
artista o álbum contienen el texto, sin distinguir mayúsculas ni acentos, agrupados
como en la búsqueda normal.

#### Scenario: Buscar en modo avión
- **WHEN** en modo avión se escribe "strokes"
- **THEN** sale Room on Fire en Álbumes y se puede abrir y escuchar
