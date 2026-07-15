from langchain_ollama import ChatOllama
from langchain_core.messages import HumanMessage, SystemMessage
from datetime import datetime
from config import OLLAMA_BASE_URL, LLM_MODEL, EMBED_MODEL
from agent.prompts import CHE_SYSTEM_PROMPT
from memory.manager import MemoryManager

class CheAgent:
    def __init__(self):
        self.llm = ChatOllama(
            base_url=OLLAMA_BASE_URL,
            model=LLM_MODEL,
            temperature=0.7,
            num_predict=150,
        )
        self.memory = MemoryManager()
        self.historial = []

    async def procesar(self, mensaje: str, usuario: str = "vos") -> str:
        contexto_memoria = await self.memory.buscar_relevante(mensaje)

        ahora = datetime.now().strftime("%A %d de %B de %Y, %H:%M hs")

        system = CHE_SYSTEM_PROMPT.format(
            nombre_usuario=usuario,
            hora_actual=ahora,
            informacion_usuario=contexto_memoria or "Sin información previa del usuario."
        )

        mensajes = [SystemMessage(content=system)]
        mensajes.extend(self.historial[-6:])
        mensajes.append(HumanMessage(content=mensaje))

        respuesta = await self.llm.ainvoke(mensajes)

        self.historial.append(HumanMessage(content=mensaje))
        self.historial.append(respuesta)

        await self.memory.guardar_interaccion(mensaje, str(respuesta.content))

        return str(respuesta.content)
