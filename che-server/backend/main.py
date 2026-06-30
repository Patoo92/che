from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
import uvicorn
import json
import base64
from config import BACKEND_PORT, DEBUG, BRAIN_PATH
from agent.che import CheAgent

app = FastAPI(title="CHE Backend", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

che = CheAgent()

@app.get("/")
async def root():
    return {"status": "CHE online", "version": "1.0.0", "modelo": "qwen2.5:1.5b"}

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
                        "text": "No se recibió transcripción. Vosk debe ejecutarse en el dispositivo."
                    }))
                    continue

                respuesta = await che.procesar(texto)
                await websocket.send_text(json.dumps({
                    "type": "response",
                    "text": respuesta
                }))

    except WebSocketDisconnect:
        print("[CHE] App desconectada")

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=BACKEND_PORT, reload=DEBUG)
