# Servidor del locutor

Rockola web no genera la voz de la radio: se la pide a un **servidor del locutor**
que el usuario pone en Ajustes. Así ninguna clave de API vive en el navegador, y
cada quien usa el modelo y la voz que quiera. Sin servidor, la radio suena igual,
solo sin locutor.

En el iPhone no se usa: allí la locutora corre en el propio teléfono.

## `GET /locutor`

```json
{"nombre": "Giulia"}
```

El nombre con el que la radio presenta al locutor.

## `POST /locutor`

Pide la entrada que va entre dos canciones.

```json
{
  "antes":   {"titulo": "Reptilia", "artista": "The Strokes", "album": "Room on Fire", "anio": 2003, "escuchas": 11},
  "despues": {"titulo": "Proud Mary", "artista": "Creedence Clearwater Revival", "anio": 1969, "escuchas": 0},
  "charla":  "normal"
}
```

- `antes` es `null` en la entrada que abre la radio.
- `despues` es obligatorio y necesita `titulo`. El resto de campos puede faltar.
- `escuchas` son las de antes de hoy, según Jellyfin.
- `charla` es `"normal"` (una o dos frases) o `"poca"` (una).

Respuesta:

```json
{"texto": "Eso fue Reptilia… sigue Proud Mary.", "audio": "<OGG/Opus en base64>", "formato": "audio/ogg"}
```

- `audio` puede ser `null` si el servidor no tiene voz; entonces Rockola no inserta la entrada.
- `400` si falta `despues`; `503` si el modelo no pudo hablar.

## CORS

El navegador llama desde el origen donde corre Rockola (por ejemplo
`http://localhost:5000`): el servidor tiene que contestar el preflight `OPTIONS` y
mandar `Access-Control-Allow-Origin` para ese origen.

## Qué hace Rockola

- Pide cada entrada al empezar la canción anterior y espera hasta 60 s.
- Si llega cuando ya empezó la canción que debía presentar, la descarta.
- Si falla o no responde, sigue la música sin locutor.
- La entrada de apertura espera como mucho 8 s antes de empezar la música.

La implementación de referencia es la de Giulia, en `danielnuld/jarvis-m710q`
(`bot/jarvis.py`, `locutor()`).
