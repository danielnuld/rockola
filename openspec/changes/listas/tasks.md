## 1. Cliente de Jellyfin

- [x] 1.1 `listas()`, `cancionesDeLista(id)` (con `PlaylistItemId`), `crearLista(nombre, ids)`, `anadirALista(id, ids)`, `quitarDeLista(id, entradas)`, `moverEnLista(id, entrada, i)`, `renombrarLista(id, nombre)`, `borrarLista(id)`
- [x] 1.2 Rutas de `/Playlists` en el Jellyfin falso de los tests, con estado (las listas viven mientras dura el test)

## 2. Añadir a una lista

- [x] 2.1 `lib/listas.dart`: hoja "Añadir a una lista" con "Nueva lista…" y las listas del usuario; aviso al terminar
- [x] 2.2 `MenuCancion` en las filas de álbum, búsqueda, mezcla y lista, y en el reproductor; "Añadir el álbum a una lista" en el álbum
- [x] 2.3 Test de widget: añadir Reptilia a una lista nueva y a una existente

## 3. Biblioteca y página de lista

- [x] 3.1 Filtro Listas con "Nueva lista" y el estado vacío
- [x] 3.2 `ListaPage`: portada, nombre, canciones y duración, reproducir, aleatorio, la que suena en coral
- [x] 3.3 Reordenar arrastrando, quitar, renombrar y borrar con confirmación; optimista con vuelta atrás
- [x] 3.4 Tests de widget: reordenar llama a mover con la entrada y el índice correctos; un quitar que falla vuelve atrás; borrar la quita de la Biblioteca

## 4. Descargar una lista (iPhone)

- [x] 4.1 `BotonDescarga` en `ListaPage` con la lista como item; `ListaPage` cae al índice sin red
- [x] 4.2 Test: una lista descargada se abre con Jellyfin caído

## 5. Cierre

- [x] 5.1 `flutter analyze` y `flutter test` en verde
- [ ] 5.2 En Chrome con la sesión de Daniel: crear, añadir, reordenar, renombrar, quitar y borrar, y comprobar en Jellyfin que queda igual (mover y renombrar no se pudieron probar con la clave del servidor)
- [x] 5.3 IPA compilado
- [ ] 5.4 En el lienzo, el filtro Listas y el menú por canción si hace falta
