-- Web FCM uses the same per-user device-token table as native devices.
-- Preserve existing RLS policies and native platform support.
alter table public.push_devices drop constraint if exists push_devices_platform_check;
alter table public.push_devices
  add constraint push_devices_platform_check
  check (platform in ('android', 'ios', 'web'));
