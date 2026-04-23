defmodule AshStoragePGLO.Resource do
  @moduledoc """
  Spark extension for declaring a PG Large Object mapping resource.

  Add to a resource that maps `AshStorage` blob keys to Postgres
  large-object oids:

      defmodule MyApp.Gallery.StorageLO do
        use Ash.Resource,
          domain: MyApp.Gallery,
          data_layer: AshPostgres.DataLayer,
          extensions: [AshStoragePGLO.Resource]

        postgres do
          table "storage_los"
          repo MyApp.Repo
        end

        lo do
          bufsize 4_194_304  # optional — defaults to 1MB
        end
      end

  The extension adds:
  - a `:key` string primary-key attribute
  - an `:oid` attribute typed as `AshStoragePGLO.Type.OID` (maps to
    Postgres `oid`)
  - `:create`, `:read`, and `:destroy` actions
  - a `lo_manage` `BEFORE UPDATE OR DELETE` trigger as a
    `custom_statement` on the resource's postgres block
  """

  @lo %Spark.Dsl.Section{
    name: :lo,
    describe: "Configuration for the PG Large Object mapping resource.",
    schema: [
      bufsize: [
        type: :pos_integer,
        doc:
          "Number of bytes transferred per chunk when reading a large object. Defaults to 1MB.",
        default: 1_048_576
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@lo],
    transformers: [AshStoragePGLO.Resource.Transformers.SetupLO]
end
