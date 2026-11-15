alter table public.profiles
  add column if not exists phone_normalized text
  generated always as (
    case
      when length(regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g')) = 12
           and left(regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g'), 2) = '91'
        then right(regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g'), 10)
      when length(regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g')) = 11
           and left(regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g'), 1) = '0'
        then right(regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g'), 10)
      when length(regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g')) = 10
        then regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g')
      else null
    end
  ) stored;

create unique index if not exists profiles_phone_normalized_unique
  on public.profiles(phone_normalized)
  where phone_normalized is not null;

create or replace function private.handle_new_bharat_saathi_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_digits text;
begin
  v_digits := regexp_replace(coalesce(new.raw_user_meta_data ->> 'phone', ''), '[^0-9]', '', 'g');
  if length(v_digits) = 12 and left(v_digits, 2) = '91' then
    v_digits := right(v_digits, 10);
  elsif length(v_digits) = 11 and left(v_digits, 1) = '0' then
    v_digits := right(v_digits, 10);
  end if;

  if length(v_digits) <> 10 then
    raise exception 'A valid 10-digit mobile number is required';
  end if;

  insert into public.profiles(id, full_name, phone, preferred_language)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), v_digits, 'hi');

  return new;
end;
$$;

revoke all on function private.handle_new_bharat_saathi_user() from public, anon, authenticated;

drop trigger if exists on_bharat_saathi_auth_user_created on auth.users;
create trigger on_bharat_saathi_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_bharat_saathi_user();
