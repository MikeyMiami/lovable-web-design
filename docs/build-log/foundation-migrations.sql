-- =============================================================================
-- Foundation build record — migrations 1–4, in apply order (golden master)
-- =============================================================================
-- Verbatim as-built DDL from the Lovable project disk. Secret-scanned: pure DDL,
-- no secret values. Validated against skills/scratch-foundation/SKILL.md
-- (see docs/build-log/foundation-schema-snapshot.md). Captured 2026-06-09.
--
-- Apply order:
--   1) 20260609032253  pre-foundation: enable pg_cron, pg_net
--   2) 20260609034320  foundation: extensions, 4 enums, trigger fn, 12 tables,
--                      GRANTs/RLS/policies, 4 SECURITY DEFINER helpers, indexes
--   3) 20260609034341  lockdown: REVOKE EXECUTE on the 4 helpers (BUG — broke
--                      RLS evaluation; superseded by migration 4)
--   4) 20260609040856  helper EXECUTE fix: GRANT-back + self-guard +
--                      service_role exemption (current form of the 4 helpers)
--
-- NOTE: the helpers' CURRENT runtime form is migration 4 (plpgsql, guarded).
-- Migration 2's sql-form helper bodies are retained here for history only.
-- =============================================================================


-- #############################################################################
-- ## MIGRATION 1 — 20260609032253 — pre-foundation (extensions)
-- #############################################################################
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;


-- #############################################################################
-- ## MIGRATION 2 — 20260609034320 — foundation (494 lines)
-- #############################################################################

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 2. ENUMS
-- ============================================================
CREATE TYPE public.app_role AS ENUM ('admin','agency_owner','client_owner','client_staff','client');

CREATE TYPE public.contact_status AS ENUM (
  'new','contacted','replied','customer',
  'review_requested','review_clicked','review_completed','negative_review','reactivation',
  'opted_out'
);

CREATE TYPE public.contact_source AS ENUM (
  'web_form','review_enroll','missed_call','import','manual','chat_widget','mobile_enroll'
);

CREATE TYPE public.review_gate_mode AS ENUM ('gated','direct');

-- ============================================================
-- 3. updated_at TRIGGER FN (shared)
-- ============================================================
CREATE OR REPLACE FUNCTION public.tg_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ============================================================
-- 4. CLIENTS
-- ============================================================
CREATE TABLE public.clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  business_name text NOT NULL,
  address text,
  phone_display text,
  email text,
  license_number text,
  hours jsonb NOT NULL DEFAULT '{}'::jsonb,
  logo_url text,
  brand_color text NOT NULL DEFAULT '#bd703e',
  service_area text[] NOT NULL DEFAULT '{}',
  tagline text,
  review_place_id text,
  review_link text,
  google_review_toggle public.review_gate_mode NOT NULL DEFAULT 'gated',
  star_threshold smallint NOT NULL DEFAULT 4,
  twilio_number text,
  twilio_messaging_service_sid text,
  allowed_origins text[] NOT NULL DEFAULT '{}',
  call_forwarding_number text,
  site_style text,
  social_links jsonb NOT NULL DEFAULT '{}'::jsonb,
  template_vars jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'active',
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.clients TO authenticated;
GRANT SELECT ON public.clients TO anon;
GRANT ALL ON public.clients TO service_role;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER trg_clients_updated_at BEFORE UPDATE ON public.clients
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

-- ============================================================
-- 5. USER_ROLES  (defined before helpers reference it)
-- ============================================================
CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  client_id uuid REFERENCES public.clients(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role, client_id)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX idx_user_roles_client_id ON public.user_roles(client_id);

-- ============================================================
-- 6. SECURITY DEFINER HELPERS  (original SQL form — superseded by migration 4)
-- ============================================================
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role);
$$;

CREATE OR REPLACE FUNCTION public.is_admin(_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = 'admin');
$$;

CREATE OR REPLACE FUNCTION public.is_agency_owner(_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = 'agency_owner');
$$;

CREATE OR REPLACE FUNCTION public.user_client_ids(_user_id uuid)
RETURNS SETOF uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.clients
    WHERE EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = _user_id AND ur.role IN ('admin','agency_owner')
    )
  UNION
  SELECT client_id FROM public.user_roles
    WHERE user_id = _user_id AND client_id IS NOT NULL;
$$;

-- ============================================================
-- 7. CLIENTS RLS POLICIES
-- ============================================================
CREATE POLICY clients_select ON public.clients
  FOR SELECT TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
CREATE POLICY clients_anon_select ON public.clients
  FOR SELECT TO anon
  USING (status = 'active' AND deleted_at IS NULL);
CREATE POLICY clients_insert ON public.clients
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin((SELECT auth.uid())) OR public.is_agency_owner((SELECT auth.uid())));
CREATE POLICY clients_update ON public.clients
  FOR UPDATE TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  )
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
CREATE POLICY clients_delete ON public.clients
  FOR DELETE TO authenticated
  USING (public.is_admin((SELECT auth.uid())));

-- ============================================================
-- 8. USER_ROLES RLS  (no recursion)
-- ============================================================
CREATE POLICY user_roles_self_select ON public.user_roles
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_admin((SELECT auth.uid()))
  );
-- writes go through service-role (server fns)

-- ============================================================
-- 9. SEND_SETTINGS
-- ============================================================
CREATE TABLE public.send_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL UNIQUE REFERENCES public.clients(id) ON DELETE CASCADE,
  timezone text NOT NULL DEFAULT 'America/New_York',
  sms_send_window jsonb NOT NULL DEFAULT '{"start":"09:00","end":"19:00"}'::jsonb,
  business_hours jsonb NOT NULL DEFAULT '{"mon":["09:00","17:00"],"tue":["09:00","17:00"],"wed":["09:00","17:00"],"thu":["09:00","17:00"],"fri":["09:00","17:00"]}'::jsonb,
  daily_send_cap int NOT NULL DEFAULT 500,
  daily_enrollment_cap int NOT NULL DEFAULT 50,
  sequence_overrides jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.send_settings TO authenticated;
GRANT ALL ON public.send_settings TO service_role;
ALTER TABLE public.send_settings ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER trg_send_settings_updated_at BEFORE UPDATE ON public.send_settings
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();
CREATE POLICY send_settings_all ON public.send_settings
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  )
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );

-- ============================================================
-- 10. CONTACTS
-- ============================================================
CREATE TABLE public.contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  first_name text,
  last_name text,
  phone_e164 text,
  email text,
  status public.contact_status NOT NULL DEFAULT 'new',
  source public.contact_source NOT NULL DEFAULT 'manual',
  consent_basis text,
  consent_at timestamptz,
  opted_out_at timestamptz,
  last_missed_call_textback_at timestamptz,
  notes text,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.contacts TO authenticated;
GRANT ALL ON public.contacts TO service_role;
ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER trg_contacts_updated_at BEFORE UPDATE ON public.contacts
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();
CREATE INDEX idx_contacts_client_status ON public.contacts(client_id, status);
CREATE INDEX idx_contacts_client_phone ON public.contacts(client_id, phone_e164);
CREATE POLICY contacts_all ON public.contacts
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  )
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );

-- ============================================================
-- 11. CONVERSATIONS
-- ============================================================
CREATE TABLE public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  contact_id uuid NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  last_message_at timestamptz,
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.conversations TO authenticated;
GRANT ALL ON public.conversations TO service_role;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_conversations_client_contact ON public.conversations(client_id, contact_id);
CREATE POLICY conversations_all ON public.conversations
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  )
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );

-- ============================================================
-- 12. MESSAGES
-- ============================================================
CREATE TABLE public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  direction text NOT NULL CHECK (direction IN ('inbound','outbound')),
  body text NOT NULL,
  twilio_sid text,
  status text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages TO authenticated;
GRANT ALL ON public.messages TO service_role;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_messages_convo_created ON public.messages(conversation_id, created_at DESC);
CREATE INDEX idx_messages_client_created ON public.messages(client_id, created_at DESC);
CREATE POLICY messages_all ON public.messages
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  )
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );

-- ============================================================
-- 13. TEMPLATES (global = client_id NULL)
-- ============================================================
CREATE TABLE public.templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES public.clients(id) ON DELETE CASCADE,
  key text NOT NULL,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.templates TO authenticated;
GRANT ALL ON public.templates TO service_role;
ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER trg_templates_updated_at BEFORE UPDATE ON public.templates
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();
CREATE UNIQUE INDEX uq_templates_client_key ON public.templates(client_id, key) WHERE client_id IS NOT NULL;
CREATE UNIQUE INDEX uq_templates_global_key ON public.templates(key) WHERE client_id IS NULL;
CREATE POLICY templates_select ON public.templates
  FOR SELECT TO authenticated
  USING (
    client_id IS NULL
    OR public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
CREATE POLICY templates_write ON public.templates
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR (client_id IS NOT NULL AND client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))))
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR (client_id IS NOT NULL AND client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))));

-- ============================================================
-- 14. SEQUENCES
-- ============================================================
CREATE TABLE public.sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES public.clients(id) ON DELETE CASCADE,
  key text NOT NULL,
  name text NOT NULL,
  steps_json jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sequences TO authenticated;
GRANT ALL ON public.sequences TO service_role;
ALTER TABLE public.sequences ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER trg_sequences_updated_at BEFORE UPDATE ON public.sequences
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();
CREATE UNIQUE INDEX uq_sequences_client_key ON public.sequences(client_id, key) WHERE client_id IS NOT NULL;
CREATE UNIQUE INDEX uq_sequences_global_key ON public.sequences(key) WHERE client_id IS NULL;
CREATE POLICY sequences_select ON public.sequences
  FOR SELECT TO authenticated
  USING (
    client_id IS NULL
    OR public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
CREATE POLICY sequences_write ON public.sequences
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR (client_id IS NOT NULL AND client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))))
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR (client_id IS NOT NULL AND client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))));

-- ============================================================
-- 15. ENROLLMENTS
-- ============================================================
CREATE TABLE public.enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  contact_id uuid NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  sequence_key text NOT NULL,
  current_step int NOT NULL DEFAULT 0,
  next_run_at timestamptz,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (client_id, contact_id, sequence_key)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.enrollments TO authenticated;
GRANT ALL ON public.enrollments TO service_role;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_enrollments_due ON public.enrollments(next_run_at) WHERE status = 'active';
CREATE INDEX idx_enrollments_client ON public.enrollments(client_id);
CREATE POLICY enrollments_all ON public.enrollments
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  )
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );

-- ============================================================
-- 16. REVIEW_FEEDBACK
-- ============================================================
CREATE TABLE public.review_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  contact_id uuid REFERENCES public.contacts(id) ON DELETE SET NULL,
  name text,
  email text,
  phone text,
  rating smallint,
  comment text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.review_feedback TO authenticated;
GRANT ALL ON public.review_feedback TO service_role;
ALTER TABLE public.review_feedback ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_review_feedback_client_created ON public.review_feedback(client_id, created_at DESC);
CREATE POLICY review_feedback_all ON public.review_feedback
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  )
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );

-- ============================================================
-- 17. EVENTS (append-only audit; powers caps/throttles)
-- ============================================================
CREATE TABLE public.events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  type text NOT NULL,
  contact_id uuid REFERENCES public.contacts(id) ON DELETE SET NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.events TO authenticated;
GRANT ALL ON public.events TO service_role;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_events_client_type_created ON public.events(client_id, type, created_at DESC);
CREATE POLICY events_select ON public.events
  FOR SELECT TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
-- inserts only via service-role

-- ============================================================
-- 18. NOTIFICATIONS
-- ============================================================
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  type text NOT NULL,
  body text NOT NULL,
  related_contact_id uuid REFERENCES public.contacts(id) ON DELETE SET NULL,
  action jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_notifications_client_created ON public.notifications(client_id, created_at DESC);
CREATE POLICY notifications_select ON public.notifications
  FOR SELECT TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
-- inserts via service-role


-- #############################################################################
-- ## MIGRATION 3 — 20260609034341 — helper lockdown (BUG; superseded by mig 4)
-- #############################################################################
-- NOTE: this REVOKE broke RLS policy evaluation for authed users (EXECUTE is
-- checked against the calling role even for SECURITY DEFINER fns invoked from a
-- policy). Fixed by migration 4. Retained here for history — do NOT re-apply in
-- isolation. See docs/build-log/migration-4-helper-execute-fix.md.
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_admin(uuid)                 FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_agency_owner(uuid)          FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.user_client_ids(uuid)          FROM PUBLIC, anon, authenticated;


-- #############################################################################
-- ## MIGRATION 4 — 20260609040856 — helper EXECUTE fix (CURRENT helper form)
-- #############################################################################
-- Restore EXECUTE so RLS policies can evaluate helpers
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role)   TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid)                    TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_agency_owner(uuid)             TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.user_client_ids(uuid)            TO anon, authenticated;

-- has_role: self-only guard, service_role exempt
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() <> 'service_role' AND _user_id IS DISTINCT FROM auth.uid() THEN
    RETURN false;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  );
END;
$$;

-- is_admin
CREATE OR REPLACE FUNCTION public.is_admin(_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() <> 'service_role' AND _user_id IS DISTINCT FROM auth.uid() THEN
    RETURN false;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = 'admin'
  );
END;
$$;

-- is_agency_owner
CREATE OR REPLACE FUNCTION public.is_agency_owner(_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() <> 'service_role' AND _user_id IS DISTINCT FROM auth.uid() THEN
    RETURN false;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = 'agency_owner'
  );
END;
$$;

-- user_client_ids: SETOF uuid → empty set, not false
CREATE OR REPLACE FUNCTION public.user_client_ids(_user_id uuid)
RETURNS SETOF uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() <> 'service_role' AND _user_id IS DISTINCT FROM auth.uid() THEN
    RETURN;
  END IF;
  RETURN QUERY
    SELECT id FROM public.clients
      WHERE EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = _user_id AND ur.role IN ('admin','agency_owner')
      )
    UNION
    SELECT client_id FROM public.user_roles
      WHERE user_id = _user_id AND client_id IS NOT NULL;
END;
$$;

-- =============================================================================
-- END — foundation migrations 1–4 (as-built golden master, 2026-06-09)
-- =============================================================================
