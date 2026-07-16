import asyncio
import psycopg2
from psycopg2.extras import Json
from config import (
    POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD,
    OLLAMA_BASE_URL, EMBED_MODEL,
)
from langchain_ollama import OllamaEmbeddings

embeddings = OllamaEmbeddings(
    base_url=OLLAMA_BASE_URL,
    model=EMBED_MODEL,
)


def _get_conn():
    conn = psycopg2.connect(
        host=POSTGRES_HOST,
        port=POSTGRES_PORT,
        dbname=POSTGRES_DB,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
    )
    conn.autocommit = True
    return conn


def _sync_get_embedding(texto: str) -> list:
    return embeddings.embed_query(texto)


def _sync_guardar_interaccion(mensaje: str, respuesta: str, tipo: str = "conversacion"):
    contenido = f"Usuario: {mensaje}\nCHE: {respuesta}"
    embedding = _sync_get_embedding(contenido)
    conn = _get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO memories (tipo, contenido, embedding, metadata)
                   VALUES (%s, %s, %s, %s)""",
                (tipo, contenido, embedding, Json({"mensaje": mensaje, "respuesta": respuesta}))
            )
    finally:
        conn.close()


def _sync_buscar_relevante(consulta: str, limite: int = 5) -> str:
    embedding = _sync_get_embedding(consulta)
    conn = _get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT contenido, tipo, similarity
                   FROM search_memories(%s::vector(768), 0.7, %s)""",
                (embedding, limite)
            )
            resultados = cur.fetchall()
    finally:
        conn.close()

    if not resultados:
        return ""

    contexto = "\n\n".join([
        f"[{r[1].upper()}] {r[0]}"
        for r in resultados
    ])
    return f"Recuerdos relevantes:\n{contexto}"


def _sync_guardar_hecho(hecho: str):
    embedding = _sync_get_embedding(hecho)
    conn = _get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO memories (tipo, contenido, embedding, importancia)
                   VALUES ('hecho', %s, %s, 4)""",
                (hecho, embedding)
            )
    finally:
        conn.close()


class MemoryManager:
    async def guardar_interaccion(self, mensaje: str, respuesta: str, tipo: str = "conversacion"):
        await asyncio.to_thread(_sync_guardar_interaccion, mensaje, respuesta, tipo)

    async def buscar_relevante(self, consulta: str, limite: int = 5) -> str:
        return await asyncio.to_thread(_sync_buscar_relevante, consulta, limite)

    async def guardar_hecho(self, hecho: str):
        await asyncio.to_thread(_sync_guardar_hecho, hecho)
