-- Synchronized from the official iv-org/invidious config/sql schema on 2026-07-12.
CREATE TABLE IF NOT EXISTS public.channels (
  id text NOT NULL,
  author text,
  updated timestamptz,
  deleted boolean,
  subscribed timestamptz,
  CONSTRAINT channels_id_key UNIQUE (id)
);
CREATE INDEX IF NOT EXISTS channels_id_idx ON public.channels USING btree (id);

CREATE UNLOGGED TABLE IF NOT EXISTS public.videos (
  id text NOT NULL,
  info text,
  updated timestamptz,
  CONSTRAINT videos_pkey PRIMARY KEY (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS id_idx ON public.videos USING btree (id);

CREATE TABLE IF NOT EXISTS public.channel_videos (
  id text NOT NULL,
  title text,
  published timestamptz,
  updated timestamptz,
  ucid text,
  author text,
  length_seconds integer,
  live_now boolean,
  premiere_timestamp timestamptz,
  views bigint,
  CONSTRAINT channel_videos_id_key UNIQUE (id)
);
CREATE INDEX IF NOT EXISTS channel_videos_ucid_idx ON public.channel_videos USING btree (ucid);

CREATE TABLE IF NOT EXISTS public.users (
  updated timestamptz,
  notifications text[],
  subscriptions text[],
  email text NOT NULL,
  preferences text,
  password text,
  token text,
  watched text[],
  feed_needs_update boolean,
  CONSTRAINT users_email_key UNIQUE (email)
);
CREATE UNIQUE INDEX IF NOT EXISTS email_unique_idx ON public.users USING btree (lower(email));

CREATE TABLE IF NOT EXISTS public.session_ids (
  id text NOT NULL,
  email text,
  issued timestamptz,
  CONSTRAINT session_ids_pkey PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS session_ids_id_idx ON public.session_ids USING btree (id);

CREATE TABLE IF NOT EXISTS public.nonces (
  nonce text,
  expire timestamptz,
  CONSTRAINT nonces_id_key UNIQUE (nonce)
);
CREATE INDEX IF NOT EXISTS nonces_nonce_idx ON public.nonces USING btree (nonce);

CREATE TABLE IF NOT EXISTS public.annotations (
  id text NOT NULL,
  annotations xml,
  CONSTRAINT annotations_id_key UNIQUE (id)
);

DO $$ BEGIN
  CREATE TYPE public.privacy AS ENUM ('Public', 'Unlisted', 'Private');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.playlists (
  title text,
  id text PRIMARY KEY,
  author text,
  description text,
  video_count integer,
  created timestamptz,
  updated timestamptz,
  privacy privacy,
  index int8[]
);

CREATE TABLE IF NOT EXISTS public.playlist_videos (
  title text,
  id text,
  author text,
  ucid text,
  length_seconds integer,
  published timestamptz,
  plid text REFERENCES playlists(id),
  index int8,
  live_now boolean,
  PRIMARY KEY (index, plid)
);

GRANT ALL ON ALL TABLES IN SCHEMA public TO CURRENT_USER;
