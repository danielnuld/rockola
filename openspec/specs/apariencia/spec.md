# apariencia Specification

## Purpose
TBD - created by archiving change base-visual. Update Purpose after archive.
## Requirements
### Requirement: Paleta de Rockola
La app SHALL usar fondo `#141110`, texto principal `#F4EDE6`, texto secundario
`#B3A79C`, superficies `#2A2421`, coral `#FF6B3D` como acento de la música y ámbar
`#F5B841` solo para la radio y la locutora. Siempre en oscuro: no hay tema claro.

#### Scenario: Acento de música
- **WHEN** se pinta un elemento activo de la música (pestaña de filtro elegida, canción que suena, indicador de descargado)
- **THEN** usa el coral `#FF6B3D`

#### Scenario: El ámbar es de la radio
- **WHEN** se pinta cualquier cosa que no sea la radio o la locutora
- **THEN** no usa el ámbar `#F5B841`

#### Scenario: El sistema pide tema claro
- **WHEN** el iPhone o el navegador están en modo claro
- **THEN** la app se sigue viendo en oscuro

### Requirement: Tipografías empaquetadas
La app SHALL usar Bricolage Grotesque para títulos y DM Sans para el resto, cargadas
desde los assets de la app y no desde la red.

#### Scenario: Sin conexión
- **WHEN** la app arranca sin internet
- **THEN** títulos y texto se ven con sus tipografías, no con las del sistema

### Requirement: Portada de reemplazo
Cuando un álbum no tenga imagen en Jellyfin, la app SHALL mostrar un bloque de color
con la inicial del álbum, con un color estable por álbum.

#### Scenario: Álbum sin portada
- **WHEN** Jellyfin no devuelve imagen para un álbum
- **THEN** se ve un bloque de color con la inicial, y el mismo álbum sale siempre del mismo color

### Requirement: Objetivos táctiles
Todo botón o elemento tocable SHALL medir al menos 44×44 px y los botones que solo
tienen icono SHALL llevar etiqueta de accesibilidad.

#### Scenario: Botón de pausa del mini reproductor
- **WHEN** VoiceOver enfoca el botón de pausa
- **THEN** lo anuncia como "Pausar"

