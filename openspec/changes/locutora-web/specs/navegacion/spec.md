## MODIFIED Requirements

### Requirement: Cuatro pestañas
La app SHALL tener cuatro pestañas: Inicio, Buscar, Biblioteca y Radio, con Inicio
elegida al abrir.

#### Scenario: Abrir la app con sesión
- **WHEN** la app arranca con una sesión de Jellyfin guardada
- **THEN** muestra la pestaña Inicio

#### Scenario: Pestañas aún vacías
- **WHEN** se elige Radio en el iPhone
- **THEN** se ve un estado vacío que dice que la radio llega pronto, sin errores; en la web se ve la radio
