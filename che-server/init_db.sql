CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE user_profile (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    preferencias JSONB DEFAULT '{}',
    zona_horaria TEXT DEFAULT 'America/Argentina/Buenos_Aires',
    asistente_nombre TEXT DEFAULT 'CHE',
    wake_word TEXT DEFAULT 'Che',
    tono TEXT DEFAULT 'argentino',
    idioma TEXT DEFAULT 'es-AR',
    creado_en TIMESTAMPTZ DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    whatsapp TEXT,
    alias TEXT[],
    tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    creado_en TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    tipo TEXT NOT NULL,
    contenido TEXT NOT NULL,
    embedding vector(768),
    metadata JSONB DEFAULT '{}',
    importancia INTEGER DEFAULT 3 CHECK (importancia BETWEEN 1 AND 5),
    fuente TEXT DEFAULT 'voz',
    archivo_md TEXT,
    expires_at TIMESTAMPTZ,
    creado_en TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_memories_embedding ON memories
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

CREATE INDEX idx_memories_timestamp ON memories (timestamp DESC);
CREATE INDEX idx_memories_tipo ON memories (tipo);

CREATE TABLE tareas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo TEXT NOT NULL,
    descripcion TEXT,
    estado TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'completada', 'cancelada')),
    prioridad INTEGER DEFAULT 2 CHECK (prioridad BETWEEN 1 AND 3),
    fecha_limite TIMESTAMPTZ,
    creado_en TIMESTAMPTZ DEFAULT NOW(),
    completado_en TIMESTAMPTZ
);

CREATE OR REPLACE FUNCTION search_memories(
    query_embedding vector(768),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10,
    filter_tipo TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    contenido TEXT,
    tipo TEXT,
    timestamp TIMESTAMPTZ,
    metadata JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id,
        m.contenido,
        m.tipo,
        m.timestamp,
        m.metadata,
        1 - (m.embedding <=> query_embedding) AS similarity
    FROM memories m
    WHERE 1 - (m.embedding <=> query_embedding) > match_threshold
      AND (filter_tipo IS NULL OR m.tipo = filter_tipo)
    ORDER BY m.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

\dt
