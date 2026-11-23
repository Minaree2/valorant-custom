-- VALORANT CUSTOM: Supabase schema + server-validated host actions
create extension if not exists pgcrypto;

create table if not exists public.rooms (
  code text primary key check (code ~ '^[A-Z0-9]{6}$'),
  host_token_hash text not null,
  state jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.rooms enable row level security;
drop policy if exists "rooms_read_for_live_room" on public.rooms;
create policy "rooms_read_for_live_room" on public.rooms
  for select to anon, authenticated using (true);
-- No direct INSERT/UPDATE/DELETE policies: clients must use the RPC functions.
alter publication supabase_realtime add table public.rooms;

create or replace function public.create_room(p_code text, p_host_token text, p_name text)
returns jsonb language plpgsql security definer set search_path=public, extensions as $$
declare s jsonb;
begin
  if length(trim(p_name))=0 or length(p_name)>16 then raise exception '닉네임은 1~16자여야 합니다.'; end if;
  if length(p_host_token)<32 then raise exception '잘못된 방장 토큰입니다.'; end if;
  s=jsonb_build_object('players',jsonb_build_array(trim(p_name)),'red','[]'::jsonb,'blue','[]'::jsonb,'map',null);
  insert into rooms(code,host_token_hash,state) values(upper(p_code),encode(digest(p_host_token,'sha256'),'hex'),s);
  return s || jsonb_build_object('code',upper(p_code));
end $$;

create or replace function public.join_room(p_code text, p_name text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r rooms%rowtype; p jsonb;
begin
  if length(trim(p_name))=0 or length(p_name)>16 then raise exception '닉네임은 1~16자여야 합니다.'; end if;
  select * into r from rooms where code=upper(p_code) for update;
  if not found then raise exception '방을 찾을 수 없습니다.'; end if;
  p=r.state->'players';
  if jsonb_array_length(p)>=10 and not (p ? trim(p_name)) then raise exception '최대 10명까지 참가할 수 있습니다.'; end if;
  if not (p ? trim(p_name)) then p=p || jsonb_build_array(trim(p_name)); end if;
  update rooms set state=jsonb_set(r.state,'{players}',p) where code=r.code returning * into r;
  return r.state || jsonb_build_object('code',r.code);
end $$;

create or replace function public.host_action(p_code text, p_host_token text, p_action text, p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public, extensions as $$
declare r rooms%rowtype; p jsonb; shuffled jsonb; n integer; maps text[] := array['Abyss','Ascent','Bind','Breeze','Fracture','Haven','Icebox','Lotus','Pearl','Split','Sunset'];
begin
  select * into r from rooms where code=upper(p_code) for update;
  if not found then raise exception '방을 찾을 수 없습니다.'; end if;
  if r.host_token_hash <> encode(digest(p_host_token,'sha256'),'hex') then raise exception '방장 권한이 없습니다.'; end if;
  case p_action
    when 'add_player' then
      if length(trim(coalesce(p_payload->>'name','')))=0 or length(p_payload->>'name')>16 then raise exception '닉네임은 1~16자여야 합니다.'; end if;
      p=r.state->'players';
      if jsonb_array_length(p)>=10 then raise exception '최대 10명까지 참가할 수 있습니다.'; end if;
      if not (p ? trim(p_payload->>'name')) then r.state=jsonb_set(r.state,'{players}',p || jsonb_build_array(trim(p_payload->>'name'))); end if;
    when 'draw_teams' then
      select coalesce(jsonb_agg(to_jsonb(x.name)),'[]'::jsonb) into shuffled
      from (select value #>> '{}' as name from jsonb_array_elements(r.state->'players') order by random()) x;
      n=ceil(jsonb_array_length(shuffled)::numeric/2);
      r.state=jsonb_set(r.state,'{red}',coalesce((select jsonb_agg(value) from jsonb_array_elements(shuffled) with ordinality where ordinality<=n),'[]'::jsonb));
      r.state=jsonb_set(r.state,'{blue}',coalesce((select jsonb_agg(value) from jsonb_array_elements(shuffled) with ordinality where ordinality>n),'[]'::jsonb));
    when 'draw_map' then
      r.state=jsonb_set(r.state,'{map}',to_jsonb(maps[1+floor(random()*array_length(maps,1))::int]));
    when 'reset' then
      r.state=jsonb_set(jsonb_set(jsonb_set(r.state,'{red}','[]'::jsonb),'{blue}','[]'::jsonb),'{map}','null'::jsonb);
    else raise exception '지원하지 않는 작업입니다.';
  end case;
  update rooms set state=r.state where code=r.code;
  return r.state || jsonb_build_object('code',r.code);
end $$;

revoke all on function public.create_room(text,text,text) from public;
revoke all on function public.join_room(text,text) from public;
revoke all on function public.host_action(text,text,text,jsonb) from public;
grant execute on function public.create_room(text,text,text) to anon, authenticated;
grant execute on function public.join_room(text,text) to anon, authenticated;
grant execute on function public.host_action(text,text,text,jsonb) to anon, authenticated;
