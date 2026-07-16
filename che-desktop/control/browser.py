import webbrowser
import subprocess

def search_google(query):
    webbrowser.open(f"https://www.google.com/search?q={query}")
    return f"Buscando: {query}"

def open_url(url):
    if not url.startswith("http"):
        url = "https://" + url
    webbrowser.open(url)
    return f"Abriendo: {url}"

def open_youtube(query):
    webbrowser.open(f"https://www.youtube.com/results?search_query={query}")
    return f"Buscando en YouTube: {query}"
