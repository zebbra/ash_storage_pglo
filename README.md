[![CI](https://github.com/zebbra/ash_storage_pglo/actions/workflows/ci.yml/badge.svg)](https://github.com/zebbra/ash_storage_pglo/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_storage_pglo.svg)](https://hex.pm/packages/ash_storage_pglo)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_storage_pglo)

# AshStoragePGLO

An [AshStorage](https://hexdocs.pm/ash_storage) service backend that stores attachment bytes as PostgreSQL [large objects](https://www.postgresql.org/docs/current/largeobjects.html) via [`pg_large_objects`](https://hex.pm/packages/pg_large_objects).

Keep your uploads inside Postgres — no S3, no disk, no extra infrastructure. Backups, replication, and transactional deletes all come for free from the database you already run. Works across multiple nodes and any env (dev, test, prod).

## When to use this

PostgreSQL large objects are a good fit when you want:

- **Multiple nodes.** Data can be accessed from multiple nodes without additional services.
- **Multiple environments.** Use the same service for `:dev`, `:prod`, and `:test` environments.
- **One storage target.** Backups, snapshots, and replication cover your uploads automatically.
- **Transactional writes.** Storing data as PG large object and creating the blob resource run in the same transation — if either fails, both roll back.
- **Automatic cleanup.** The `lo_manage` trigger this library installs ties each large object's lifetime to the row that references it. Delete the row, the bytes go too — no orphans.
- **Streaming.** Supports streaming blobs of up to 4TB for reads and writes.

It's *not* a good fit if you need CDN edge caching, cross-region reads, or files larger than what a single Postgres instance can comfortably hold. See the `pg_large_objects` [considerations doc](https://github.com/frerich/pg_large_objects/blob/main/CONSIDERATIONS.md) for the trade-offs.

## Installation

AshStoragePGLO is not yet published to Hex. For now, depend on it from source:

```elixir
def deps do
  [
    {:ash_storage, "~> 0.1"},
    {:ash_storage_pglo, github: "zebbra/ash_storage_pglo"}
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

AshStoragePGLO needs one resource of its own — the mapping table that translates between AshStorage's string `key`s and Postgres's numeric `oid`s (reference to stored PG LO) — plus the usual AshStorage blob and attachment resources.

### 1. Mapping resource

```elixir
defmodule MyApp.StorageLO do
  use Ash.Resource,
    domain: MyApp.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStoragePGLO.Resource]

  postgres do
    table "storage_los"
    repo MyApp.Repo
  end

  lo do
  end
end
```

The `AshStoragePGLO.Resource` extension adds the `:key` and `:oid` attributes, the actions the service dispatches through (`:import`, `:download`, `:destroy`), and an `lo_manage BEFORE UPDATE OR DELETE` trigger as a `custom_statement` — so whenever a mapping row is deleted, its underlying large object is unlinked in the same transaction.

Register `StorageLO` in your domain:

```elixir
defmodule MyApp.Domain do
  use Ash.Domain

  resources do
    resource MyApp.StorageLO
    # ... your other resources
  end
end
```

Run `mix ash.codegen create_storage_lo_table`. The generated migration will create the table with the correct `oid` column type and the `lo_manage` trigger.

### 2. AshStorage blob and attachment resources

These are the usual AshStorage resources — AshStoragePGLO doesn't replace them. A minimal pair:

```elixir
defmodule MyApp.StorageBlob do
  use Ash.Resource,
    domain: MyApp.Domain,
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
defmodule MyApp.StorageAttachment do
  use Ash.Resource,
    domain: MyApp.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStorage.AttachmentResource]

  postgres do
    table "storage_attachments"
    repo MyApp.Repo
  end

  attachment do
    blob_resource MyApp.StorageBlob
    belongs_to_resource :post, MyApp.Post
  end

  attributes do
    uuid_primary_key :id
  end
end
```

### 3. Host resource

Wire `AshStoragePGLO.Service` into any resource that declares attachments:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    domain: MyApp.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStorage]

  storage do
    service {AshStoragePGLO.Service,
             lo_resource: MyApp.StorageLO,
             base_url: "/storage"}

    blob_resource MyApp.StorageBlob
    attachment_resource MyApp.StorageAttachment

    has_one_attached :cover_image
  end

  # ...
end
```

### 4. Serving downloads

Mount `AshStorage.Plug.Proxy` in your router. It calls `AshStoragePGLO.Service.download/2` and streams the result:

```elixir
scope "/", MyAppWeb do
  forward "/storage", AshStorage.Plug.Proxy,
    service: {AshStoragePGLO.Service, lo_resource: MyApp.StorageLO}
end
```

The `base_url` you set on the service must match the path you forward at — the service's `url/2` produces `"#{base_url}/#{key}"`, and the Proxy plug dispatches on the remainder.

**Limitations:** 

- All service opts (incl. `base_url`) is stored on the blob database record. 
- `AshStorage.Plug.Proxy` currently does not support caching.

## Usage

With the setup above, uploads and downloads go through AshStorage's normal API. Nothing about the host resource's code looks different from any other AshStorage backend:

```elixir
{:ok, post} = Ash.create(MyApp.Post, %{title: "Hello, world!"})

{:ok, _} =
  AshStorage.Operations.attach(post, :cover_image, file_bytes,
    filename: "world.jpg",
    content_type: "image/jpeg"
  )

post = Ash.load!(post, :cover_image_url)
post.cover_image_url
#=> "/storage/01h9z8qtabc..."
```

Destroying the photo cascades through AshStorage's dependent-attachment handler, which calls `AshStoragePGLO.Service.delete/2`. That in turn runs a bulk destroy on the mapping row — and the `lo_manage` trigger cleans up the underlying large object in the same transaction. No orphaned bytes.

## Service options

The `{AshStoragePGLO.Service, opts}` tuple takes:

- `:lo_resource` — **required.** The `AshStoragePGLO.Resource` mapping resource (e.g. `MyApp.StorageLO`).
- `:base_url` — **required for `url/2`.** The path where `AshStorage.Plug.Proxy` is mounted.

**Note:** All service options are stored on the blob resource by `ash_storage`. Existing blobs must be updated if options are changed!

## Limitations

- **No direct uploads.** `direct_upload/2` is not implemented — large objects need an open DB connection, so there's no meaningful presigned flow.
- **No streaming.** `AshStorage.Plug.Proxy` reads the full binary into memory before sending the response. Fine for photos, not for multi-GB files. An (upstream?) streaming plug is a plausible future addition.
- **No caching.** `AshStorage.Plug.Proxy` does not support caching, yet. 

## Documentation

- [`pg_large_objects`](https://hex.pm/packages/pg_large_objects) — the low-level library this extension wraps
- [`ash_storage`](https://hexdocs.pm/ash_storage) — the extension this plugs into
- [PostgreSQL large objects](https://www.postgresql.org/docs/current/largeobjects.html) — upstream docs

## Authors

This library is created by 🦓 [zebbra](https://zebbra.ch). Need Elixir expertise made in 🇨🇭 Switzerland? Feel free to [reach out](https://zebbra.ch/contact).
