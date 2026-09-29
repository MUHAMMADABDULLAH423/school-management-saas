/*
  School Management SaaS — demo seed
  ===================================
  1. Run supabase/schema.sql first.
  2. Create 4 users in Supabase Auth (dashboard → Authentication → Users):
       superadmin@demo.pk / School Admin  → admin@greenwood.demo.pk
       teacher@demo.pk (Ayesha Khan)     → teacher@greenwood.demo.pk
       parent@demo.pk  (Bilal Ahmed)      → parent@greenwood.demo.pk
     Copy each user's UUID from the dashboard.
  3. Replace the four UUID placeholders below, then run this file.
*/

begin;

-- Demo tenant (fixed UUID so the rest of the seed can reference it)
insert into public.schools (id, name, name_ur, address, phone, email, plan, status)
values ('11111111-1111-1111-1111-111111111111'::uuid,
        'Green Wood School', 'گرین ووڈ اسکول',
        'Korangi Industrial Area, Karachi', '021-35000000',
        'info@greenwood.demo.pk', 'standard', 'active')
on conflict (id) do nothing;

-- ---- Users (REPLACE the UUIDs with real Auth user ids) ----
-- insert into public.users (id, school_id, email, full_name, role, status) values
--   ('SUPERADMIN-UUID', null, 'superadmin@demo.pk', 'Super Admin', 'super_admin', 'active'),
--   ('SCHOOLADMIN-UUID', '11111111-1111-1111-1111-111111111111', 'admin@greenwood.demo.pk', 'Principal Ahmed', 'school_admin', 'active'),
--   ('TEACHER-UUID', '11111111-1111-1111-1111-111111111111', 'teacher@greenwood.demo.pk', 'Ayesha Khan', 'teacher', 'active'),
--   ('PARENT-UUID', '11111111-1111-1111-1111-111111111111', 'parent@greenwood.demo.pk', 'Bilal Ahmed', 'parent', 'active');

-- ---- Staff row for the teacher (uncomment after users exist) ----
-- insert into public.staff (school_id, user_id, employee_no, name, designation, subjects, phone)
-- values ('11111111-1111-1111-1111-111111111111', 'TEACHER-UUID',
--         'EMP-001', 'Ayesha Khan', 'teacher', '{Mathematics,Science}', '0300-0000001');

-- ---- Classes ----
insert into public.classes (id, school_id, name, section, academic_year)
values
  ('22222222-2222-2222-2222-222222222222'::uuid, '11111111-1111-1111-1111-111111111111', 'Grade 5', 'A', '2026-27'),
  ('33333333-3333-3333-3333-333333333333'::uuid, '11111111-1111-1111-1111-111111111111', 'Grade 5', 'B', '2026-27'),
  ('44444444-4444-4444-4444-444444444444'::uuid, '11111111-1111-1111-1111-111111111111', 'Grade 6', 'A', '2026-27')
on conflict do nothing;

-- ---- Students (10 demo) ----
insert into public.students
  (school_id, admission_no, name, name_ur, father_name, gender, class_id, phone)
select '11111111-1111-1111-1111-111111111111',
       'ADM-2026-' || lpad(g::text, 3, '0'),
       s.name, s.name_ur, s.father, s.gender,
       (case when g <= 4 then '22222222-2222-2222-2222-222222222222'
             when g <= 7 then '33333333-3333-3333-333333333333'
             else '44444444-4444-4444-444444444444' end)::uuid,
       '0300-00000' || lpad(g::text, 2, '0')
from generate_series(1, 10) g
join (values
  ('Ali Raza', 'علی رضا', 'Bilal Ahmed', 'male'),
  ('Fatima Noor', 'فاطمہ نور', 'Imran Sheikh', 'female'),
  ('Usman Tariq', 'عثمان طارق', 'Tariq Mehmood', 'male'),
  ('Areeba Khan', 'عریبہ خان', 'Kamran Khan', 'female'),
  ('Hamza Yousuf', 'حمزہ یوسف', 'Yousuf Ali', 'male'),
  ('Zainab Bibi', 'زینب بی بی', 'Rashid Minhas', 'female'),
  ('Danish Ali', 'دانش علی', 'Nadeem Ali', 'male'),
  ('Mahnoor Fatima', 'ماہ نور فاطمہ', 'Shahid Iqbal', 'female'),
  ('Abdullah Jan', 'عبداللہ جان', 'Jan Muhammad', 'male'),
  ('Iqra Saleem', 'اقرا سلیم', 'Saleem Raza', 'female')
) as s(name, name_ur, father, gender) on true
on conflict do nothing;

-- ---- Exam ----
insert into public.exams (school_id, name, name_ur, academic_year, result_published)
values ('11111111-1111-1111-1111-111111111111',
        'First Term', 'پہلی سہ ماہی', '2026-27', false)
on conflict do nothing;

-- ---- Fee vouchers for October 2026 (one per student) ----
insert into public.fee_vouchers
  (school_id, student_id, title, month, amount, discount, due_date, created_by)
select '11111111-1111-1111-1111-111111111111', st.id,
       'October 2026 Fee', date '2026-10-01', 2500, 0, date '2026-10-10', null
from public.students st
where st.school_id = '11111111-1111-1111-1111-111111111111'
on conflict do nothing;

-- ---- Notice ----
insert into public.notices
  (school_id, title, title_ur, content, content_ur, audience, posted_by)
select '11111111-1111-1111-1111-111111111111',
       'Parent-Teacher Meeting', 'والدین اساتذہ میٹنگ',
       'PTM will be held on Saturday at 10 AM in the school hall.',
       'ہفتے کو صبح 10 بجے اسکول ہال میں پی ٹی ایم ہوگی۔',
       'school_wide', u.id
from public.users u
where u.role = 'school_admin'
  and u.school_id = '11111111-1111-1111-1111-111111111111'
limit 1
on conflict do nothing;

commit;
