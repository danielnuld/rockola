## Context

Medido en el Jellyfin de `nuld` (622 canciones):
- 12 escuchadas, 15 reproducciones, 0 favoritas. Rockola no avisa de nada.
- Géneros: Rock 163, sin género 116, Pop 48, Hip Hop 40, Pop Rap 31, Alternative 30,
  Hispanic Hip Hop 24, Blues Rock 24, Gangsta Rap 18, Rap/Hip Hop 18, Hip-Hop/Rap 18…
- Décadas: 2010 159, 2000 147, 1970 94, 1990 60, 2020 58, 1980 46, 1960 43, sin año 15.
- `POST /Users/{u}/PlayedItems/{id}` sube el contador **solo la primera vez**: la
  segunda deja `PlayCount` en 1 porque la canción ya está marcada.
- `POST /Sessions/Playing` + `/Sessions/Playing/Stopped` responden 204, pero con la
  clave de API del servidor no cuentan: esa clave no es de ningún usuario. Con la
  sesión de un usuario es lo que usan los clientes oficiales; queda por comprobar con
  la de Daniel (tarea 1.4).
- `InstantMix` existe (200).

## Goals / Non-Goals

**Goals:** que el historial se llene usando Rockola, y mezclas que sirvan desde el
primer día y mejoren con el uso.

**Non-Goals:** mezclas sin red (fase 6), modelos o embeddings, arreglar etiquetas.

## Decisions

**Avisos por sesión (`/Sessions/Playing` y `/Stopped`), no `PlayedItems`.** Este último
no cuenta repeticiones (ver Context), y las mezclas viven de esa cuenta. Con los
avisos de sesión Jellyfin aplica su criterio de "escuchada" (90 %) igual que con
Finamp o su web, así una misma biblioteca cuenta igual la use quien la use.

**Un observador aparte, `Escuchas`, no el `Player`.** Escucha `player.mediaItem` y
`player.playbackState`: al cambiar de canción manda el fin de la anterior con su
última posición y el inicio de la nueva; si la posición anterior era menor de 30 s
y no terminó, suma un salto. Así el `Player` sigue sin saber de Jellyfin, y en los
tests se prueba con un `BaseAudioHandler` y un Jellyfin falso.

**Pendientes y saltos en `SharedPreferences`.** Los fines que fallan se guardan como
lista y se reintentan antes del siguiente aviso y al arrancar; los saltos son un
mapa id → cuenta. Es lo que ya se usa para la sesión y funciona igual en web e iOS.

**Mezclas en el equipo, no `InstantMix`.** `InstantMix` es de Jellyfin y está a mano,
pero se calcula en el servidor: la radio del iPhone (fase 6) la necesita sin red, y
no sabe de los saltos, que solo están en el equipo. Además el algoritmo es una
función pura sobre una lista, que se prueba sin red y se reutiliza con lo descargado.

**Familias de género por palabras clave.** Una tabla corta: contiene "rap" o "hip"
→ Rap; "rock", "alternative", "grunge", "punk" → Rock; "pop" → Pop; "electr",
"house", "techno" → Electrónica; "regional", "banda", "norteñ", "cumbia" → Regional
mexicano. Orden de la tabla = prioridad ("Pop Rap" es Rap). Lo que no encaja queda
con su nombre. `ponytail:` con el techo: si la tabla crece a cada rato, se pasa a los
géneros de MusicBrainz.

**Peso de cada canción: `1 + 2·escuchas + 3·favorita − 2·saltos`, mínimo 0.2**, y
fuera si tiene 3 saltos o más y ninguna escucha. Elección al azar ponderada sin
repetir, con `Random` sembrado por la fecha (año·10000 + mes·100 + día): mismo día,
mismas mezclas. Tope de 3 por artista y 25 por mezcla; después una pasada que separa
canciones seguidas del mismo artista cuando hay con qué.

**Qué mezclas.** Dos familias y dos décadas con más peso, "Lo más tuyo: <artista>"
(solo por escuchas) si las hay, y "Lo que casi no tocas" (sin escuchas, de las dos
familias con más peso). Nombres de década: Sesentera, Setentera, Ochentera,
Noventera, Dosmilera, "De los 2010", "De ahora"; en la descripción, en palabras
("los ochenta").

**Corregido al probar con la biblioteca real** (antes se pesaba solo por escuchas y
con tope fijo de 3):
- Peso de un grupo = canciones + 5 × escuchas. Con 15 escuchas en total, pesar solo
  por escuchas ponía "Ochentera" (AC/DC, 5 escuchas) por delante de "Dosmilera", que
  tiene tres veces más canciones: eso era azar, no gusto.
- Tope por artista = `max(3, ⌈25 / artistas⌉)`. Con tope fijo, "Mezcla de rap" se
  quedaba en 6 canciones porque el rap de la biblioteca es casi todo de dos artistas.
- La misma canción en dos discos cuenta una vez ("Dreams" salía dos veces).
Resultado: seis mezclas de 25 canciones, con las dos décadas más grandes (2010, 2000).

**Todas las canciones en una consulta** (`Fields=Genres,ProductionYear`, con
`UserData`), guardada en el `Armazon` como el resto de lo que se pide una vez por
sesión; las mezclas se calculan de ahí.

## Risks / Trade-offs

- [Sin comprobar que los avisos cuenten con la sesión de Daniel] → Tarea 1.4 lo mira
  contra `nuld` antes de seguir; si no cuenta, el plan B es `PlayedItems` para la
  primera escucha y la cuenta de repeticiones en local.
- [Con el historial vacío las mezclas son de género y década, sin gusto personal] →
  Es lo mejor que se puede con cero datos; mejoran en cuanto Rockola avisa.
- [116 canciones sin género nunca entran en mezclas de género] → Sí en las de
  década y en "Lo más tuyo".
- [Una sola consulta con todas las canciones] → Con 622 es inmediata; con decenas
  de miles se pagina o se cachea en disco.
