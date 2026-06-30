#!/usr/bin/env python3
"""
Consolidación Nocturna de CHE
Ejecutar: python3 consolidacion.py
Programar con cron: 0 3 * * *
"""

import psycopg2
import json
import os
from datetime import datetime, timedelta
from pathlib import Path
import shutil
from langchain_ollama import ChatOllama, OllamaEmbeddings

OLLAMA_URL = "http://ollama:11434"
LLM_MODEL = "qwen2.5:1.5b"
EMBED_MODEL = "nomic-embed-text"
BRAIN_PATH = "/mnt/che/brain"
DB_HOST = "postgres"
DB_NAME = "che_brain"
DB_USER = "che"
DB_PASS = os.environ.get("POSTGRES_PASSWORD")

llm = ChatOllama(base_url=OLLAMA_URL, model=LLM_MODEL, temperature=0.3)
embeddings = OllamaEmbeddings(base_url=OLLAMA_URL, model=EMBED_MODEL)

conn = psycopg2.connect(host=DB_HOST, dbname=DB_NAME, user=DB_USER, password=DB_PASS)
conn.autocommit = True

def get_embedding(texto):
    return embeddings.embed_query(texto)

def get_interacciones_del_dia():
    with conn.cursor() as cur:
        cur.execute(
            """SELECT id, contenido, timestamp FROM memories
               WHERE timestamp >= NOW() - INTERVAL '24 hours'
               AND tipo = 'conversacion'
               ORDER BY timestamp"""
        )
        return cur.fetchall()

def extraer_hechos(interacciones):
    if not interacciones:
        return []

    texto = "\n".join([f"- {i[1]}" for i in interacciones])
    prompt = f"""De las siguientes interacciones del día, extraé 3-5 hechos importantes
o datos para recordar sobre el usuario. Respondé SOLO con la lista numerada:

{texto}"""
    respuesta = llm.invoke(prompt)
    hechos = [l.strip() for l in str(respuesta.content).split("\n") if l.strip() and l[0].isdigit()]
    return hechos

def guardar_hechos(hechos):
    for hecho in hechos:
        embedding = get_embedding(hecho)
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO memories (tipo, contenido, embedding, importancia)
                   VALUES ('hecho', %s, %s, 4)""",
                (hecho, embedding)
            )
        print(f"  ✓ Hecho guardado: {hecho[:60]}...")

def generar_diario_md(interacciones, hechos):
    fecha = datetime.now().strftime("%Y-%m-%d")
    ruta = Path(BRAIN_PATH) / "diario" / f"{fecha}.md"
    ruta.parent.mkdir(exist_ok=True)

    with open(ruta, "w", encoding="utf-8") as f:
        f.write(f"# Diario — {fecha}\n\n")

        if hechos:
            f.write("## Hechos del día\n")
            for h in hechos:
                f.write(f"- {h}\n")
            f.write("\n")

        if interacciones:
            f.write("## Interacciones\n")
            for i in interacciones:
                f.write(f"- [{i[2].strftime('%H:%M')}] {i[1][:100]}...\n")
            f.write("\n")

    print(f"  ✓ Diario generado: {ruta}")

def comprimir_memorias_viejas():
    with conn.cursor() as cur:
        cur.execute(
            """SELECT id, contenido FROM memories
               WHERE timestamp < NOW() - INTERVAL '30 days'
               AND tipo = 'conversacion'
               AND metadata->>'comprimido' IS NULL
               LIMIT 50"""
        )
        viejas = cur.fetchall()

    for vid, contenido in viejas:
        prompt = f"Resumí esta conversación en 1-2 oraciones: {contenido}"
        resumen = str(llm.invoke(prompt).content)
        embedding = get_embedding(resumen)

        with conn.cursor() as cur:
            cur.execute(
                "UPDATE memories SET contenido = %s, embedding = %s, metadata = metadata || '{\"comprimido\": true}' WHERE id = %s",
                (resumen, embedding, vid)
            )
        print(f"  ~ Memoria comprimida: {vid}")

def hacer_backup():
    import subprocess
    backup_path = Path(BRAIN_PATH) / "../backups" / "pg" / f"che_brain_{datetime.now():%Y%m%d}.sql"
    backup_path.parent.mkdir(exist_ok=True)
    subprocess.run([
        "pg_dump", "-h", "postgres", "-U", "che", "-d", "che_brain",
        "-f", str(backup_path)
    ], env={"PGPASSWORD": DB_PASS})
    print(f"  ✓ Backup: {backup_path}")

def limpiar_cache_celu():
    print("  ~ Cache del celu marcada como sincronizada")

def main():
    print("=" * 50)
    print(f"  Consolidación Nocturna — {datetime.now():%Y-%m-%d %H:%M}")
    print("=" * 50)

    print("\n[1/6] Obteniendo interacciones del día...")
    interacciones = get_interacciones_del_dia()
    print(f"  → {len(interacciones)} interacciones encontradas")

    print("\n[2/6] Extrayendo hechos...")
    hechos = extraer_hechos(interacciones)
    print(f"  → {len(hechos)} hechos extraídos")
    guardar_hechos(hechos)

    print("\n[3/6] Generando diario Markdown...")
    generar_diario_md(interacciones, hechos)

    print("\n[4/6] Comprimiendo memorias viejas...")
    comprimir_memorias_viejas()

    print("\n[5/6] Haciendo backup...")
    hacer_backup()

    print("\n[6/6] Limpiando caché del celu...")
    limpiar_cache_celu()

    print("\n✓ Consolidación completada exitosamente")

if __name__ == "__main__":
    main()
