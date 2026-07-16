import json
import asyncio
import websockets
import config

async def send_message(text):
    try:
        async with websockets.connect(config.SERVER_URL) as ws:
            await ws.send(json.dumps({
                "type": "chat",
                "text": text,
                "token": config.WS_SECRET,
            }))
            response = await ws.recv()
            data = json.loads(response)
            return data.get("text", "")
    except Exception as e:
        print(f"[CHE] Error de conexión: {e}")
        return "No pude conectarme al servidor. Revisá la conexión."
