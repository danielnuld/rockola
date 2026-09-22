# Servidor de huellas

El visualizador no puede escuchar el audio: ni just_audio en el navegador ni
AVPlayer en el iPhone entregan las muestras. Así que cada canción se analiza una
vez en el servidor y la app anima esa **huella** con la posición de reproducción.
Es opcional: sin servidor, el visualizador pinta un patrón sintético.

## Contrato

`GET /huella/{id}`, donde `{id}` es el id de Jellyfin de la canción (32 hex).

```json
{"fps": 20, "bandas": 16, "cuadros": 4433, "datos": "<base64>"}
```

- `datos` son `cuadros × bandas` bytes, cuadro por cuadro. El cuadro `i`
  corresponde al segundo `i / fps`.
- Bandas logarítmicas de 40 Hz a 11 kHz, graves primero. Cada banda va de 0 a
  255 normalizada **dentro de la canción** (del percentil 5 al 99.5), para que los
  graves no tapen a los agudos.
- `404` si Jellyfin no conoce la canción; `503` si no se pudo calcular.
- Con `Origin`, CORS solo para los orígenes de la lista.

Una canción de 3:40 son ~70 KB (~95 KB en JSON).

## Montarlo (`servidor/huellas.py`)

Solo stdlib, numpy y ffmpeg. Lee el archivo de audio directo del disco, así que
tiene que correr en la máquina de Jellyfin y ver la biblioteca en la misma ruta.

| Variable | Qué |
|---|---|
| `JELLYFIN_URL`, `JELLYFIN_API_KEY` | para preguntar la ruta del archivo |
| `HUELLAS_DIR` | caché, `<id>.json`; se rehace con `--todas`, no hace falta respaldarla |
| `HUELLAS_PUERTO` | 8788 |
| `HUELLAS_TAILSCALE` | IP extra donde escuchar, además de 127.0.0.1 |
| `HUELLAS_ORIGENES` | orígenes web permitidos, separados por comas |

```sh
python3 huellas.py --check   # autocomprobación
python3 huellas.py --todas   # toda la biblioteca de una vez (~1 s por canción)
python3 huellas.py           # servidor; lo nuevo se calcula al pedirlo
```

Si el archivo cambia de tamaño, la huella se recalcula. `huellas.service` es un
ejemplo de unidad de systemd: cambia el usuario, las rutas y la IP antes de instalarla.
