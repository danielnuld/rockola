## ADDED Requirements

### Requirement: Mezclas para ti
Inicio SHALL mostrar, debajo de "Volver a escuchar", la sección "Mezclas para ti" con
el texto "Armadas en tu equipo con lo que escuchas" y una fila de tarjetas (portada
de cuatro álbumes, nombre y artistas principales), que en la web pasa a cuadrícula.

#### Scenario: Abrir Inicio
- **WHEN** la biblioteca carga
- **THEN** se ven las tarjetas de las mezclas y tocar una abre su página dentro de Inicio

#### Scenario: Jellyfin no responde
- **WHEN** no se pueden traer las canciones
- **THEN** la sección no se muestra y el resto de Inicio sigue
