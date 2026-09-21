## ADDED Requirements

### Requirement: Avisar a Jellyfin de lo que suena
La app SHALL avisar a Jellyfin, con la sesión del usuario, cuando empieza una canción
y hasta dónde sonó cuando se deja (cambio de canción, fin, pausa larga o cierre).
Jellyfin decide si cuenta como escuchada con su propio criterio (por defecto, pasar
del 90 %), igual que con sus clientes oficiales, y entonces sube su contador y su
fecha de última escucha.

#### Scenario: Canción entera
- **WHEN** Reptilia suena hasta el final y empieza la siguiente
- **THEN** Jellyfin recibe el fin de Reptilia con su duración completa y su contador sube en uno

#### Scenario: Se deja a medias
- **WHEN** Reptilia se cambia a 1:20
- **THEN** Jellyfin recibe el fin en 1:20 y no la cuenta como escuchada

#### Scenario: Repetir la misma canción
- **WHEN** Reptilia suena entera dos veces seguidas con repetir una
- **THEN** Jellyfin recibe dos inicios y dos fines, y su contador sube en dos

### Requirement: Avisos sin conexión
Si un aviso de fin no llega a Jellyfin, SHALL guardarse y reintentarse en el
siguiente aviso o al abrir la app, sin perderse ni duplicarse.

#### Scenario: En modo avión
- **WHEN** se escuchan tres canciones descargadas en modo avión y después vuelve la red
- **THEN** al siguiente aviso Jellyfin recibe los tres fines

### Requirement: Saltos
Una canción que se deja antes de los 30 segundos sin haber terminado SHALL contarse
como saltada en un registro local del equipo.

#### Scenario: Saltar
- **WHEN** suena una canción 12 segundos y se pasa a la siguiente
- **THEN** su cuenta de saltos sube en uno
