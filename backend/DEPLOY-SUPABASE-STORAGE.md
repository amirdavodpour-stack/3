# Supabase Storage S3 Integration

This backend uses its own authentication and authorization layer. Supabase is used as an S3-compatible object store behind the backend storage abstraction.

## Staging configuration

Use the existing V2hope private bucket for backend-controlled uploads:

```dotenv
STORAGE_BACKEND=s3
S3_BUCKET=v2hope-private
S3_REGION=eu-west-1
S3_ENDPOINT=https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/s3
S3_FORCE_PATH_STYLE=true
S3_PREFIX=uploads
S3_SERVER_SIDE_ENCRYPTION=
```

Generate the S3 Access Key ID and Secret Access Key from the Supabase Storage S3 configuration page and inject them only into the backend/staging secret store:

```dotenv
AWS_ACCESS_KEY_ID=<server-side Supabase S3 access key>
AWS_SECRET_ACCESS_KEY=<server-side Supabase S3 secret>
SUPABASE_SERVICE_ROLE_KEY=<server-side Supabase service-role key>
```

Never put any of these credentials in Flutter, source control, or public build configuration. The service-role key is used only by the backend to create a Supabase native signed upload URL; it is never returned to the client.

## Security boundary

The generated Supabase S3 access keys are server-side credentials and bypass Storage RLS. Therefore the V2hope backend remains the authorization boundary: every storage request is authenticated by the V2hope bearer token, upload completion is bound to a per-user expiring upload intent, and the stored object is checked for size, content type, and file signature before the database record is committed.

The Storage bucket policies remain restrictive for non-server access. `v2hope-private` is private, and `v2hope-temp` is also private. `v2hope-public` is reserved for genuinely public assets.

## Supabase-specific compatibility

Supabase Storage's S3 `PutObject` API does not support the `x-amz-server-side-encryption` request header or a documented conditional `If-None-Match` on `PutObject`. For Supabase presigned uploads, the backend therefore uses the native Storage signed-upload endpoint (`/object/upload/sign`) with `upsert=false`, and the client must send `x-upsert: false`. Supabase rejects an existing object instead of overwriting it. The internal Upload Intent remains five minutes; Supabase's signed URL token itself is valid for two hours, but an expired intent cannot be completed or associated with a HOPE upload record. Generic S3 providers continue using a signed `If-None-Match: *` conditional PUT. The backend omits `ServerSideEncryption` for Supabase S3 operations.

The direct storage hostname is used for the endpoint because Supabase recommends it for S3 traffic:

```text
https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/s3
```

## Current limitations

The repository currently has no Supabase S3 credentials in source control, and the GitHub connector does not expose those secret values. A live Supabase S3 upload remains `UNVERIFIED` until the staging environment supplies the four runtime values below:

- `STORAGE_BACKEND=s3`
- `S3_BUCKET=v2hope-private`
- `S3_ENDPOINT=https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/s3`
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (server-side only; used to mint native signed uploads with `upsert=false`)

Once those secrets are configured, the existing `s3-integration.test.mjs` gate can exercise upload, HEAD, presign, signature validation, and deletion against the real Storage endpoint.
