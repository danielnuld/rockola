## ADDED Requirements

### Requirement: Filtro Listas
La Biblioteca SHALL tener el filtro Listas, entre Artistas y Mezclas, con las listas
de Jellyfin como filas ("Lista · <n> canciones") y "Nueva lista" arriba.

#### Scenario: Ver las listas
- **WHEN** se toca Listas
- **THEN** se ven las listas del usuario y tocar una abre su página

#### Scenario: Ninguna lista
- **WHEN** no hay listas
- **THEN** se lee "Todavía no tienes listas" y "Nueva lista" sigue disponible
