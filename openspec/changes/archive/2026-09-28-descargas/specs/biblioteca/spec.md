## ADDED Requirements

### Requirement: Filtro Descargado
En iOS la Biblioteca SHALL tener un tercer filtro, Descargado, que lista los álbumes
descargados a partir del índice local, sin consultar a Jellyfin. Las filas de álbumes
descargados SHALL llevar el indicador coral en cualquier filtro.

#### Scenario: Filtrar lo descargado
- **WHEN** hay dos álbumes descargados y se toca Descargado
- **THEN** la lista muestra esos dos y el total dice "2 álbumes"

#### Scenario: Indicador
- **WHEN** Room on Fire está descargado y se mira el filtro Álbumes
- **THEN** su fila lleva el indicador coral junto a "Álbum · The Strokes"
