-- =====================================================
-- Thai literacy game for Primary 1 (ป.1) - Supabase / PostgreSQL schema
-- Run in Supabase: SQL Editor -> New query -> paste -> Run
-- =====================================================

-- ---------- 1. Tables ----------

-- Kid profiles. The guardian logs in via Supabase Auth (auth.users);
-- each guardian can have several kid profiles (nickname only, no real data needed).
create table public.profiles (
  id           uuid primary key default gen_random_uuid(),
  guardian_id  uuid not null references auth.users(id) on delete cascade,
  nickname     text not null,
  avatar       text,
  created_at   timestamptz not null default now()
);
create index on public.profiles (guardian_id);

-- Main stages (ด่านหลัก): consonants, vowels, tones, ...
create table public.stages (
  id         smallint primary key,
  code       text not null unique,
  name_th    text not null
);

-- Playable levels (ด่านย่อย). sort_order is the GLOBAL play order used for unlocking.
create table public.levels (
  id          smallint primary key,
  stage_id    smallint not null references public.stages(id),
  code        text not null unique,
  name_th     text not null,
  sort_order  smallint not null unique,
  pass_score  smallint not null default 80   -- % needed to pass
);
create index on public.levels (stage_id);

-- Questions inside each level.
-- type: match_image | match_audio | order_words
-- options/answer are jsonb so one table fits every question style, e.g.
--   match_image : options = ["ก","ข","ค"], answer = "ก", image_path = 'img/ko-kai.png'
--   order_words : options = ["แมว","ฉัน","ชอบ"], answer = ["ฉัน","ชอบ","แมว"]
create table public.questions (
  id          uuid primary key default gen_random_uuid(),
  level_id    smallint not null references public.levels(id) on delete cascade,
  type        text not null check (type in ('match_image','match_audio','order_words')),
  prompt_text text,
  image_path  text,          -- path in Supabase Storage
  audio_path  text,          -- path in Supabase Storage
  options     jsonb not null default '[]'::jsonb,
  answer      jsonb not null,
  created_at  timestamptz not null default now()
);
create index on public.questions (level_id);

-- Progress per kid per level
create table public.progress (
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  level_id    smallint not null references public.levels(id),
  status      text not null default 'in_progress' check (status in ('in_progress','passed')),
  best_score  smallint not null default 0,
  play_count  integer not null default 0,
  passed_at   timestamptz,
  updated_at  timestamptz not null default now(),
  primary key (profile_id, level_id)
);

-- Optional: every answer, useful to see which letters/words a kid misses most
create table public.attempts (
  id           bigint generated always as identity primary key,
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  question_id  uuid not null references public.questions(id) on delete cascade,
  is_correct   boolean not null,
  answer_given jsonb,
  created_at   timestamptz not null default now()
);
create index on public.attempts (profile_id, created_at desc);

-- ---------- 2. Helper functions ----------

-- Does this authenticated user own the kid profile?
create or replace function public.owns_profile(p_profile uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = p_profile and guardian_id = auth.uid()
  );
$$;

-- Is the level unlocked for this kid?
-- Unlocked if it is the first level, or the previous level (by sort_order) is 'passed'.
create or replace function public.is_level_unlocked(p_profile uuid, p_level smallint)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce((
    select coalesce(pr.status = 'passed', false)
    from public.levels prev
    left join public.progress pr
      on pr.level_id = prev.id and pr.profile_id = p_profile
    where prev.sort_order < (select sort_order from public.levels where id = p_level)
    order by prev.sort_order desc
    limit 1
  ), true);   -- no previous level => first level => unlocked
$$;

-- ---------- 3. Row Level Security ----------

alter table public.profiles  enable row level security;
alter table public.stages    enable row level security;
alter table public.levels    enable row level security;
alter table public.questions enable row level security;
alter table public.progress  enable row level security;
alter table public.attempts  enable row level security;

-- Content: any logged-in user can read, nobody can write from the client
create policy "read stages"    on public.stages    for select to authenticated using (true);
create policy "read levels"    on public.levels    for select to authenticated using (true);
create policy "read questions" on public.questions for select to authenticated using (true);

-- Profiles: guardian manages only their own kids
create policy "guardian select profiles" on public.profiles
  for select to authenticated using (guardian_id = auth.uid());
create policy "guardian insert profiles" on public.profiles
  for insert to authenticated with check (guardian_id = auth.uid());
create policy "guardian update profiles" on public.profiles
  for update to authenticated using (guardian_id = auth.uid()) with check (guardian_id = auth.uid());
create policy "guardian delete profiles" on public.profiles
  for delete to authenticated using (guardian_id = auth.uid());

-- Progress: only own kids, and only for levels that are unlocked
create policy "select own progress" on public.progress
  for select to authenticated using (public.owns_profile(profile_id));
create policy "insert progress if unlocked" on public.progress
  for insert to authenticated
  with check (public.owns_profile(profile_id) and public.is_level_unlocked(profile_id, level_id));
create policy "update progress if unlocked" on public.progress
  for update to authenticated
  using (public.owns_profile(profile_id))
  with check (public.owns_profile(profile_id) and public.is_level_unlocked(profile_id, level_id));

-- Attempts: only own kids
create policy "select own attempts" on public.attempts
  for select to authenticated using (public.owns_profile(profile_id));
create policy "insert own attempts" on public.attempts
  for insert to authenticated with check (public.owns_profile(profile_id));

-- ---------- 4. Seed data: stages and levels ----------

insert into public.stages (id, code, name_th) values
  (1, 'consonants',       'พยัญชนะ'),
  (2, 'vowels',           'สระ'),
  (3, 'tones',            'วรรณยุกต์'),
  (4, 'final_consonants', 'ตัวสะกด'),
  (5, 'words',            'คำ'),
  (6, 'word_building',    'การประสมคำ'),
  (7, 'sentences',        'ประโยค');

insert into public.levels (id, stage_id, code, name_th, sort_order) values
  (1,  1, 'consonants',       'พยัญชนะ',                 1),
  (2,  2, 'vowels_short',     'สระเสียงสั้น',             2),
  (3,  2, 'vowels_long',      'สระเสียงยาว',              3),
  (4,  3, 'tones_middle',     'อักษรกลาง',                4),
  (5,  3, 'tones_high',       'อักษรสูง',                 5),
  (6,  3, 'tones_low',        'อักษรต่ำ',                 6),
  (7,  4, 'final_standard',   'ตัวสะกดตรงตามมาตรา',       7),
  (8,  4, 'final_nonstandard','ตัวสะกดไม่ตรงตามมาตรา',    8),
  (9,  5, 'words_ma_ka',      'คำ แม่ ก กา',              9),
  (10, 5, 'words_final',      'คำที่มีตัวสะกด',           10),
  (11, 6, 'word_building',    'การประสมคำ',               11),
  (12, 7, 'sentences',        'ประโยค (ประธาน+กริยา+กรรม)', 12);

-- ---------- 5. Example queries ----------
-- Is level 4 unlocked for this kid?
--   select public.is_level_unlocked('<profile_uuid>', 4::smallint);
--
-- Levels + status for one kid:
--   select l.sort_order, l.name_th, coalesce(p.status,'locked/not started') as status
--   from public.levels l
--   left join public.progress p on p.level_id = l.id and p.profile_id = '<profile_uuid>'
--   order by l.sort_order;
