\set ON_ERROR_STOP 1
select pg_sleep(1);
begin;
insert into weather_hourly values (2, now(), 1,1,null,0,0,0,0,null) on conflict (cell_id,time) do update set temperature = excluded.temperature;
update weather_cells set fetched_at = now(), next_refresh_at = now() + interval '1 hour', attempts = 0, claimed_until = null, updated_at = now() where id = 2;
select pg_sleep(2);
insert into weather_hourly values (1, now(), 1,1,null,0,0,0,0,null) on conflict (cell_id,time) do update set temperature = excluded.temperature;
select 'hourly insert on cell 1 passed while planner holds its row lock (FK KEY SHARE does not block)';
update weather_cells set fetched_at = now(), next_refresh_at = now() + interval '1 hour', attempts = 0, claimed_until = null, updated_at = now() where id = 1;
commit; select 'store committed';
