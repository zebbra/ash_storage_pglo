defmodule AshStoragePGLO.Service do
  @moduledoc """
  `AshStorage.Service` backend that stores attachment bytes as PostgreSQL
  large objects via `pg_large_objects`.

  Requires an explicit mapping resource (see `AshStoragePGLO.Resource`) to
  translate between `AshStorage` string keys and large-object oids.

  ## Configuration

      storage do
        service {AshStoragePGLO.Service,
                 lo_resource: MyApp.Gallery.StorageLO,
                 base_url: "/storage"}
      end

  Mount `AshStorage.Plug.Proxy` to serve downloads:

      forward "/storage", AshStorage.Plug.Proxy,
        service: {AshStoragePGLO.Service,
                  lo_resource: MyApp.Gallery.StorageLO}

  ## Options

  - `:lo_resource` — required. The `AshStoragePGLO.Resource` mapping resource.
  - `:base_url` — required for `url/2`. The path where `AshStorage.Plug.Proxy`
    is mounted.
  """

  @behaviour AshStorage.Service

  alias AshStorage.Service.Context

  require Ash.Query

  @impl true
  def service_opts_fields do
    [
      lo_resource: [type: :atom, allow_nil?: false],
      base_url: [type: :string]
    ]
  end

  @impl true
  def upload(key, data, %Context{} = ctx) when is_binary(key) do
    lo_resource = resource!(ctx)

    with {:ok, _row} <- Ash.create(lo_resource, %{key: key, data: data}, action: :import) do
      :ok
    end
  end

  @impl true
  def download(key, %Context{} = ctx) when is_binary(key) do
    lo_resource = resource!(ctx)

    lo_resource
    |> Ash.ActionInput.for_action(:download, %{key: key})
    |> Ash.run_action()
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, binary} -> {:ok, binary}
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def delete(key, %Context{} = ctx) when is_binary(key) do
    lo_resource = resource!(ctx)

    result =
      lo_resource
      |> Ash.Query.filter(key == ^key)
      |> Ash.bulk_destroy(:destroy, %{})

    case result do
      %Ash.BulkResult{status: :success} -> :ok
      %Ash.BulkResult{status: :error, errors: errors} -> {:error, errors}
    end
  end

  @impl true
  def exists?(key, %Context{} = ctx) when is_binary(key) do
    lo_resource = resource!(ctx)

    exists? =
      lo_resource
      |> Ash.Query.filter(key == ^key)
      |> Ash.exists?()

    {:ok, exists?}
  end

  @impl true
  def url(key, %Context{} = ctx) do
    base_url = Keyword.fetch!(ctx.service_opts, :base_url)
    "#{base_url}/#{key}"
  end

  # --- helpers -------------------------------------------------------------

  # `ash_storage` persists `service_opts` on the blob row and reconstitutes
  # them later for async purge / dependent-attachment cleanup. The stored
  # form goes through `Ash.Type.Keyword.cast_stored/2`, which doesn't cast
  # individual field values — so our `:lo_resource` atom comes back as a
  # string on the delete path. Coerce it here so the service works whether
  # it's being called with fresh opts or reconstituted ones.
  defp resource!(%Context{service_opts: opts}) do
    case Keyword.fetch!(opts, :lo_resource) do
      module when is_atom(module) -> module
      binary when is_binary(binary) -> String.to_existing_atom(binary)
    end
  end
end
