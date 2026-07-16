from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
import uvicorn
import json
import base64
from config import BACKEND_PORT, DEBUG, WS_SECRET
from agent.che import CheAgent
from stt.whisper_stt import transcribe_audio

app = FastAPI(title="CHE Backend", version="1.2.0")

che = CheAgent()

def _check_ws_auth(token: str) -> bool:
    if not WS_SECRET:
        return True
    return token == WS_SECRET

@app.get("/")
async def root():
    return {"status": "CHE online", "version": "1.2.0", "modelo": "qwen2.5:1.5b"}

async def _handle_audio(websocket: WebSocket, audio_bytes: bytes):
    await websocket.send_text(json.dumps({
        "type": "status",
        "text": "transcribiendo"
    }))

    try:
        texto = await _run_transcribe(audio_bytes)
    except Exception as e:
        print(f"[CHE Voice] Whisper error: {e}")
        await websocket.send_text(json.dumps({
            "type": "error",
            "text": f"Error de transcripcion: {e}"
        }))
        return

    if not texto.strip():
        await websocket.send_text(json.dumps({
            "type": "error",
            "text": "No se pudo transcribir el audio"
        }))
        return

    await websocket.send_text(json.dumps({
        "type": "transcript",
        "text": texto
    }))

    await websocket.send_text(json.dumps({
        "type": "status",
        "text": "procesando"
    }))

    respuesta = await che.procesar(texto)

    await websocket.send_text(json.dumps({
        "type": "response",
        "text": respuesta
    }))

import asyncio

async def _run_transcribe(audio_bytes: bytes) -> str:
    return await asyncio.to_thread(transcribe_audio, audio_bytes)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = Query("")):
    if not _check_ws_auth(token):
        await websocket.close(code=4401, reason="Unauthorized")
        return
    await websocket.accept()
    print("[CHE] App conectada")
    try:
        while True:
            data = await websocket.receive_text()
            msg = json.loads(data)
            tipo = msg.get("type", "")

            if tipo == "message":
                texto = msg.get("text", "")
                respuesta = await che.procesar(texto)
                await websocket.send_text(json.dumps({
                    "type": "response",
                    "text": respuesta
                }))

    except WebSocketDisconnect:
        print("[CHE] App desconectada")

@app.websocket("/ws/voice")
async def voice_websocket(websocket: WebSocket, token: str = Query("")):
    if not _check_ws_auth(token):
        await websocket.close(code=4401, reason="Unauthorized")
        return
    await websocket.accept()
    print("[CHE Voice] Cliente conectado", flush=True)
    try:
        while True:
            msg = await websocket.receive()

            if "bytes" in msg and msg["bytes"] is not None:
                audio_bytes = msg["bytes"]
                print(f"[CHE Voice] Binary: {len(audio_bytes)} bytes", flush=True)
                await _handle_audio(websocket, audio_bytes)

            elif "text" in msg and msg["text"] is not None:
                data = json.loads(msg["text"])
                tipo = data.get("type", "")

                if tipo == "audio":
                    audio_b64 = data.get("data", "")
                    if not audio_b64:
                        await websocket.send_text(json.dumps({
                            "type": "error",
                            "text": "Audio vacio"
                        }))
                        continue
                    audio_bytes = base64.b64decode(audio_b64)
                    print(f"[CHE Voice] Base64: {len(audio_bytes)} bytes", flush=True)
                    await _handle_audio(websocket, audio_bytes)

                elif tipo == "transcript":
                    texto = data.get("text", "")
                    if not texto:
                        await websocket.send_text(json.dumps({
                            "type": "error",
                            "text": "Transcripcion vacia"
                        }))
                        continue

                    await websocket.send_text(json.dumps({
                        "type": "status",
                        "text": "procesando"
                    }))

                    respuesta = await che.procesar(texto)

                    await websocket.send_text(json.dumps({
                        "type": "response",
                        "text": respuesta
                    }))

                elif tipo == "interrupt":
                    await websocket.send_text(json.dumps({
                        "type": "interrupt_ack"
                    }))

    except WebSocketDisconnect:
        print("[CHE Voice] Cliente desconectado", flush=True)
    except Exception as e:
        print(f"[CHE Voice] Error: {e}", flush=True)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=BACKEND_PORT, reload=DEBUG)
