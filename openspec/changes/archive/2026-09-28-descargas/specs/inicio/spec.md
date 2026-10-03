## ADDED Requirements

### Requirement: Chips de Inicio
En iOS, Inicio SHALL tener los chips Todo (predeterminado) y Descargado. Con
Descargado, "Volver a escuchar" SHALL dejar solo los álbumes descargados, y si no hay
ninguno SHALL decir que todavía no hay descargas.

#### Scenario: Solo lo descargado
- **WHEN** se toca Descargado y de los recientes solo Room on Fire está descargado
- **THEN** "Volver a escuchar" muestra solo Room on Fire

#### Scenario: Nada descargado
- **WHEN** se toca Descargado sin ningún álbum descargado
- **THEN** se lee "Todavía no has descargado nada"
