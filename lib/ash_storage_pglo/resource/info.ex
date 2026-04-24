defmodule AshStoragePGLO.Resource.Info do
  @moduledoc """
  Introspection helpers for `AshStoragePGLO.Resource` DSL options.
  """

  alias Spark.Dsl.Extension

  @doc """
  Returns the configured `bufsize` for the given resource.
  """
  @spec bufsize(Spark.Dsl.t() | module()) :: pos_integer()
  def bufsize(resource) do
    Extension.get_opt(resource, [:lo], :bufsize)
  end
end
