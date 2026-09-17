-- Storage contract hardening for V2hope application buckets.
-- Keep application uploads constrained to known file classes and bounded sizes.

update storage.buckets
set
  allowed_mime_types = case id
    when 'v2hope-private' then array['application/pdf','image/png','image/jpeg','image/webp','text/plain']::text[]
    when 'v2hope-public' then array['image/png','image/jpeg','image/webp']::text[]
    when 'v2hope-temp' then array['application/pdf','image/png','image/jpeg','image/webp','text/plain']::text[]
    else allowed_mime_types
  end,
  file_size_limit = case id
    when 'v2hope-private' then 10485760
    when 'v2hope-public' then 5242880
    when 'v2hope-temp' then 10485760
    else file_size_limit
  end
where id in ('v2hope-private','v2hope-public','v2hope-temp');
