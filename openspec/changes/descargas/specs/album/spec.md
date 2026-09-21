## ADDED Requirements

### Requirement: Botón de descarga del álbum
En iOS la fila de acciones del álbum SHALL tener el botón de descarga junto al
favorito, con tres estados: sin descargar, descargando (con el avance) y descargado
(en coral, con el tamaño al lado).

#### Scenario: Descargado
- **WHEN** Room on Fire está descargado en Normal
- **THEN** el botón está en coral y al lado dice "48 MB" o lo que ocupe
