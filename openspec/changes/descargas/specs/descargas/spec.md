## ADDED Requirements

### Requirement: Calidad de descarga
La app SHALL ofrecer cuatro calidades: Original (el archivo tal cual), Alta (AAC 256
kbps), Normal (AAC 160 kbps, la predeterminada) y Ahorro (AAC 96 kbps). Las tres AAC
SHALL pedirse a Jellyfin ya comprimidas. Cambiar la calidad SHALL afectar solo a lo
que se descargue después.

#### Scenario: Descargar en Normal
- **WHEN** se descarga Reptilia con la calidad Normal
- **THEN** se guarda un archivo AAC de unos 4.5 MB, no el flac de 28.9 MB

#### Scenario: Cambiar de calidad
- **WHEN** hay un álbum descargado en Normal y se elige Ahorro
- **THEN** ese álbum sigue en Normal y el siguiente se descarga en Ahorro

### Requirement: Estimación por calidad
Junto a cada calidad SHALL mostrarse cuánto ocuparía toda la biblioteca: en Original,
la suma de los tamaños que da Jellyfin; en las AAC, la duración total por la tasa.

#### Scenario: Biblioteca de 39 horas
- **WHEN** la biblioteca suma 39 horas y 8.16 GB en original
- **THEN** se lee alrededor de 8.2 GB en Original, 4.5 GB en Alta, 2.8 GB en Normal y 1.7 GB en Ahorro

### Requirement: Descargar y borrar un álbum
El botón de descarga del álbum SHALL descargar todas sus canciones, mostrando el
avance; con el álbum descargado SHALL ofrecer borrarlo. Las descargas SHALL hacerse
de una en una, en el orden en que se pidieron.

#### Scenario: Descargar
- **WHEN** se toca descargar en Room on Fire
- **THEN** el botón muestra el avance por canciones y al terminar queda en coral como descargado

#### Scenario: Borrar
- **WHEN** se toca el botón de un álbum descargado y se confirma
- **THEN** sus archivos se borran y el espacio usado baja

#### Scenario: Se corta a medias
- **WHEN** la app se cierra con un álbum a medio descargar
- **THEN** al abrirla de nuevo la descarga sigue desde la canción que faltaba

### Requirement: Solo con Wi-Fi
Con "Descargar solo con Wi-Fi" encendido (predeterminado), las descargas SHALL
esperar a que haya Wi-Fi y retomarse solas cuando lo haya.

#### Scenario: En datos móviles
- **WHEN** se pide una descarga sin Wi-Fi y con el interruptor encendido
- **THEN** el álbum queda "Esperando Wi-Fi" y empieza al conectarse a una red Wi-Fi

### Requirement: Espacio usado
La pantalla de Descargas SHALL mostrar lo que ocupan los archivos descargados y
cuántos álbumes son.

#### Scenario: Cuatro álbumes
- **WHEN** hay cuatro álbumes descargados que suman 190 MB
- **THEN** se lee "190 MB en este iPhone" y "Música · 4 álbumes"

### Requirement: Solo en iOS
En la web no SHALL aparecer nada de descargas: ni botón en el álbum, ni pantalla, ni
filtros de descargado.

#### Scenario: Navegador
- **WHEN** se abre un álbum en Chrome
- **THEN** no hay botón de descarga
