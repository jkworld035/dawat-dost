-- Run AFTER schema.sql. Adds veg flag, images, secure ordering and order tracking.
alter table products add column if not exists is_veg boolean default false;
alter table products add column if not exists image_url text;

-- customers no longer insert directly; prices are computed on the server
drop policy if exists "customers place orders" on orders;

create or replace function place_order(p_name text, p_phone text, p_address text, p_items jsonb)
returns bigint language plpgsql security definer as $$
declare sub numeric := 0; fee numeric := 30; its jsonb := '[]'; r record; p products; oid bigint;
begin
  if p_phone !~ '^[6-9][0-9]{9}$' or coalesce(trim(p_name),'')='' or coalesce(trim(p_address),'')='' then
    raise exception 'invalid details'; end if;
  for r in select (e->>'id')::bigint pid, (e->>'q')::int q from jsonb_array_elements(p_items) e loop
    select * into p from products where id = r.pid and active;
    if found and r.q > 0 and r.q <= 50 then
      sub := sub + p.price * r.q;
      its := its || jsonb_build_object('n', p.name, 'q', r.q, 'p', p.price);
    end if;
  end loop;
  if sub = 0 then raise exception 'empty order'; end if;
  insert into orders(customer_name,phone,address,items,subtotal,fee,total)
  values (trim(p_name),p_phone,trim(p_address),its,sub,fee,sub+fee) returning id into oid;
  return oid;
end $$;

create or replace function track_order(p_id bigint, p_phone text)
returns table(status text, total numeric, items jsonb, created_at timestamptz)
language sql security definer as $$
  select o.status, o.total, o.items, o.created_at from orders o where o.id = p_id and o.phone = p_phone $$;

grant execute on function place_order(text,text,text,jsonb) to anon, authenticated;
grant execute on function track_order(bigint,text) to anon, authenticated;
