-- LearnLynk Tech Test - Task 2: RLS Policies on leads

alter table public.leads enable row level security;

-- Example helper: assume JWT has tenant_id, user_id, role.
-- You can use: current_setting('request.jwt.claims', true)::jsonb

-- SELECT Policy:
-- - Counselors see leads where they are the owner_id
-- - Admins can see all leads of their tenant

create policy "leads_select_policy"
on public.leads
for select
using (
  (
    -- Extract JWT claims - tenant must match
    (current_setting('request.jwt.claims', true)::jsonb->>'tenant_id')::uuid = tenant_id
  )
  and
  (
    -- Admins can see all leads in their tenant
    (current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin'
    or
    -- Counselors can see leads they own
    (
      (current_setting('request.jwt.claims', true)::jsonb->>'role') = 'counselor'
      and
      owner_id = (current_setting('request.jwt.claims', true)::jsonb->>'user_id')::uuid
    )
  )
);

-- INSERT Policy:
-- - Allows counselors/admins to insert leads for their tenant
-- - Ensures tenant_id matches the user's tenant

create policy "leads_insert_policy"
on public.leads
for insert
with check (
  -- User must be counselor or admin
  (current_setting('request.jwt.claims', true)::jsonb->>'role') in ('counselor', 'admin')
  and
  -- Tenant ID must match the user's tenant
  tenant_id = (current_setting('request.jwt.claims', true)::jsonb->>'tenant_id')::uuid
);
