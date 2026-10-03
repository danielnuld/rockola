## ADDED Requirements

### Requirement: Origen de la canción
Cuando la canción que suena sale de un archivo descargado, el Reproductor SHALL
mostrar abajo la insignia "En el iPhone · <calidad>"; si sale del servidor, no.

#### Scenario: Descargada en Normal
- **WHEN** suena Reptilia descargada en Normal
- **THEN** abajo se lee "En el iPhone · AAC 160 kbps"

#### Scenario: Desde el servidor
- **WHEN** suena una canción que no está descargada
- **THEN** no hay insignia
