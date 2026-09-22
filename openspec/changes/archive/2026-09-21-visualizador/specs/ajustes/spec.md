## ADDED Requirements

### Requirement: Servidor de huellas
Ajustes SHALL tener el campo "Servidor de huellas" (una URL), en la web y en el iPhone,
guardado al escribir y con una prueba que pide una huella y dice si responde.

#### Scenario: Configurar
- **WHEN** se escribe `http://tu-servidor:8788` y se prueba
- **THEN** se lee "Responde" y la URL queda guardada

#### Scenario: Vacío
- **WHEN** el campo está vacío
- **THEN** el visualizador usa la animación que no reacciona
