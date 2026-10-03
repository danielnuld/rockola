# listas Specification

## Purpose
Listas de reproducción de Jellyfin: crearlas, llenarlas, editarlas y descargarlas.
## Requirements
### Requirement: Crear una lista
"Nueva lista" SHALL pedir un nombre y crear la lista en Jellyfin, vacía o ya con las
canciones desde las que se pidió.

#### Scenario: Desde la Biblioteca
- **WHEN** en el filtro Listas se toca "Nueva lista" y se escribe "Para correr"
- **THEN** aparece "Para correr" en la lista con 0 canciones

#### Scenario: Desde una canción
- **WHEN** en "Añadir a una lista" de Reptilia se elige "Nueva lista…" y se escribe "Para correr"
- **THEN** se crea "Para correr" con Reptilia dentro

#### Scenario: Sin nombre
- **WHEN** se confirma con el nombre vacío
- **THEN** no se crea nada

### Requirement: Añadir a una lista
Cada canción del álbum, de la búsqueda, de una mezcla, de otra lista y la que suena
en el reproductor SHALL tener "Añadir a una lista"; el álbum SHALL tener "Añadir el
álbum a una lista". La hoja SHALL ofrecer "Nueva lista…" y las listas existentes, y
confirmar con un aviso breve.

#### Scenario: Añadir una canción
- **WHEN** se añade Reptilia a "Para correr"
- **THEN** "Para correr" termina con Reptilia y se lee "Añadida a Para correr"

#### Scenario: Añadir un álbum
- **WHEN** se añade Room on Fire a "Para correr"
- **THEN** se añaden sus 11 canciones en su orden

### Requirement: Página de lista
Tocar una lista SHALL abrir su página con portada, nombre, número de canciones y
duración, reproducir, aleatorio y las canciones en su orden, con la que suena en
coral.

#### Scenario: Reproducir una lista
- **WHEN** se toca reproducir en "Para correr"
- **THEN** suena la lista desde la primera canción

### Requirement: Editar una lista
En la página de lista SHALL poder reordenarse arrastrando, quitar una canción,
renombrar la lista y borrarla (con confirmación). Cada cambio SHALL guardarse en
Jellyfin, y si Jellyfin lo rechaza, la lista SHALL volver a como estaba con un aviso.

#### Scenario: Reordenar
- **WHEN** se arrastra la tercera canción al principio
- **THEN** Jellyfin la tiene primera y la página también

#### Scenario: Falla al quitar
- **WHEN** se quita una canción y Jellyfin responde con error
- **THEN** la canción vuelve a su sitio y aparece un aviso

#### Scenario: Borrar
- **WHEN** se borra "Para correr" y se confirma
- **THEN** desaparece de la Biblioteca y de Jellyfin

### Requirement: Descargar una lista
En el iPhone, la página de lista SHALL tener el mismo botón de descarga que un álbum,
y una lista descargada SHALL abrirse y sonar sin conexión.

#### Scenario: Sin conexión
- **WHEN** "Para correr" está descargada y no hay red
- **THEN** se abre con sus canciones y suenan del teléfono

