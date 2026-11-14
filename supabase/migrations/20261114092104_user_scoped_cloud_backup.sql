-- Private per-user snapshot backup for the offline-first Flutter app.
CREATE TABLE public.user_backups (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
  schema_version smallint NOT NULL DEFAULT 1 CHECK (schema_version > 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_backups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own backup" ON public.user_backups
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can create their own backup" ON public.user_backups
  FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can update their own backup" ON public.user_backups
  FOR UPDATE TO authenticated USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can delete their own backup" ON public.user_backups
  FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_backups TO authenticated;
REVOKE ALL PRIVILEGES ON public.user_backups FROM anon;
