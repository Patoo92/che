import os

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")
LLM_MODEL = os.getenv("LLM_MODEL", "qwen2.5:1.5b")
EMBED_MODEL = os.getenv("EMBED_MODEL", "nomic-embed-text")

POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgres")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_DB = os.getenv("POSTGRES_DB", "che_brain")
POSTGRES_USER = os.getenv("POSTGRES_USER", "che")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "")

BACKEND_PORT = int(os.getenv("BACKEND_PORT", "8000"))
DEBUG = os.getenv("DEBUG_MODE", "False") == "True"

BRAIN_PATH = os.getenv("BRAIN_PATH", "/mnt/che/brain")
SEARCH_PROVIDER = os.getenv("SEARCH_PROVIDER", "duckduckgo")
