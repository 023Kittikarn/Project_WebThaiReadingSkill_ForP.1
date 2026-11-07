-- =====================================================
-- เนื้อหาทุกหมวด (ต่อจาก schema.sql และ consonants.sql)
-- ด่าน 2-3  สระ                  -> vowels
-- ด่าน 4-6  วรรณยุกต์            -> tones, tone_rules, tone_drills
-- ด่าน 7-8  ตัวสะกด              -> final_standards
-- ด่าน 9-10 คำ                   -> words
-- ด่าน 11   การประสมคำ           -> word_compositions (+ words ที่มีรูป)
-- ด่าน 12   ประโยค               -> sentences
-- รันทั้งไฟล์ใน SQL Editor ได้เลย
-- =====================================================

-- ---------- 1. สระ ----------
create table public.vowels (
  id          smallint primary key,
  symbol      text not null unique,      -- รูปสระ เช่น อะ
  length      text not null check (length in ('สั้น','ยาว')),
  pair_group  text not null,             -- คู่เสียงสั้น-ยาว เช่น a, i, ue ('special' = สระเกิน)
  sample      text not null,             -- พยางค์ตัวอย่างแจกลูกด้วย ก
  image_path  text,
  audio_path  text
);

insert into public.vowels (id, symbol, length, pair_group, sample) values
  (1,  'อะ',   'สั้น', 'a',   'กะ'),
  (2,  'อา',   'ยาว', 'a',   'กา'),
  (3,  'อิ',   'สั้น', 'i',   'กิ'),
  (4,  'อี',   'ยาว', 'i',   'กี'),
  (5,  'อึ',   'สั้น', 'ue',  'กึ'),
  (6,  'อือ',  'ยาว', 'ue',  'กือ'),
  (7,  'อุ',   'สั้น', 'u',   'กุ'),
  (8,  'อู',   'ยาว', 'u',   'กู'),
  (9,  'เอะ',  'สั้น', 'e',   'เกะ'),
  (10, 'เอ',   'ยาว', 'e',   'เก'),
  (11, 'แอะ',  'สั้น', 'ae',  'แกะ'),
  (12, 'แอ',   'ยาว', 'ae',  'แก'),
  (13, 'โอะ',  'สั้น', 'o',   'โกะ'),
  (14, 'โอ',   'ยาว', 'o',   'โก'),
  (15, 'เอาะ', 'สั้น', 'or',  'เกาะ'),
  (16, 'ออ',   'ยาว', 'or',  'กอ'),
  (17, 'เออะ', 'สั้น', 'oe',  'เกอะ'),
  (18, 'เออ',  'ยาว', 'oe',  'เกอ'),
  (19, 'เอียะ','สั้น', 'ia',  'เกียะ'),
  (20, 'เอีย', 'ยาว', 'ia',  'เกีย'),
  (21, 'เอือะ','สั้น', 'uea', 'เกือะ'),
  (22, 'เอือ', 'ยาว', 'uea', 'เกือ'),
  (23, 'อัวะ', 'สั้น', 'ua',  'กัวะ'),
  (24, 'อัว',  'ยาว', 'ua',  'กัว'),
  -- สระเกิน (นับเป็นเสียงสั้น)
  (25, 'อำ',   'สั้น', 'special', 'กำ'),
  (26, 'ไอ',   'สั้น', 'special', 'ไก'),
  (27, 'ใอ',   'สั้น', 'special', 'ใก'),
  (28, 'เอา',  'สั้น', 'special', 'เกา');

-- ---------- 2. วรรณยุกต์ ----------
create table public.tones (
  id            smallint primary key,
  name_th       text not null unique,    -- สามัญ เอก โท ตรี จัตวา
  mark          text not null,           -- รูปวรรณยุกต์ ('' = ไม่มีรูป)
  mark_name_th  text
);

insert into public.tones (id, name_th, mark, mark_name_th) values
  (1, 'สามัญ', '',  null),
  (2, 'เอก',   '่', 'ไม้เอก'),
  (3, 'โท',    '้', 'ไม้โท'),
  (4, 'ตรี',   '๊', 'ไม้ตรี'),
  (5, 'จัตวา', '๋', 'ไม้จัตวา');

-- กฎการผันเสียง: ไตรยางศ์ + ชนิดพยางค์ + รูปวรรณยุกต์ => เสียงวรรณยุกต์
create table public.tone_rules (
  id             smallint generated always as identity primary key,
  class          text not null check (class in ('กลาง','สูง','ต่ำ')),
  syllable_type  text not null check (syllable_type in ('เป็น','ตาย','ตาย-สั้น','ตาย-ยาว')),
  mark           text not null,          -- '' = ไม่มีรูป
  tone_id        smallint not null references public.tones(id),
  unique (class, syllable_type, mark)
);

insert into public.tone_rules (class, syllable_type, mark, tone_id) values
  -- อักษรกลาง คำเป็น (ผันได้ 5 เสียง)
  ('กลาง','เป็น','',  1), ('กลาง','เป็น','่',2), ('กลาง','เป็น','้',3),
  ('กลาง','เป็น','๊',4), ('กลาง','เป็น','๋',5),
  -- อักษรกลาง คำตาย
  ('กลาง','ตาย','',  2), ('กลาง','ตาย','้',3), ('กลาง','ตาย','๊',4), ('กลาง','ตาย','๋',5),
  -- อักษรสูง
  ('สูง','เป็น','',  5), ('สูง','เป็น','่',2), ('สูง','เป็น','้',3),
  ('สูง','ตาย','',   2), ('สูง','ตาย','่', 2), ('สูง','ตาย','้', 3),
  -- อักษรต่ำ
  ('ต่ำ','เป็น','',  1), ('ต่ำ','เป็น','่',3), ('ต่ำ','เป็น','้',4),
  ('ต่ำ','ตาย-สั้น','',4), ('ต่ำ','ตาย-สั้น','่',3), ('ต่ำ','ตาย-สั้น','้',4),
  ('ต่ำ','ตาย-ยาว','',3), ('ต่ำ','ตาย-ยาว','่',3), ('ต่ำ','ตาย-ยาว','้',4);

-- แบบฝึกแจกลูกวรรณยุกต์ (คำเป็น) ใช้ทำโจทย์ด่าน 4-6
create table public.tone_drills (
  id           smallint generated always as identity primary key,
  class        text not null check (class in ('กลาง','สูง','ต่ำ')),
  base_letter  text not null,
  syllable     text not null,
  mark         text not null,
  tone_id      smallint not null references public.tones(id),
  image_path   text,
  audio_path   text
);

insert into public.tone_drills (class, base_letter, syllable, mark, tone_id) values
  ('กลาง','ก','กา', '',  1), ('กลาง','ก','ก่า','่',2), ('กลาง','ก','ก้า','้',3),
  ('กลาง','ก','ก๊า','๊',4), ('กลาง','ก','ก๋า','๋',5),
  ('กลาง','จ','จา', '',  1), ('กลาง','จ','จ่า','่',2), ('กลาง','จ','จ้า','้',3),
  ('กลาง','จ','จ๊า','๊',4), ('กลาง','จ','จ๋า','๋',5),
  ('สูง','ข','ขา', '',  5), ('สูง','ข','ข่า','่',2), ('สูง','ข','ข้า','้',3),
  ('สูง','ส','สา', '',  5), ('สูง','ส','ส่า','่',2), ('สูง','ส','ส้า','้',3),
  ('ต่ำ','ค','คา', '',  1), ('ต่ำ','ค','ค่า','่',3), ('ต่ำ','ค','ค้า','้',4),
  ('ต่ำ','ม','มา', '',  1), ('ต่ำ','ม','ม่า','่',3), ('ต่ำ','ม','ม้า','้',4);

-- ---------- 3. ตัวสะกด (มาตราตัวสะกด) ----------
create table public.final_standards (
  id                   smallint primary key,
  code                 text not null unique,
  name_th              text not null,        -- แม่กก ...
  standard_letter      text,                 -- ตัวสะกดตรงตามมาตรา (ด่าน 7)
  non_standard_letters text[] not null default '{}',   -- ตัวสะกดไม่ตรงตามมาตรา (ด่าน 8)
  end_sound            text,
  is_dead              boolean not null default false  -- แม่กก กด กบ = คำตาย
);

insert into public.final_standards
  (id, code, name_th, standard_letter, non_standard_letters, end_sound, is_dead) values
  (1, 'ma_ka', 'แม่ ก กา',  null, '{}', null, false),
  (2, 'kok',   'แม่กก',  'ก', '{ข,ค,ฆ}', 'k', true),
  (3, 'kot',   'แม่กด',  'ด', '{จ,ช,ซ,ฎ,ฏ,ฐ,ฑ,ฒ,ต,ถ,ท,ธ,ศ,ษ,ส}', 't', true),
  (4, 'kop',   'แม่กบ',  'บ', '{ป,พ,ฟ,ภ}', 'p', true),
  (5, 'kong',  'แม่กง',  'ง', '{}', 'ng', false),
  (6, 'kon',   'แม่กน',  'น', '{ญ,ณ,ร,ล,ฬ}', 'n', false),
  (7, 'kom',   'แม่กม',  'ม', '{}', 'm', false),
  (8, 'koei',  'แม่เกย', 'ย', '{}', 'y', false),
  (9, 'koeo',  'แม่เกอว','ว', '{}', 'w', false);

-- ---------- 4. คำศัพท์ ----------
-- final_id = 1 (แม่ ก กา) คือคำที่ไม่มีตัวสะกด
-- ตรงตามมาตรา  : final_letter = final_standards.standard_letter
-- ไม่ตรงตามมาตรา: final_letter อยู่ใน final_standards.non_standard_letters
create table public.words (
  id              integer generated always as identity primary key,
  word            text not null unique,
  syllable_count  smallint not null default 1,
  final_id        smallint not null references public.final_standards(id),
  final_letter    text,
  image_path      text,
  audio_path      text
);
create index on public.words (final_id);

insert into public.words (word, syllable_count, final_id, final_letter) values
  -- แม่ ก กา (ด่าน 9)
  ('ตา',1,1,null), ('หู',1,1,null), ('ปู',1,1,null), ('มือ',1,1,null),
  ('ปลา',1,1,null), ('ม้า',1,1,null), ('หมู',1,1,null), ('ขา',1,1,null),
  ('ผ้า',1,1,null), ('ไก่',1,1,null), ('ไข่',1,1,null), ('เสือ',1,1,null),
  -- แม่กก
  ('นก',1,2,'ก'), ('ปาก',1,2,'ก'), ('ลูก',1,2,'ก'), ('ผัก',1,2,'ก'),
  ('เลข',1,2,'ข'), ('โรค',1,2,'ค'),
  -- แม่กด
  ('กด',1,3,'ด'), ('ปิด',1,3,'ด'), ('ขวด',1,3,'ด'), ('รถ',1,3,'ถ'), ('บาท',1,3,'ท'),
  -- แม่กบ
  ('กบ',1,4,'บ'), ('ขอบ',1,4,'บ'), ('จบ',1,4,'บ'), ('รูป',1,4,'ป'), ('ภาพ',1,4,'พ'),
  -- แม่กง
  ('ช้าง',1,5,'ง'), ('ลิง',1,5,'ง'), ('โรง',1,5,'ง'), ('ลุง',1,5,'ง'),
  -- แม่กน
  ('กิน',1,6,'น'), ('บ้าน',1,6,'น'), ('ฟัน',1,6,'น'), ('ผล',1,6,'ล'), ('ทหาร',2,6,'ร'),
  -- แม่กม
  ('ลม',1,7,'ม'), ('ผม',1,7,'ม'), ('ส้ม',1,7,'ม'), ('ขนม',2,7,'ม'),
  -- แม่เกย
  ('ควาย',1,8,'ย'), ('นาย',1,8,'ย'), ('สาย',1,8,'ย'), ('ชาย',1,8,'ย'),
  -- แม่เกอว
  ('ดาว',1,9,'ว'), ('ข้าว',1,9,'ว'), ('แมว',1,9,'ว'), ('ขาว',1,9,'ว');

-- ---------- 5. การประสมคำ (ด่าน 11) ----------
-- แยกชิ้นส่วนของคำ: พยัญชนะต้น + สระ + ตัวสะกด (+ วรรณยุกต์) ให้ผู้เล่นจับคู่/ประกอบ
-- หมายเหตุ: ผัก ใช้สระอะที่เขียนเป็นไม้หันอากาศ (ั)
create table public.word_compositions (
  id            integer generated always as identity primary key,
  word_id       integer not null references public.words(id) on delete cascade,
  initial       text not null,
  vowel_id      smallint not null references public.vowels(id),
  final_letter  text not null,
  tone_mark     text not null default ''
);

insert into public.word_compositions (word_id, initial, vowel_id, final_letter, tone_mark)
select w.id, c.initial, c.vowel_id, c.final_letter, c.tone_mark
from (values
  ('ปาก','ป',2,'ก',''),
  ('ลูก','ล',8,'ก',''),
  ('ช้าง','ช',2,'ง','้'),
  ('ลิง','ล',3,'ง',''),
  ('บ้าน','บ',2,'น','้'),
  ('ดาว','ด',2,'ว',''),
  ('นาย','น',2,'ย',''),
  ('ข้าว','ข',2,'ว','้'),
  ('ขอบ','ข',16,'บ',''),
  ('ผัก','ผ',1,'ก',''),
  ('รูป','ร',8,'ป',''),
  ('กิน','ก',3,'น',''),
  ('ลุง','ล',7,'ง',''),
  ('ภาพ','ภ',2,'พ','')
) as c(word, initial, vowel_id, final_letter, tone_mark)
join public.words w on w.word = c.word;

-- ---------- 6. ประโยค (ด่าน 12) ----------
-- ประธาน + กริยา + กรรม ; sentence ต่อคำให้อัตโนมัติ (ภาษาไทยไม่เว้นวรรค)
create table public.sentences (
  id          smallint generated always as identity primary key,
  subject     text not null,
  verb        text not null,
  object      text not null,
  sentence    text generated always as (subject || verb || object) stored,
  image_path  text,
  audio_path  text
);

insert into public.sentences (subject, verb, object) values
  ('ฉัน','ชอบ','แมว'),
  ('แมว','กิน','ปลา'),
  ('หมา','กิน','ข้าว'),
  ('แม่','ซื้อ','ไข่'),
  ('พ่อ','ขับ','รถ'),
  ('น้อง','ดื่ม','นม'),
  ('เด็ก','เล่น','บอล'),
  ('ฉัน','กิน','ส้ม'),
  ('ลิง','กิน','กล้วย'),
  ('วัว','กิน','หญ้า'),
  ('ฉัน','ล้าง','มือ'),
  ('ฉัน','อ่าน','หนังสือ');

-- ---------- 7. RLS: ทุกตารางเนื้อหาอ่านได้อย่างเดียว ----------
alter table public.vowels            enable row level security;
alter table public.tones             enable row level security;
alter table public.tone_rules        enable row level security;
alter table public.tone_drills       enable row level security;
alter table public.final_standards   enable row level security;
alter table public.words             enable row level security;
alter table public.word_compositions enable row level security;
alter table public.sentences         enable row level security;

create policy "read vowels"            on public.vowels            for select to authenticated using (true);
create policy "read tones"             on public.tones             for select to authenticated using (true);
create policy "read tone_rules"        on public.tone_rules        for select to authenticated using (true);
create policy "read tone_drills"       on public.tone_drills       for select to authenticated using (true);
create policy "read final_standards"   on public.final_standards   for select to authenticated using (true);
create policy "read words"             on public.words             for select to authenticated using (true);
create policy "read word_compositions" on public.word_compositions for select to authenticated using (true);
create policy "read sentences"         on public.sentences         for select to authenticated using (true);

-- ---------- 8. ตรวจสอบจำนวนแถว ----------
-- ควรได้: vowels 28 | tones 5 | tone_rules 24 | tone_drills 22 | final_standards 9
--         words 49 | word_compositions 14 | sentences 12
-- select 'vowels' t, count(*) from public.vowels
-- union all select 'tones', count(*) from public.tones
-- union all select 'tone_rules', count(*) from public.tone_rules
-- union all select 'tone_drills', count(*) from public.tone_drills
-- union all select 'final_standards', count(*) from public.final_standards
-- union all select 'words', count(*) from public.words
-- union all select 'word_compositions', count(*) from public.word_compositions
-- union all select 'sentences', count(*) from public.sentences;
