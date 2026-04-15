# AshStoragePGLO

An [AshStorage](https://hexdocs.pm/ash_storage) service backend that stores attachment bytes as PostgreSQL [large objects](https://www.postgresql.org/docs/current/largeobjects.html).

Keep your uploads inside Postgres — no S3, no disk, no extra infrastructure. Backups, replication, and transactional deletes all come for free from the database you already run.

## When to use this

PostgreSQL large objects are a good fit when you want:

- **One storage target.** Backups, snapshots, and replication cover your uploads automatically.
- **Transactional writes.** `PgLargeObjects.import/3` runs inside the same transaction as the `Ash.create` that references it — if either fails, both roll back.
- **Automatic cleanup.** The `lo_manage` trigger this library installs ties each large object's lifetime to the row that references it. Delete the row, the bytes go too — no orphans.
- **Streaming.** [`pg_large_objects`](https://hex.pm/packages/pg_large_objects) streams both reads and writes up to 4 TB per object.

It's *not* a good fit if you need CDN edge caching, cross-region reads, or files larger than what a single Postgres instance can comfortably hold. See the [`pg_large_objects` considerations doc](https://github.com/frerich/pg_large_objects/blob/main/CONSIDERATIONS.md) for the trade-offs.

## Installation

AshStoragePGLO is not yet published to Hex. For now, depend on it from source:

```elixir
def deps do
  [
    {:ash_storage, "~> 0.1"},
    {:ash_storage_pglo, github: "hwuethrich/ash_storage_pglo"}
  ]
end
```

You also need the `lo` extension enabled on your database:

```elixir
# lib/my_app/repo.ex
def installed_extensions do
  ["ash-functions", "lo"]
end
```

Run `mix ash.codegen install_lo_extension` to generate the migration that enables it.

## Setup

AshStoragePGLO needs one resource of its own — the mapping table that translates between AshStorage's string `key`s and Postgres's numeric `oid`s — plus the usual AshStorage blob and attachment resources.

### 1. Mapping resource

```elixir
defmodule MyApp.Gallery.StorageLO do
  use Ash.Resource,
    domain: MyApp.Gallery,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStoragePGLO.Resource]

  postgres do
    table "storage_lo"
    repo MyApp.Repo
  end

  lo do
  end
end
```

The `AshStoragePGLO.Resource` extension adds:

- a `:key` string primary-key attribute,
- an `:oid` attribute typed as `AshStoragePGLO.Type.OID` (maps to the native Postgres `oid` column),
- an `:import` create action that streams bytes into a new large object and writes the mapping row in one transaction,
- a `:download` generic action that streams the bytes back out,
- a `:destroy` action, and
- an `lo_manage BEFORE UPDATE OR DELETE` trigger installed as a `custom_statement` — so whenever a mapping row is deleted, its large object is unlinked in the same transaction.

Register `StorageLO` in your domain:

```elixir
defmodule MyApp.Gallery do
  use Ash.Domain

  resources do
    resource MyApp.Gallery.StorageLO
    # ... your other resources
  end
end
```

Run `mix ash.codegen create_storage_lo_table`. The generated migration will create the table with the correct `oid` column type and the `lo_manage` trigger.

### 2. AshStorage blob and attachment resources

These are the usual AshStorage resources — AshStoragePGLO doesn't replace them. A minimal pair:

```elixir
defmodule MyApp.Gallery.StorageBlob do
  use Ash.Resource,
    domain: MyApp.Gallery,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStorage.BlobResource]

  postgres do
    table "storage_blobs"
    repo MyApp.Repo
  end

  blob do
  end

  attributes do
    uuid_primary_key :id
  end
end
```

```elixir
defmodule MyApp.Gallery.StorageAttachment do
  use Ash.Resource,
    domain: MyApp.Gallery,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStorage.AttachmentResource]

  postgres do
    table "storage_attachments"
    repo MyApp.Repo
  end

  attachment do
    blob_resource MyApp.Gallery.StorageBlob
    belongs_to_resource :photo, MyApp.Gallery.Photo
  end

  attributes do
    uuid_primary_key :id
  end
end
```

### 3. Host resource

Wire `AshStoragePGLO.Service` into any resource that declares attachments:

```elixir
defmodule MyApp.Gallery.Photo do
  use Ash.Resource,
    domain: MyApp.Gallery,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStorage]

  storage do
    service {AshStoragePGLO.Service,
             resource: MyApp.Gallery.StorageLO,
             base_url: "/storage"}

    blob_resource MyApp.Gallery.StorageBlob
    attachment_resource MyApp.Gallery.StorageAttachment

    has_one_attached :image
  end

  # ...
end
```

### 4. Serving downloads

Mount `AshStorage.Plug.Proxy` in your router. It calls `AshStoragePGLO.Service.download/2` and streams the result:

```elixir
scope "/", MyAppWeb do
  forward "/storage", AshStorage.Plug.Proxy,
    service: {AshStoragePGLO.Service, resource: MyApp.Gallery.StorageLO}
end
```

The `base_url` you set on the service must match the path you forward at — the service's `url/2` produces `"#{base_url}/#{key}"`, and the Proxy plug dispatches on the remainder.

## Usage

With the setup above, uploads and downloads go through AshStorage's normal API. Nothing about the host resource's code looks different from any other AshStorage backend:

```elixir
{:ok, photo} =
  Ash.create(MyApp.Gallery.Photo, %{title: "Sunset"})

{:ok, _} =
  AshStorage.Operations.attach(photo, :image, file_bytes,
    filename: "sunset.jpg",
    content_type: "image/jpeg"
  )

photo = Ash.load!(photo, :image_url)
photo.image_url
#=> "/storage/01h9z8qtabc..."
```

Destroying the photo cascades through AshStorage's dependent-attachment handler, which calls `AshStoragePGLO.Service.delete/2`. That in turn runs a bulk destroy on the mapping row — and the `lo_manage` trigger cleans up the underlying large object in the same transaction. No orphaned bytes.

## Service options

The `{AshStoragePGLO.Service, opts}` tuple takes:

- `:resource` — **required.** The `AshStoragePGLO.Resource` mapping resource (e.g. `MyApp.Gallery.StorageLO`).
- `:base_url` — **required for `url/2`.** The path where `AshStorage.Plug.Proxy` is mounted.

The repo used for transactions and large-object I/O is derived automatically from the mapping resource's `postgres do repo end` block — there's nothing to configure.

## How it works

The library hides three things behind a thin service façade.

**On upload**, `AshStoragePGLO.Service.upload/3` calls `Ash.create(lo_resource, %{key: key, data: data}, action: :import)`. The `:import` action's change module (`AshStoragePGLO.Resource.Changes.Import`) runs `PgLargeObjects.import/3` in a `before_action` hook — so the `lo_create` and the mapping row insert both commit or both roll back. The `:data` argument is a public `:term`, so raw binaries, iolists, and `File.Stream`s all work.

**On download**, `AshStoragePGLO.Service.download/2` calls `Ash.run_action(lo_resource, :download, %{key: key})`. The `:download` generic action is declared `transaction?: true`, so the implementation module (`AshStoragePGLO.Resource.Actions.Download`) runs inside a DB transaction without having to wrap `Repo.transaction/1` manually. It looks up the oid via `Ash.get/3` (with `not_found_error?: false`) and calls `PgLargeObjects.export/3`.

**On delete**, `AshStoragePGLO.Service.delete/2` runs `Ash.bulk_destroy/4` against the mapping resource, filtered by key. The `lo_manage` trigger fires per-row and unlinks the underlying large object in the same transaction. Deleting a missing key is a no-op (bulk destroy on an empty result set returns `%Ash.BulkResult{status: :success}`).

The mapping resource is a full Ash resource, so authorization policies, notifications, and the rest of the Ash toolkit apply to every operation — including the ones the service dispatches internally.

## Limitations

- **Single data layer.** Only `AshPostgres.DataLayer` is supported. The transformer bails out of trigger installation for anything else, and the service assumes the resource's repo is an `AshPostgres.Repo`.
- **No signed URLs yet.** `url/2` produces a plain path. If you need expiring links, mount `AshStorage.Plug.Proxy` with a `:secret` (the plug supports HMAC verification) and thread signed URLs through your own calculation.
- **No direct uploads.** `direct_upload/2` is not implemented — large objects need an open DB connection, so there's no meaningful presigned flow.
- **Whole-binary downloads.** `AshStorage.Plug.Proxy` reads the full binary into memory before sending the response. Fine for photos, not for multi-GB files. A streaming plug is a plausible future addition.
- **Orphan blobs on partial failures.** If the `AshStorage.BlobResource` create fails after the large object has already been written, the mapping row + bytes are orphaned. This mirrors the S3 service's behaviour and should be covered by AshStorage's planned unified cleanup.

## Roadmap

- **Signed URLs.** Mirror `AshStorage.Service.Disk`'s `:secret` + HMAC token pattern so `url/2` can produce expiring links.
- **Streaming `Plug`.** A variant of `AshStorage.Plug.Proxy` that streams large objects chunk-by-chunk instead of buffering the whole binary.
- **Direct chunked uploads** — possibly via a dedicated plug that maps `PUT` chunks onto `PgLargeObjects.LargeObject.write/2`.
- **Orphan cleanup.** A periodic action that finds mapping rows with no matching `StorageBlob` row and destroys them.

## Documentation

- [`pg_large_objects`](https://hex.pm/packages/pg_large_objects) — the low-level library this extension wraps
- [`ash_storage`](https://hexdocs.pm/ash_storage) — the extension this plugs into
- [PostgreSQL large objects](https://www.postgresql.org/docs/current/largeobjects.html) — upstream docs
