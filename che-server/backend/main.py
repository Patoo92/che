from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
import uvicorn
import json
import base64
import io
import struct
from config import BACKEND_PORT, DEBUG, BRAIN_PATH
from agent.che import CheAgent
from stt.whisper_stt import transcribe_audio

app = FastAPI(title="CHE Backend", version="1.1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

che = CheAgent()

@app.get("/")
async def root():
    return {"status": "CHE online", "version": "1.1.0", "modelo": "qwen2.5:1.5b"}

@app.get("/tts")
async def text_to_speech(texto: str):
    import edge_tts
    communicate = edge_tts.Communicate(texto, "es-AR-ElenaNeural")
    audio_bytes = b""
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            audio_bytes += chunk["data"]
    return Response(content=audio_bytes, media_type="audio/mpeg")

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
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

            elif tipo == "audio":
                audio_b64 = msg.get("audio", "")
                formato = msg.get("formato", "webm")
                audio_bytes = base64.b64decode(audio_b64)

                texto = msg.get("text", "")

                if not texto:
                    await websocket.send_text(json.dumps({
                        "type": "error",
                        "text": "No se recibio transcripcion."
                    }))
                    continue

                respuesta = await che.procesar(texto)
                await websocket.send_text(json.dumps({
                    "type": "response",
                    "text": respuesta
                }))

    except WebSocketDisconnect:
        print("[CHE] App desconectada")

async def _handle_audio(websocket: WebSocket, audio_bytes: bytes):
    await websocket.send_text(json.dumps({
        "type": "status",
        "text": "transcribiendo"
    }))

    try:
        texto = transcribe_audio(audio_bytes)
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

@app.websocket("/ws/voice")
async def voice_websocket(websocket: WebSocket):
    await websocket.accept()
    print("[CHE Voice] Cliente conectado", flush=True)
    try:
        while True:
            print("[CHE Voice] Waiting for message...", flush=True)
            msg = await websocket.receive()
            print(f"[CHE Voice] Received msg keys: {list(msg.keys())}", flush=True)

            if "bytes" in msg and msg["bytes"] is not None:
                audio_bytes = msg["bytes"]
                print(f"[CHE Voice] Binary received: {len(audio_bytes)} bytes", flush=True)
                await _handle_audio(websocket, audio_bytes)

            elif "text" in msg and msg["text"] is not None:
                data = json.loads(msg["text"])
                tipo = data.get("type", "")
                print(f"[CHE Voice] Text msg type: {tipo}", flush=True)

                if tipo == "audio":
                    audio_b64 = data.get("data", "")
                    if not audio_b64:
                        await websocket.send_text(json.dumps({
                            "type": "error",
                            "text": "Audio vacio"
                        }))
                        continue
                    audio_bytes = base64.b64decode(audio_b64)
                    print(f"[CHE Voice] Base64 audio: {len(audio_bytes)} bytes", flush=True)
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
            else:
                print(f"[CHE Voice] Unknown msg: {msg}", flush=True)

    except WebSocketDisconnect:
        print("[CHE Voice] Cliente desconectado", flush=True)
    except Exception as e:
        print(f"[CHE Voice] Error: {e}", flush=True)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=BACKEND_PORT, reload=DEBUG)
