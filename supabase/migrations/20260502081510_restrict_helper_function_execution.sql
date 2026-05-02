begin;

revoke execute on all functions in schema private from public, anon;
revoke execute on all functions in schema public from public, anon;

grant execute on all functions in schema private to authenticated, service_role;
grant execute on function public.convert_inquiry_to_player(uuid, uuid, integer) to authenticated, service_role;

commit;
