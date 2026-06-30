#!/usr/bin/env python3
"""
verify_che.py — Verifica que CHE está funcionando correctamente.
Ejecutar desde el servidor (o desde cualquier lado con acceso a la IP).

Uso:
    python3 scripts/verify_che.py                          # Prueba localhost:8000
    python3 scripts/verify_che.py http://100.x.x.x:8000    # Prueba remota
"""

import sys
import json
import urllib.request
import urllib.error

BASE_URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"

def test(name, url, expected_key=None):
    full_url = f"{BASE_URL}{url}"
    try:
        resp = urllib.request.urlopen(full_url, timeout=10)
        data = resp.read().decode()
        if expected_key:
            parsed = json.loads(data)
            if expected_key in parsed:
                print(f"  ✅ {name}: {parsed[expected_key]}")
            else:
                print(f"  ⚠️  {name}: respuesta inesperada: {data[:100]}")
        else:
            print(f"  ✅ {name}: OK ({resp.status})")
    except urllib.error.HTTPError as e:
        print(f"  ❌ {name}: HTTP {e.code}")
    except urllib.error.URLError as e:
        print(f"  ❌ {name}: {e.reason}")
    except Exception as e:
        print(f"  ❌ {name}: {e}")

print(f"\n🔍 Verificando CHE en: {BASE_URL}\n")

test("Backend (GET /)", "/", "status")

test("TTS (audio)", "/tts?texto=Hola%20che%20esto%20es%20una%20prueba")

print(f"\n📡 Para probar WebSocket necesitás un cliente como websocat:")
print(f"    websocat ws://{BASE_URL.replace('http://', '')}/ws")
print()
