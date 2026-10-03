## MODIFIED Requirements

### Requirement: Huella sin conexión
Al descargar un álbum o una lista SHALL guardarse también la huella de cada canción:
la del servidor de huellas si está configurado y responde y, si no, en iOS, la
calculada en el teléfono a partir del archivo descargado, con el mismo formato. Sin
conexión SHALL usarse esa. Si no se consigue ninguna, la canción SHALL quedar descargada
igual.

#### Scenario: Modo avión
- **WHEN** suena sin red una canción descargada con su huella
- **THEN** el visualizador reacciona a la música igual que con red

#### Scenario: Descarga sin servidor de huellas
- **WHEN** en el iPhone se descarga un álbum sin servidor de huellas en Ajustes
- **THEN** cada canción queda con su huella y el visualizador reacciona a la música sin red

#### Scenario: Servidor que no responde
- **WHEN** el servidor de huellas configurado no responde al descargar
- **THEN** la huella se calcula en el teléfono y la descarga termina bien

#### Scenario: Formato que no se abre
- **WHEN** la canción descargada es un formato que el iPhone no decodifica
- **THEN** queda descargada sin huella y el visualizador usa el patrón suave
