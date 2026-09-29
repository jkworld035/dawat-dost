-- Run in Supabase: SQL Editor > New query > Run
create table products(
  id bigint generated always as identity primary key,
  name text not null, description text, category text default 'General',
  price numeric not null, active boolean default true);
create table staff(
  user_id uuid primary key references auth.users on delete cascade,
  name text, role text not null check (role in ('admin','delivery')));
create table orders(
  id bigint generated always as identity primary key,
  customer_name text not null, phone text not null, address text not null,
  items jsonb not null, subtotal numeric, fee numeric, total numeric,
  status text not null default 'new'
    check (status in ('new','preparing','ready','picked_up','delivered','cancelled')),
  delivery_boy uuid references auth.users, created_at timestamptz default now());

create function is_role(r text) returns boolean language sql security definer stable
as $$ select exists(select 1 from staff where user_id = auth.uid() and role = r) $$;

alter table products enable row level security;
alter table staff enable row level security;
alter table orders enable row level security;

create policy "anyone reads products" on products for select using (true);
create policy "admin manages products" on products for all using (is_role('admin')) with check (is_role('admin'));
create policy "read own staff row" on staff for select using (user_id = auth.uid());

create policy "customers place orders" on orders for insert to anon, authenticated
  with check (status = 'new' and delivery_boy is null);
create policy "admin manages orders" on orders for all using (is_role('admin')) with check (is_role('admin'));
create policy "delivery sees ready and own" on orders for select
  using (is_role('delivery') and (status = 'ready' or delivery_boy = auth.uid()));
create policy "delivery accepts and completes" on orders for update
  using (is_role('delivery') and (status = 'ready' or delivery_boy = auth.uid()))
  with check (delivery_boy = auth.uid() and status in ('picked_up','delivered'));

insert into products(name,description,category,price) values
('Chicken Curry + Bagara Rice (1 kg)','Special offer, full pack','Specials',650),
('Makka Gudalu','Corn chaat','Snacks',60),
('Fish Fry','Spicy fried fish','Non-veg',180);

-- After creating users in Authentication > Users, make them staff:
-- insert into staff(user_id,name,role) values ('<USER_UUID>','Owner','admin');
-- insert into staff(user_id,name,role) values ('<USER_UUID>','Ravi','delivery');
