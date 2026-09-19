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
```

Never put either credential in Flutter, source control, or public build configuration.

## Security boundary

The generated Supabase S3 access keys are server-side credentials and bypass Storage RLS. Therefore the V2hope backend remains the authorization boundary: every storage request is authenticated by the V2hope bearer token, upload completion is bound to a per-user expiring upload intent, and the stored object is checked for size, content type, and file signature before the database record is committed.

The Storage bucket policies remain restrictive for non-server access. `v2hope-private` is private, and `v2hope-temp` is also private. `v2hope-public` is reserved for genuinely public assets.

## Supabase-specific compatibility

Supabase Storage's S3 `PutObject` API does not support the `x-amz-server-side-encryption` request header. The backend therefore detects the Supabase Storage S3 endpoint and omits `ServerSideEncryption` from normal and presigned PUT requests.

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

Once those secrets are configured, the existing `s3-integration.test.mjs` gate can exercise upload, HEAD, presign, signature validation, and deletion against the real Storage endpoint.
