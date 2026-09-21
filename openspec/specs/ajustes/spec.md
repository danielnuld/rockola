# ajustes Specification

## Purpose
Los ajustes de la web: el servidor del locutor y dónde se guarda.
## Requirements
### Requirement: Servidor del locutor
En la web, Ajustes SHALL tener el campo "Servidor del locutor" (una URL), guardado en
el navegador, y un botón que lo prueba con `GET /locutor` y muestra el nombre de la
locutora o el error.

#### Scenario: Configurar
- **WHEN** se escribe `http://100.102.40.65:8787` y se prueba
- **THEN** se lee "Responde: Giulia" y la URL queda guardada

#### Scenario: Vacío
- **WHEN** el campo está vacío
- **THEN** la radio suena sin locutora y la pantalla de radio invita a configurarla

### Requirement: Dónde están los ajustes
Los ajustes SHALL abrirse desde la pantalla de radio y desde el lateral de la web.

#### Scenario: Desde la radio
- **WHEN** en la radio se toca el botón de ajustes
- **THEN** se abre Ajustes con el campo del servidor

### Requirement: Servidor de huellas
Ajustes SHALL tener el campo "Servidor de huellas" (una URL), en la web y en el iPhone,
guardado al escribir y con una prueba que pide una huella y dice si responde.

#### Scenario: Configurar
- **WHEN** se escribe `http://100.102.40.65:8788` y se prueba
- **THEN** se lee "Responde" y la URL queda guardada

#### Scenario: Vacío
- **WHEN** el campo está vacío
- **THEN** el visualizador usa la animación que no reacciona

