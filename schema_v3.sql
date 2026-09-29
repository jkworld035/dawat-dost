-- Run AFTER schema_v2.sql. Adds Cash on delivery / UPI payment tracking.
alter table orders add column if not exists payment_method text not null default 'cod' check (payment_method in ('cod','upi'));
alter table orders add column if not exists payment_status text not null default 'pending' check (payment_status in ('pending','paid'));

drop function if exists place_order(text,text,text,jsonb);
create function place_order(p_name text, p_phone text, p_address text, p_items jsonb, p_method text default 'cod')
returns bigint language plpgsql security definer as $$
declare sub numeric := 0; fee numeric := 30; its jsonb := '[]'; r record; p products; oid bigint;
begin
  if p_phone !~ '^[6-9][0-9]{9}$' or coalesce(trim(p_name),'')='' or coalesce(trim(p_address),'')='' or p_method not in ('cod','upi') then
    raise exception 'invalid details'; end if;
  for r in select (e->>'id')::bigint pid, (e->>'q')::int q from jsonb_array_elements(p_items) e loop
    select * into p from products where id = r.pid and active;
    if found and r.q > 0 and r.q <= 50 then
      sub := sub + p.price * r.q;
      its := its || jsonb_build_object('n', p.name, 'q', r.q, 'p', p.price);
    end if;
  end loop;
  if sub = 0 then raise exception 'empty order'; end if;
  insert into orders(customer_name,phone,address,items,subtotal,fee,total,payment_method)
  values (trim(p_name),p_phone,trim(p_address),its,sub,fee,sub+fee,p_method) returning id into oid;
  return oid;
end $$;

drop function if exists track_order(bigint,text);
create function track_order(p_id bigint, p_phone text)
returns table(status text, total numeric, items jsonb, created_at timestamptz, payment_method text, payment_status text)
language sql security definer as $$
  select o.status, o.total, o.items, o.created_at, o.payment_method, o.payment_status from orders o where o.id = p_id and o.phone = p_phone $$;

grant execute on function place_order(text,text,text,jsonb,text) to anon, authenticated;
grant execute on function track_order(bigint,text) to anon, authenticated;
