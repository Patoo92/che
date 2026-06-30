from duckduckgo_search import DDGS

def buscar_web(query: str) -> str:
    with DDGS() as ddgs:
        resultados = list(ddgs.text(query, max_results=5))
    if not resultados:
        return "Sin resultados."
    return "\n\n".join([
        f"{r['title']}: {r['body']}"
        for r in resultados
    ])
