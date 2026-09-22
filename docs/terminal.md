# Rockola en la terminal

Para equipos donde Chrome con la versión web pesa demasiado: búsqueda, mezclas del
día y la radio con locutora, con la letra y el visualizador de barras. Gasta ~20 MB y
casi nada de CPU; mpv, que es quien suena, unos 75 MB.

## Montarlo (Windows)

```sh
winget install shinchiro.mpv                    # el reproductor
dart build cli -t bin/rockola.dart -o build/cli # desde la raíz del repo
```

El ejecutable queda en `build/cli/bundle/bin/rockola.exe`; se puede copiar donde se
quiera. `dart compile exe` no sirve en este repo (lo frenan los build hooks de una
dependencia de iOS): hay que usar `dart build cli`.

mpv se busca en el PATH y en `C:\Program Files\MPV Player\` (donde lo deja winget).
Si está en otro lado, su ruta va en `"mpv"` del archivo de configuración.

## Configuración

Un JSON escrito a mano. Rockola lo busca en este orden:

1. `rockola.json` junto a `rockola.exe`: para llevarlo en una memoria a otro PC. No
   en `build/cli/…`: `dart build cli` vacía esa carpeta cada vez que compila.
2. `%APPDATA%\Rockola\config.json`.

```json
{
  "url": "http://100.102.40.65:8096",
  "usuario": "daniel",
  "huellas": "http://100.102.40.65:8788",
  "locutor": "http://100.102.40.65:8787"
}
```

`huellas` (el visualizador sigue la música), `locutor` (la radio habla) y `mpv` son
opcionales. La primera vez pide la contraseña y añade al mismo archivo solo el `token`
y el `usuarioId`, nunca la contraseña. Si la sesión se cierra en Jellyfin, Rockola
borra el token y la vuelve a pedir.

## Uso

`rockola` abre la interfaz: la barra lateral (Inicio, Buscar, Biblioteca, Mezclas,
Listas, Radio, Cola), la lista en el centro y abajo lo que suena, con un visualizador
de una línea y la letra.

| Comando | Abre en |
|---|---|
| `rockola` | Inicio: mezclas del día y álbumes recientes |
| `rockola <búsqueda>` | Buscar, con los resultados de eso |
| `rockola mezclas` | Mezclas |
| `rockola radio` | Radio, ya sintonizando |

`--ascii` en cualquiera: sin color ni símbolos Unicode, para consolas viejas.

| Tecla | |
|---|---|
| ↑ ↓ (o `k` `j`), RePág AvPág | mover |
| Enter | abrir (un álbum, una mezcla) o tocar (una canción: sigue el resto) |
| Tab | pasar entre la barra lateral y la lista |
| Esc | atrás |
| `/` | buscar: se escribe, Enter busca, Esc cancela |
| espacio | pausa |
| `n` / `p` | siguiente / anterior |
| ← / → | 10 s atrás / adelante |
| `v` | visualizador a pantalla completa (`v` o Esc para volver) |
| `a` | color o ASCII |
| `q` o Ctrl+C | salir |

En Radio, Enter en «Sintonizar» arma una hora de radio de las mezclas, con la locutora
entre canciones; «Cambiar el rumbo», otra con otras canciones. En Cola, Enter salta a
esa canción.

Sin servidor de huellas, las barras se mueven con un patrón que no sigue la música. Sin
servidor del locutor, la radio suena solo con música.

Si se cierra la ventana mientras suena, mpv se cierra solo a los ~6 s.
