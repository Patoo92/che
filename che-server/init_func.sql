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
