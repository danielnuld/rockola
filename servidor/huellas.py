#!/usr/bin/env python3
"""Huellas de Rockola: lo que el visualizador sabe de cada cancion.

16 bandas de frecuencia, 20 veces por segundo, un byte por valor. La app las
anima con la posicion de reproduccion: ni just_audio en el navegador ni AVPlayer
en el iPhone entregan las muestras de audio. Contrato en docs/huellas.md.

    python3 huellas.py            # servidor (GET /huella/{id})
    python3 huellas.py --todas    # calcula toda la biblioteca de Jellyfin
    python3 huellas.py --check    # autocomprobacion, sin red ni Jellyfin

Medido en un i5-6500T: 0.8 s y 69 KB por cancion de 3:40.
"""
import base64
import http.server
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np

TASA = 22050      # Hz: hasta 11 kHz, de sobra para ver musica
FPS = 20          # cuadros por segundo
BANDAS = 16
N = 2048          # tamano de la FFT (93 ms a 22 kHz)

JELLYFIN = os.environ.get("JELLYFIN_URL", "http://localhost:8096").rstrip("/")
CLAVE = os.environ.get("JELLYFIN_API_KEY", "")
DIR = Path(os.environ.get("HUELLAS_DIR", "/srv/data/huellas"))
PUERTO = int(os.environ.get("HUELLAS_PUERTO", "8788"))
# Ademas de 127.0.0.1, la IP de Tailscale: nunca 0.0.0.0, que seria tambien la LAN.
TAILSCALE = os.environ.get("HUELLAS_TAILSCALE", "")
ORIGENES = [o.strip() for o in os.environ.get("HUELLAS_ORIGENES", "").split(",") if o.strip()]


def bandas_db(x):
    """Cuadros x BANDAS en dB, de audio mono a TASA Hz (floats en [-1, 1])."""
    paso = TASA // FPS
    if len(x) < N:
        x = np.pad(x, (0, N - len(x)))
    cuadros = (len(x) - N) // paso + 1
    idx = np.arange(N)[None, :] + paso * np.arange(cuadros)[:, None]
    esp = np.abs(np.fft.rfft(x[idx] * np.hanning(N), axis=1))
    frec = np.fft.rfftfreq(N, 1 / TASA)
    bordes = np.geomspace(40, 11000, BANDAS + 1)  # logaritmicas, como el oido
    bandas = np.stack([esp[:, (frec >= a) & (frec < b)].mean(axis=1) for a, b in zip(bordes, bordes[1:])], axis=1)
    return 20 * np.log10(bandas + 1e-6)


def huella_de_pcm(x):
    db = bandas_db(x)
    cuadros = len(db)
    # Por banda, del 5 % al 99.5 % de esta cancion: asi los graves no tapan los agudos.
    lo, hi = np.percentile(db, 5, axis=0), np.percentile(db, 99.5, axis=0)
    q = np.clip((db - lo) / np.maximum(hi - lo, 1e-3), 0, 1)
    datos = (q * 255).astype(np.uint8).tobytes()
    return {"fps": FPS, "bandas": BANDAS, "cuadros": int(cuadros), "datos": base64.b64encode(datos).decode()}


def huella(archivo):
    pcm = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(archivo), "-ac", "1", "-ar", str(TASA), "-f", "s16le", "-"],
        capture_output=True, check=True, timeout=300,
    ).stdout
    return huella_de_pcm(np.frombuffer(pcm, np.int16).astype(np.float32) / 32768)


def jellyfin(ruta, **query):
    url = f"{JELLYFIN}{ruta}?" + urllib.parse.urlencode({**query, "api_key": CLAVE})
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)


def archivo_de(item_id):
    """(ruta, tamano) del archivo de una cancion, o None si Jellyfin no la conoce.

    La biblioteca esta en la misma ruta dentro y fuera del contenedor de Jellyfin.
    """
    items = jellyfin("/Items", Ids=item_id, Fields="Path")["Items"]
    if not items or not items[0].get("Path"):
        return None
    ruta = Path(items[0]["Path"])
    return (ruta, ruta.stat().st_size) if ruta.exists() else None


_cerrojos = {}
_cerrojo = threading.Lock()


def obtener(item_id, ruta=None, tamano=None):
    """La huella guardada si el archivo no cambio de tamano; si no, se calcula y guarda."""
    if ruta is None:
        encontrado = archivo_de(item_id)
        if encontrado is None:
            return None
        ruta, tamano = encontrado
    # Un cerrojo por cancion: dos peticiones a la vez no la calculan dos veces.
    with _cerrojo:
        cerrojo = _cerrojos.setdefault(item_id, threading.Lock())
    with cerrojo:
        f = DIR / f"{item_id}.json"
        if f.exists():
            guardada = json.loads(f.read_text())
            if guardada.get("tamano") == tamano:
                return guardada["huella"]
        h = huella(ruta)
        DIR.mkdir(parents=True, exist_ok=True)
        tmp = f.with_suffix(".tmp")
        tmp.write_text(json.dumps({"tamano": tamano, "huella": h}))
        tmp.rename(f)
        return h


def origen_permitido(origen, lista):
    return origen if origen and origen in lista else None


ID = re.compile(r"^/huella/([0-9a-f]{32})/?$")


class Huellas(http.server.BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(204)
        self.cors()
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Max-Age", "600")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        m = ID.match(self.path)
        if not m:
            return self.contestar(404, {"error": "no existe"})
        try:
            h = obtener(m[1])
        except Exception as e:
            print(f"huella {m[1]}: {e}", file=sys.stderr, flush=True)
            return self.contestar(503, {"error": "no pude calcularla"})
        self.contestar(200, h) if h else self.contestar(404, {"error": "Jellyfin no conoce esa cancion"})

    def contestar(self, codigo, datos):
        cuerpo = json.dumps(datos).encode()
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(cuerpo)))
        # Se guardan en el navegador: una huella no cambia mientras no cambie el archivo.
        if codigo == 200:
            self.send_header("Cache-Control", "max-age=86400")
        self.cors()
        self.end_headers()
        self.wfile.write(cuerpo)

    def cors(self):
        origen = origen_permitido(self.headers.get("Origin"), ORIGENES)
        if origen:
            self.send_header("Access-Control-Allow-Origin", origen)
            self.send_header("Vary", "Origin")

    def log_message(self, *_):
        pass


def servir():
    hosts = ["127.0.0.1"] + ([TAILSCALE] if TAILSCALE else [])
    servidores = []
    for host in hosts:
        try:
            s = http.server.ThreadingHTTPServer((host, PUERTO), Huellas)
            s.daemon_threads = True
            servidores.append(s)
            print(f"huellas en http://{host}:{PUERTO}", flush=True)
        except OSError as e:
            print(f"huellas en {host}: {e}", file=sys.stderr, flush=True)
    for s in servidores[1:]:
        threading.Thread(target=s.serve_forever, daemon=True).start()
    servidores[0].serve_forever()


def todas():
    """Calcula lo que falte de toda la biblioteca. Un fallo no para el resto."""
    canciones = jellyfin("/Items", IncludeItemTypes="Audio", Recursive="true", Fields="Path")["Items"]
    t0, hechas, fallos = time.time(), 0, []
    for i, c in enumerate(canciones, 1):
        ruta = Path(c.get("Path") or "")
        try:
            if not ruta.exists():
                raise FileNotFoundError(ruta)
            obtener(c["Id"], ruta, ruta.stat().st_size)
            hechas += 1
        except Exception as e:
            fallos.append(f"{c.get('Name')}: {e}")
        if i % 50 == 0 or i == len(canciones):
            print(f"{i}/{len(canciones)} en {time.time() - t0:.0f} s", flush=True)
    tamano = sum(f.stat().st_size for f in DIR.glob("*.json"))
    print(f"listo: {hechas} huellas, {len(fallos)} fallos, {tamano / 1e6:.1f} MB en {DIR}")
    for f in fallos[:20]:
        print("  fallo:", f)


def check():
    # Un tono de 1 kHz: la banda que lo contiene manda en casi todos los cuadros.
    t = np.arange(TASA * 3) / TASA
    tono = 0.5 * np.sin(2 * np.pi * 1000 * t)
    banda = int(np.searchsorted(np.geomspace(40, 11000, BANDAS + 1), 1000)) - 1
    assert (bandas_db(tono).argmax(axis=1) == banda).all(), "1 kHz no cae en su banda"
    # Silencio y luego el tono: su banda va de 0 a casi 255 (el tope es el percentil 99.5).
    h = huella_de_pcm(np.concatenate([np.zeros(TASA * 3), tono]))
    datos = np.frombuffer(base64.b64decode(h["datos"]), np.uint8).reshape(h["cuadros"], BANDAS)
    assert h["cuadros"] == (TASA * 6 - N) // (TASA // FPS) + 1, h["cuadros"]
    assert datos[10, banda] == 0 and datos[-10, banda] > 240, datos[[10, -10], banda]
    # Mas corto que una FFT no revienta.
    assert huella_de_pcm(np.zeros(100))["cuadros"] == 1
    assert origen_permitido("http://localhost:5000", ["http://localhost:5000"]) == "http://localhost:5000"
    assert origen_permitido("http://otro.com", ["http://localhost:5000"]) is None
    assert ID.match("/huella/" + "a" * 32) and not ID.match("/huella/../../etc/passwd")
    print("ok")


if __name__ == "__main__":
    check() if "--check" in sys.argv else todas() if "--todas" in sys.argv else servir()
