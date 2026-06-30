from .manager import MemoryManager

async def buscar_en_memoria(consulta: str) -> str:
    mm = MemoryManager()
    return await mm.buscar_relevante(consulta, limite=3)
