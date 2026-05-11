DDL_STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS missions (
        mission_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        mode TEXT NOT NULL,
        status TEXT NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS cloud_events (
        id TEXT PRIMARY KEY,
        specversion TEXT NOT NULL,
        type TEXT NOT NULL,
        source TEXT NOT NULL,
        subject TEXT,
        time TEXT NOT NULL,
        datacontenttype TEXT NOT NULL,
        mission_id TEXT,
        correlation_id TEXT,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL
    );
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_cloud_events_time
    ON cloud_events(time);
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_cloud_events_mission
    ON cloud_events(mission_id);
    """,
    """
    CREATE TABLE IF NOT EXISTS assets (
        asset_id TEXT PRIMARY KEY,
        asset_type TEXT NOT NULL,
        domain TEXT NOT NULL,
        status TEXT NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS evidence (
        evidence_id TEXT PRIMARY KEY,
        mission_id TEXT NOT NULL,
        evidence_type TEXT NOT NULL,
        object_ref TEXT NOT NULL,
        hash_sha256 TEXT,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS device_trust_events (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        trust_domain TEXT NOT NULL,
        classification TEXT NOT NULL,
        severity TEXT NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS network_paths (
        path_id TEXT PRIMARY KEY,
        mission_id TEXT NOT NULL,
        service_type TEXT NOT NULL,
        source_label TEXT NOT NULL,
        destination_label TEXT NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS incidents (
        incident_id TEXT PRIMARY KEY,
        mission_id TEXT NOT NULL,
        classification TEXT NOT NULL,
        severity TEXT NOT NULL,
        status TEXT NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """
]
