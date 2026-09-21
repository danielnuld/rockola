## ADDED Requirements

### Requirement: Buscar mientras se escribe
La pestaña Buscar SHALL tener un campo que busca en Jellyfin artistas, álbumes y
canciones cuando se deja de escribir 300 ms, con al menos dos letras.

#### Scenario: Buscar un artista
- **WHEN** se escribe "strokes"
- **THEN** aparece The Strokes en Artistas

#### Scenario: Una sola letra
- **WHEN** el campo tiene una letra
- **THEN** no se consulta a Jellyfin y no se muestra nada

#### Scenario: Escribir rápido
- **WHEN** se teclea "cartel" letra por letra sin pausas
- **THEN** se hace una sola consulta, con "cartel"

### Requirement: Resultados agrupados
Los resultados SHALL agruparse en Artistas, Álbumes y Canciones, en ese orden, omitiendo
los grupos vacíos. Tocar un artista o un álbum SHALL abrir su página dentro de Buscar;
tocar una canción SHALL reproducir las canciones del resultado desde esa.

#### Scenario: Resultados mixtos
- **WHEN** se busca "cartel" y Jellyfin devuelve un artista y dos canciones
- **THEN** se ven los grupos Artistas y Canciones, y no el de Álbumes

#### Scenario: Sin resultados
- **WHEN** la búsqueda no encuentra nada
- **THEN** se lee "Nada con «<texto>» en tu biblioteca"
