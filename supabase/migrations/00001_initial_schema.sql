-- LearnLynk Tech Test - Task 1: Schema
-- Fill in the definitions for leads, applications, tasks as per README.

create extension if not exists "pgcrypto";

-- Leads table
create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  owner_id uuid not null,
  email text,
  phone text,
  full_name text,
  stage text not null default 'new',
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes for leads
create index if not exists idx_leads_tenant_id on public.leads(tenant_id);
create index if not exists idx_leads_owner_id on public.leads(owner_id);
create index if not exists idx_leads_stage on public.leads(stage);
create index if not exists idx_leads_tenant_owner on public.leads(tenant_id, owner_id);
create index if not exists idx_leads_created_at on public.leads(created_at desc);


-- Applications table
create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  lead_id uuid not null references public.leads(id) on delete cascade,
  program_id uuid,
  intake_id uuid,
  stage text not null default 'inquiry',
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes for applications
create index if not exists idx_applications_tenant_id on public.applications(tenant_id);
create index if not exists idx_applications_lead_id on public.applications(lead_id);
create index if not exists idx_applications_tenant_lead on public.applications(tenant_id, lead_id);


-- Tasks table
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  application_id uuid not null references public.applications(id) on delete cascade,
  title text,
  type text not null,
  status text not null default 'open',
  due_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint check_task_type check (type in ('call', 'email', 'review')),
  constraint check_due_at_after_created check (due_at >= created_at)
);

-- Indexes for tasks
create index if not exists idx_tasks_tenant_id on public.tasks(tenant_id);
create index if not exists idx_tasks_due_at on public.tasks(due_at);
create index if not exists idx_tasks_status on public.tasks(status);
create index if not exists idx_tasks_tenant_due_status on public.tasks(tenant_id, due_at, status);
create index if not exists idx_tasks_application_id on public.tasks(application_id);
-- LearnLynk Tech Test - Task 2: RLS Policies on leads

alter table public.leads enable row level security;

-- Example helper: assume JWT has tenant_id, user_id, role.
-- You can use: current_setting('request.jwt.claims', true)::jsonb

-- SELECT Policy:
-- - Counselors see leads where they are owner_id OR in one of their teams
-- - Admins can see all leads of their tenant

create policy "leads_select_policy"
on public.leads
for select
using (
  (
    -- Extract JWT claims
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
      (
        owner_id = (current_setting('request.jwt.claims', true)::jsonb->>'user_id')::uuid
        or
        -- Or leads assigned to teams they belong to
        exists (
          select 1
          from public.user_teams ut
          join public.teams t on ut.team_id = t.id
          join public.leads l on l.team_id = t.id
          where ut.user_id = (current_setting('request.jwt.claims', true)::jsonb->>'user_id')::uuid
          and l.id = leads.id
        )
      )
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
