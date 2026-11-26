CREATE TABLE IF NOT EXISTS sessions (
  id serial PRIMARY KEY,
  started_at timestamptz NOT NULL DEFAULT now(),
  active boolean NOT NULL DEFAULT true
);
-- Como máximo una activa…
CREATE UNIQUE INDEX IF NOT EXISTS sessions_one_active ON sessions (active) WHERE active;
-- …y al menos una.
INSERT INTO sessions (active) SELECT true WHERE NOT EXISTS (SELECT 1 FROM sessions WHERE active)
  ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS attempts (
  id serial PRIMARY KEY,
  session_id int NOT NULL REFERENCES sessions(id),
  name_key text NOT NULL,
  display_name text NOT NULL,
  rounds jsonb NOT NULL,
  score numeric(6,3) NOT NULL,
  vel_error_pct numeric,
  reaction_avg numeric,
  stars int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS attempts_session_name ON attempts (session_id, name_key);

CREATE TABLE IF NOT EXISTS events (
  id serial PRIMARY KEY,
  session_id int NOT NULL REFERENCES sessions(id),
  type text NOT NULL CHECK (type IN ('joined', 'finished')),
  name_key text NOT NULL,
  display_name text NOT NULL,
  rank int,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS events_session_created ON events (session_id, created_at DESC);
