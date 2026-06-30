from langchain_ollama import ChatOllama
from langchain_core.messages import HumanMessage, SystemMessage
from config import OLLAMA_BASE_URL, LLM_MODEL, EMBED_MODEL
from agent.prompts import CHE_SYSTEM_PROMPT
from memory.manager import MemoryManager

class CheAgent:
    def __init__(self):
        self.llm = ChatOllama(
            base_url=OLLAMA_BASE_URL,
            model=LLM_MODEL,
            temperature=0.7,
            num_predict=1000,
        )
        self.memory = MemoryManager()
        self.historial = []

    async def procesar(self, mensaje: str, usuario: str = "vos") -> str:
        contexto_memoria = await self.memory.buscar_relevante(mensaje)

        system = CHE_SYSTEM_PROMPT.format(
            nombre_usuario=usuario,
            informacion_usuario=contexto_memoria
        )

        mensajes = [SystemMessage(content=system)]
        mensajes.extend(self.historial[-10:])
        mensajes.append(HumanMessage(content=mensaje))

        respuesta = await self.llm.ainvoke(mensajes)

        self.historial.append(HumanMessage(content=mensaje))
        self.historial.append(respuesta)

        await self.memory.guardar_interaccion(mensaje, str(respuesta.content))

        return str(respuesta.content)
