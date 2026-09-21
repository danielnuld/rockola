# huellas Specification

## Purpose
TBD - created by archiving change visualizador. Update Purpose after archive.
## Requirements
### Requirement: La huella de una canción
El servicio SHALL describir cada canción con 16 bandas de frecuencia logarítmicas
entre 40 Hz y 11 kHz, 20 veces por segundo, cada valor en un byte (0–255) normalizado
por banda dentro de esa canción, y SHALL devolverla como
`{"fps": 20, "bandas": 16, "cuadros": n, "datos": "<n×16 bytes en base64>"}`.

#### Scenario: Una canción real
- **WHEN** se pide la huella de Reptilia (3:41)
- **THEN** llegan ~4400 cuadros de 16 bandas, unos 69 KB de datos

#### Scenario: Un tono puro
- **WHEN** se calcula la huella de un tono de 1 kHz
- **THEN** la banda que contiene 1 kHz es la más alta en casi todos los cuadros

### Requirement: Servir y guardar
`GET /huella/{id}` SHALL devolver la huella de esa canción de Jellyfin; si no está
guardada, SHALL calcularla desde el archivo, guardarla y devolverla. Un id que Jellyfin
no conoce SHALL dar 404.

#### Scenario: Primera vez
- **WHEN** se pide una canción que nunca se calculó
- **THEN** responde en unos segundos y queda guardada

#### Scenario: Id desconocido
- **WHEN** se pide un id que no existe en Jellyfin
- **THEN** responde 404

### Requirement: Toda la biblioteca de una vez
`huellas.py --todas` SHALL calcular y guardar la huella de cada canción de Jellyfin que
no la tenga, informando el avance, y un fallo en una canción SHALL no parar el resto.

#### Scenario: Biblioteca entera
- **WHEN** se corre `--todas` en `nuld`
- **THEN** al terminar hay una huella por canción y un resumen de cuántas fallaron

### Requirement: Acceso
El servicio SHALL escuchar en `127.0.0.1` y en la IP de Tailscale, y mandar CORS solo a
los orígenes configurados, como el núcleo de Giulia.

#### Scenario: Desde Chrome
- **WHEN** Rockola web en `http://localhost:5000` pide una huella
- **THEN** el navegador puede leer la respuesta

