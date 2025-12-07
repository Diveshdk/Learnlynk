# LearnLynk – Technical Assessment 

**Submitted by:** Divesh  
**GitHub Repository:** https://github.com/Diveshdk/Learnlynk  
**Submission Date:** December 7, 2025

---

## 📋 Setup Instructions

### Prerequisites
- Node.js 18+ and npm
- A Supabase account (free tier works)

### 1. Clone the Repository
```bash
git clone https://github.com/Diveshdk/Learnlynk.git
cd Learnlynk
```

### 2. Set Up Supabase Database
1. Create a new project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** in your Supabase dashboard
3. Run the following files in order:
   - First: `backend/schema.sql` (creates tables, indexes, constraints)
   - Second: `backend/rls_policies.sql` (enables row-level security)

### 3. Configure Frontend
1. Navigate to frontend directory:
   ```bash
   cd frontend
   ```

2. Copy the environment template:
   ```bash
   cp .env.example .env.local
   ```

3. Get your Supabase credentials from **Settings → API** and update `.env.local`:
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://your-project-id.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
   ```

4. Install dependencies and run:
   ```bash
   npm install
   npm run dev
   ```

5. Open http://localhost:3000/dashboard/today to see the dashboard

### 4. (Optional) Deploy Edge Function
The Edge Function in `backend/edge-functions/create-task/` can be deployed to Supabase Functions:
```bash
npx supabase functions deploy create-task
```

---

## 🔍 Assumptions & Notes

### Architecture Decisions
- **Multi-tenant design**: All tables include `tenant_id` for data isolation
- **RLS simplification**: Since `teams` and `user_teams` tables weren't in scope, the RLS policy focuses on direct ownership (counselors see leads where they're the `owner_id`, admins see all tenant leads)
- **JWT structure**: Assumed JWT claims include `user_id`, `role`, and `tenant_id` as specified

### Database Design
- Used `uuid` for all IDs for better security and distribution
- Added composite indexes for common query patterns (e.g., `tenant_id + owner_id` for leads)
- Check constraints enforce data integrity at the database level
- `ON DELETE CASCADE` ensures cleanup when parent records are deleted

### Edge Function
- Added `@ts-nocheck` directive since Deno modules don't resolve in standard Node.js environments
- Validates all inputs before database operations
- Fetches `tenant_id` from the application to maintain multi-tenant security
- Returns proper HTTP status codes (400 for validation, 500 for errors)

### Frontend
- Used Next.js Pages Router as per existing project structure
- Implemented proper loading and error states
- Date filtering uses PostgreSQL date range queries for efficiency
- Mark complete updates status locally for instant UI feedback

### What I Would Add With More Time
- Authentication flow with proper user login
- Unit tests for Edge Function validation logic
- Integration tests for database operations
- Frontend tests with React Testing Library
- Error boundary components for better error handling
- Pagination for tasks list
- Filters by task type and status
- Real-time subscriptions using Supabase Realtime

---

## 📁 Project Structure

```
learnlynk-tech-test/
├── backend/
│   ├── schema.sql                    # Database tables and indexes
│   ├── rls_policies.sql              # Row-level security policies
│   └── edge-functions/
│       └── create-task/
│           ├── index.ts              # Task creation Edge Function
│           └── deno.json             # Deno configuration
├── frontend/
│   ├── pages/
│   │   └── dashboard/
│   │       └── today.tsx             # Today's tasks dashboard
│   ├── lib/
│   │   └── supabaseClient.ts         # Supabase client config
│   ├── .env.example                  # Environment template
│   └── package.json
└── README.md                         # This file
```

---

Thanks for taking the time to complete this assessment. The goal is to understand how you think about problems and how you structure real project work. This is a small, self-contained exercise that should take around **2–3 hours**. It's completely fine if you don't finish everything—just note any assumptions or TODOs.earnLynk – Technical Assessment 



## Stripe Answer

To implement a Stripe Checkout flow for an application fee, I would follow this approach:

1. **Create Payment Request**: When the counselor initiates payment, insert a row in `payment_requests` with `application_id`, `amount`, `currency`, and `status: 'pending'`. Store the payment request ID.

2. **Call Stripe API**: Use a Supabase Edge Function to call `stripe.checkout.sessions.create()` with the payment amount, success/cancel URLs, and metadata containing the `payment_request_id` and `application_id`.

3. **Store Checkout Session**: Save the Stripe `session_id` and `session_url` in the `payment_requests` table, then redirect the user to the checkout page via the `session_url`.

4. **Handle Webhooks**: Set up a webhook endpoint listening for `checkout.session.completed` events. Verify the webhook signature, extract the session metadata, and update the `payment_requests` status to 'paid' with the payment intent ID and timestamp.

5. **Update Application**: In the webhook handler, after confirming payment, update the `applications` table setting `payment_status: 'paid'` and `paid_at: now()`. Optionally trigger any downstream workflows like sending confirmation emails or advancing the application stage.

6. **Idempotency**: Use the Stripe event ID as an idempotency key when processing webhooks to prevent duplicate updates if the webhook is received multiple times.
