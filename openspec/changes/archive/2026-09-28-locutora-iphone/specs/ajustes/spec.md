## MODIFIED Requirements

### Requirement: Servidor del locutor
En la web, Ajustes SHALL tener el campo "Servidor del locutor" (una URL), guardado en
el navegador, y un botón que lo prueba con `GET /locutor` y muestra el nombre de la
locutora o el error. En el iPhone el campo SHALL no aparecer: allí la locutora es la
del teléfono.

#### Scenario: Configurar
- **WHEN** se escribe `http://tu-servidor:8787` y se prueba
- **THEN** se lee "Responde: <nombre del locutor>" y la URL queda guardada

#### Scenario: Vacío
- **WHEN** el campo está vacío
- **THEN** la radio suena sin locutora y la pantalla de radio invita a configurarla

#### Scenario: En el iPhone
- **WHEN** se abre Ajustes en el iPhone
- **THEN** no está el campo del servidor del locutor; sí el de huellas

## ADDED Requirements

### Requirement: Voz de la locutora del iPhone
En el iPhone, Ajustes SHALL listar las voces en español instaladas (nombre, región y
calidad), con un botón para oír cada una y "Automática" (la mejor instalada) como
opción por defecto. La voz elegida SHALL usarse desde la siguiente entrada y la
locutora SHALL llamarse como ella. Si la elegida deja de estar instalada, SHALL
usarse la automática.

#### Scenario: Elegir voz
- **WHEN** se toca "Jorge" en la lista
- **THEN** queda marcada, la siguiente entrada suena con Jorge y la radio se presenta como Jorge

#### Scenario: Oír antes de elegir
- **WHEN** se toca ▶ junto a una voz
- **THEN** esa voz dice una frase de muestra, sin cambiar la elegida
