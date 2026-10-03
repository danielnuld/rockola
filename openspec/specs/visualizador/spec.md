# visualizador Specification

## Purpose
TBD - created by archiving change visualizador. Update Purpose after archive.
## Requirements
### Requirement: Abrir el visualizador
El Reproductor SHALL tener un botón "Visualizador" que abre una pantalla completa con
la visualización de la canción que suena, su título y artista discretos abajo, y que se
cierra tocando la flecha o con el gesto de volver.

#### Scenario: Abrir
- **WHEN** suena una canción y se toca "Visualizador"
- **THEN** se ve la visualización a pantalla completa, moviéndose

### Requirement: Sincronizado con la música
La visualización SHALL tomar en cada fotograma el cuadro de la huella que corresponde a
la posición de reproducción, interpolando entre cuadros, y SHALL quedarse quieta con la
música en pausa.

#### Scenario: Saltar en la canción
- **WHEN** se arrastra la canción al minuto 2
- **THEN** la visualización sigue desde la huella del minuto 2

#### Scenario: Pausa
- **WHEN** se pausa la música
- **THEN** la visualización se detiene en ese cuadro

### Requirement: Cuatro estilos
SHALL haber cuatro estilos: **Barras** (las 16 bandas con picos que caen), **Ambiente**
(una forma de color que respira y se deforma con las bandas), **Batería** (anillos que
giran y chispas con los graves) y **Ondas** (círculos que nacen del centro con cada
golpe de graves). Tocar la pantalla SHALL pasar al siguiente y mostrar su nombre un
momento; el elegido SHALL recordarse.

#### Scenario: Cambiar de estilo
- **WHEN** en Barras se toca la pantalla
- **THEN** pasa a Ambiente y se lee "Ambiente"

#### Scenario: Volver a abrir
- **WHEN** se cierra en Ondas y se vuelve a abrir
- **THEN** abre en Ondas

### Requirement: Sin huella
Sin servidor de huellas configurado, o si no responde y la canción no está descargada,
la visualización SHALL moverse con un patrón suave que no depende de la música, sin
mostrar errores.

#### Scenario: Sin servidor
- **WHEN** no hay servidor de huellas en Ajustes
- **THEN** el visualizador se abre y se mueve igual, sin reaccionar a la música

### Requirement: Huella sin conexión
Al descargar un álbum o una lista SHALL guardarse también la huella de cada canción:
la del servidor de huellas si está configurado y responde y, si no, en iOS, la
calculada en el teléfono a partir del archivo descargado, con el mismo formato. Sin
conexión SHALL usarse esa. Si no se consigue ninguna, la canción SHALL quedar descargada
igual.

#### Scenario: Modo avión
- **WHEN** suena sin red una canción descargada con su huella
- **THEN** el visualizador reacciona a la música igual que con red

#### Scenario: Descarga sin servidor de huellas
- **WHEN** en el iPhone se descarga un álbum sin servidor de huellas en Ajustes
- **THEN** cada canción queda con su huella y el visualizador reacciona a la música sin red

#### Scenario: Servidor que no responde
- **WHEN** el servidor de huellas configurado no responde al descargar
- **THEN** la huella se calcula en el teléfono y la descarga termina bien

#### Scenario: Formato que no se abre
- **WHEN** la canción descargada es un formato que el iPhone no decodifica
- **THEN** queda descargada sin huella y el visualizador usa el patrón suave

