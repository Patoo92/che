import psycopg2
from psycopg2.extras import Json
import json
from datetime import datetime
from config import POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, BRAIN_PATH
from langchain_ollama import OllamaEmbeddings
from config import OLLAMA_BASE_URL, EMBED_MODEL

embeddings = OllamaEmbeddings(
    base_url=OLLAMA_BASE_URL,
    model=EMBED_MODEL,
)

class MemoryManager:
    def __init__(self):
        self.conn = psycopg2.connect(
            host=POSTGRES_HOST,
            port=POSTGRES_PORT,
            dbname=POSTGRES_DB,
            user=POSTGRES_USER,
            password=POSTGRES_PASSWORD,
        )
        self.conn.autocommit = True

    def _get_embedding(self, texto: str) -> list:
        return embeddings.embed_query(texto)

    async def guardar_interaccion(self, mensaje: str, respuesta: str, tipo: str = "conversacion"):
        contenido = f"Usuario: {mensaje}\nCHE: {respuesta}"
        embedding = self._get_embedding(contenido)

        with self.conn.cursor() as cur:
            cur.execute(
                """INSERT INTO memories (tipo, contenido, embedding, metadata)
                   VALUES (%s, %s, %s, %s)""",
                (tipo, contenido, embedding, Json({"mensaje": mensaje, "respuesta": respuesta}))
            )

    async def buscar_relevante(self, consulta: str, limite: int = 5) -> str:
        embedding = self._get_embedding(consulta)

        with self.conn.cursor() as cur:
            cur.execute(
                """SELECT contenido, tipo, similarity
                   FROM search_memories(%s::vector(768), 0.7, %s)""",
                (embedding, limite)
            )
            resultados = cur.fetchall()

        if not resultados:
            return ""

        contexto = "\n\n".join([
            f"[{r[1].upper()}] {r[0]}"
            for r in resultados
        ])
        return f"Recuerdos relevantes:\n{contexto}"

    async def guardar_hecho(self, hecho: str):
        embedding = self._get_embedding(hecho)
        with self.conn.cursor() as cur:
            cur.execute(
                """INSERT INTO memories (tipo, contenido, embedding, importancia)
                   VALUES ('hecho', %s, %s, 4)""",
                (hecho, embedding)
            )
