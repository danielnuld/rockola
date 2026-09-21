## MODIFIED Requirements

### Requirement: Cuatro pestañas
La app SHALL tener cuatro pestañas: Inicio, Buscar, Biblioteca y Radio, con Inicio
elegida al abrir.

#### Scenario: Abrir la app con sesión
- **WHEN** la app arranca con una sesión de Jellyfin guardada
- **THEN** muestra la pestaña Inicio

#### Scenario: Pestaña aún vacía
- **WHEN** se elige Radio
- **THEN** se ve un estado vacío que dice qué habrá ahí, sin errores
