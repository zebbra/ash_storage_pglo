defmodule AshStoragePGLO.Resource.Actions.Download do
  @moduledoc """
  Implementation for the `:download` generic action on
  `AshStoragePGLO.Resource` resources.

  Looks up the `{key, oid}` mapping row and streams the underlying PG
  large object back as a binary. The action is declared with
  `transaction?: true`, so Ash wraps this callback in a DB transaction
  — which `PgLargeObjects.export/3` requires.

  The chunk size used when reading from the large object is taken from the
  resource's `lo do bufsize <value> end` DSL option (default 1MB). See
  `AshStoragePGLO.Resource.Info.bufsize/1`.

  Returns `{:ok, binary}` on success and `{:ok, nil}` when no row with
  the given key exists. The action is declared with `allow_nil? true`,
  so the service layer translates `nil` into its own `:not_found` error.
  """

  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    resource = input.resource
    repo = AshPostgres.DataLayer.Info.repo(resource)
    key = input.arguments.key
    bufsize = AshStoragePGLO.Resource.Info.bufsize(resource)

    with {:ok, %{oid: oid}} <- Ash.get(resource, key, not_found_error?: false),
         do: PgLargeObjects.export(repo, oid, bufsize: bufsize)
  end
end
