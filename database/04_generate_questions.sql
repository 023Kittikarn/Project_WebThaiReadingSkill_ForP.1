-- =====================================================
-- สร้างโจทย์ในตาราง questions อัตโนมัติ จากตารางเนื้อหาที่มีอยู่
-- รันหลัง schema.sql, consonants.sql, content_all.sql
-- รันซ้ำได้ ไม่ซ้ำแถวเดิม (ใช้ source_key กันซ้ำ)
-- =====================================================

-- คอลัมน์อ้างอิงต้นทางของโจทย์ ใช้กันซ้ำและใช้ซิงก์รูป/เสียงทีหลัง
alter table public.questions add column if not exists source_key text;
create unique index if not exists questions_source_key_uq on public.questions (source_key);

-- ---------- ด่าน 1: พยัญชนะ (ไม่รวม ฃ ฅ) ----------
-- 1a) ดูภาพ -> เลือกพยัญชนะต้นของคำ
insert into public.questions (level_id, type, prompt_text, image_path, audio_path, options, answer, source_key)
select 1, 'match_image', 'ภาพนี้ขึ้นต้นด้วยพยัญชนะตัวไหน', c.image_path, null,
  (select jsonb_agg(x.opt order by random()) from (
     select c.letter as opt
     union all
     (select d.letter from public.consonants d
      where d.id <> c.id and not d.is_obsolete order by random() limit 3)) x),
  to_jsonb(c.letter),
  'consonant_img:' || c.id
from public.consonants c
where not c.is_obsolete
on conflict (source_key) do nothing;

-- 1b) ฟังเสียง -> เลือกพยัญชนะ
insert into public.questions (level_id, type, prompt_text, image_path, audio_path, options, answer, source_key)
select 1, 'match_audio', 'ฟังเสียงแล้วเลือกพยัญชนะ', null, c.audio_path,
  (select jsonb_agg(x.opt order by random()) from (
     select c.letter as opt
     union all
     (select d.letter from public.consonants d
      where d.id <> c.id and not d.is_obsolete order by random() limit 3)) x),
  to_jsonb(c.letter),
  'consonant_aud:' || c.id
from public.consonants c
where not c.is_obsolete
on conflict (source_key) do nothing;

-- ---------- ด่าน 2-3: สระ (สั้น = ด่าน 2, ยาว = ด่าน 3) ----------
insert into public.questions (level_id, type, prompt_text, image_path, audio_path, options, answer, source_key)
select case v.length when 'สั้น' then 2 else 3 end,
  'match_audio',
  'พยางค์ "' || v.sample || '" ใช้สระอะไร',
  null, v.audio_path,
  (select jsonb_agg(x.opt order by random()) from (
     select v.symbol as opt
     union all
     (select d.symbol from public.vowels d
      where d.id <> v.id and d.length = v.length order by random() limit 3)) x),
  to_jsonb(v.symbol),
  'vowel:' || v.id
from public.vowels v
on conflict (source_key) do nothing;

-- ---------- ด่าน 4-6: วรรณยุกต์ (กลาง = 4, สูง = 5, ต่ำ = 6) ----------
-- ตัวเลือกคือเสียงวรรณยุกต์ที่เป็นไปได้ของอักษรไตรยางศ์นั้นๆ
insert into public.questions (level_id, type, prompt_text, image_path, audio_path, options, answer, source_key)
select case d.class when 'กลาง' then 4 when 'สูง' then 5 else 6 end,
  'match_audio',
  'คำว่า "' || d.syllable || '" ออกเสียงวรรณยุกต์ใด',
  null, d.audio_path,
  (select jsonb_agg(t2.name_th order by random())
   from public.tones t2
   where t2.id in (select tone_id from public.tone_drills where class = d.class)),
  to_jsonb(t.name_th),
  'tone:' || d.id
from public.tone_drills d
join public.tones t on t.id = d.tone_id
on conflict (source_key) do nothing;

-- ---------- ด่าน 7-8: ตัวสะกด (ตรงมาตรา = 7, ไม่ตรงมาตรา = 8) ----------
insert into public.questions (level_id, type, prompt_text, image_path, audio_path, options, answer, source_key)
select case when w.final_letter = f.standard_letter then 7 else 8 end,
  'match_image',
  case when w.final_letter = f.standard_letter
       then 'คำว่า "' || w.word || '" สะกดด้วยแม่อะไร'
       else 'คำว่า "' || w.word || '" ใช้ ' || w.final_letter || ' สะกด อยู่ในแม่อะไร'
  end,
  w.image_path, w.audio_path,
  (select jsonb_agg(x.opt order by random()) from (
     select f.name_th as opt
     union all
     (select g.name_th from public.final_standards g
      where g.id > 1 and g.id <> f.id order by random() limit 3)) x),
  to_jsonb(f.name_th),
  'final:' || w.id
from public.words w
join public.final_standards f on f.id = w.final_id
where w.final_id > 1
on conflict (source_key) do nothing;

-- ---------- ด่าน 9-10: คำ (แม่ ก กา = 9, มีตัวสะกด = 10) ----------
-- ดูภาพ -> เลือกคำ
insert into public.questions (level_id, type, prompt_text, image_path, audio_path, options, answer, source_key)
select case when w.final_id = 1 then 9 else 10 end,
  'match_image', 'ภาพนี้คือคำว่าอะไร', w.image_path, null,
  (select jsonb_agg(x.opt order by random()) from (
     select w.word as opt
     union all
     (select d.word from public.words d
      where d.id <> w.id and ((d.final_id = 1) = (w.final_id = 1))
      order by random() limit 3)) x),
  to_jsonb(w.word),
  'word_img:' || w.id
from public.words w
on conflict (source_key) do nothing;

-- ฟังเสียง -> เลือกคำ
insert into public.questions (level_id, type, prompt_text, image_path, audio_path, options, answer, source_key)
select case when w.final_id = 1 then 9 else 10 end,
  'match_audio', 'ฟังเสียงแล้วเลือกคำที่ได้ยิน', null, w.audio_path,
  (select jsonb_agg(x.opt order by random()) from (
     select w.word as opt
     union all
     (select d.word from public.words d
      where d.id <> w.id and ((d.final_id = 1) = (w.final_id = 1))
      order by random() limit 3)) x),
  to_jsonb(w.word),
  'word_aud:' || w.id
from public.words w
on conflict (source_key) do nothing;

-- ---------- ด่าน 11: การประสมคำ ----------
-- 11a) เรียงชิ้นส่วน พยัญชนะต้น + สระ + ตัวสะกด (+ วรรณยุกต์) ให้เป็นคำ
with src as (
  select c.id, w.word, w.image_path, w.audio_path,
    jsonb_build_array(c.initial, v.symbol, c.final_letter)
      || case when c.tone_mark <> '' then jsonb_build_array(c.tone_mark) else '[]'::jsonb end as parts
  from public.word_compositions c
  join public.words w  on w.id = c.word_id
  join public.vowels v on v.id = c.vowel_id
)
insert into public.questions (level_id, type, prompt_text, image_path, audio_path, options, answer, source_key)
select 11, 'order_words',
  'เรียงชิ้นส่วนให้เป็นคำว่า "' || s.word || '"',
  s.image_path, s.audio_path,
  (select jsonb_agg(p.piece order by random())
   from jsonb_array_elements_text(s.parts) as p(piece)),
  s.parts,
  'compose:' || s.id
from src s
on conflict (source_key) do nothing;

-- 11b) จับคู่ภาพกับคำศัพท์
insert into public.questions (level_id, type, prompt_text, image_path, audio_path, options, answer, source_key)
select 11, 'match_image', 'เลือกคำที่ตรงกับภาพ', w.image_path, null,
  (select jsonb_agg(x.opt order by random()) from (
     select w.word as opt
     union all
     (select d.word from public.words d where d.id <> w.id order by random() limit 3)) x),
  to_jsonb(w.word),
  'compose_img:' || c.id
from public.word_compositions c
join public.words w on w.id = c.word_id
on conflict (source_key) do nothing;

-- ---------- ด่าน 12: ประโยค (ประธาน + กริยา + กรรม) ----------
insert into public.questions (level_id, type, prompt_text, image_path, audio_path, options, answer, source_key)
select 12, 'order_words', 'เรียงคำให้เป็นประโยค', s.image_path, s.audio_path,
  (select jsonb_agg(p.piece order by random())
   from jsonb_array_elements_text(jsonb_build_array(s.subject, s.verb, s.object)) as p(piece)),
  jsonb_build_array(s.subject, s.verb, s.object),
  'sentence:' || s.id
from public.sentences s
on conflict (source_key) do nothing;

-- ---------- ซิงก์รูป/เสียงจากตารางเนื้อหามาที่ questions ----------
-- ใช้หลังอัปโหลดไฟล์ลง Storage และใส่ image_path/audio_path ในตารางต้นทางแล้ว
-- รันด้วย:  select public.sync_question_media();
create or replace function public.sync_question_media()
returns void
language plpgsql
as $$
begin
  update public.questions q set image_path = c.image_path
    from public.consonants c where q.source_key = 'consonant_img:' || c.id;
  update public.questions q set audio_path = c.audio_path
    from public.consonants c where q.source_key = 'consonant_aud:' || c.id;

  update public.questions q set audio_path = v.audio_path
    from public.vowels v where q.source_key = 'vowel:' || v.id;

  update public.questions q set audio_path = d.audio_path
    from public.tone_drills d where q.source_key = 'tone:' || d.id;

  update public.questions q set image_path = w.image_path, audio_path = w.audio_path
    from public.words w where q.source_key = 'final:' || w.id;
  update public.questions q set image_path = w.image_path
    from public.words w where q.source_key = 'word_img:' || w.id;
  update public.questions q set audio_path = w.audio_path
    from public.words w where q.source_key = 'word_aud:' || w.id;

  update public.questions q set image_path = w.image_path, audio_path = w.audio_path
    from public.word_compositions c join public.words w on w.id = c.word_id
    where q.source_key = 'compose:' || c.id;
  update public.questions q set image_path = w.image_path
    from public.word_compositions c join public.words w on w.id = c.word_id
    where q.source_key = 'compose_img:' || c.id;

  update public.questions q set image_path = s.image_path, audio_path = s.audio_path
    from public.sentences s where q.source_key = 'sentence:' || s.id;
end;
$$;

-- ---------- ตรวจสอบจำนวนโจทย์ ----------
-- ควรได้ด่านละ: 1=84 | 2=16 | 3=12 | 4=10 | 5=6 | 6=6 | 7=29 | 8=8 | 9=24 | 10=74 | 11=28 | 12=12 (รวม 309)
-- select level_id, count(*) from public.questions group by level_id order by level_id;
