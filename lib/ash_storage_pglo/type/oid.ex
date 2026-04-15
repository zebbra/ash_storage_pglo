defmodule AshStoragePGLO.Type.OID do
  @moduledoc """
  Ash type backed by PostgreSQL's native `oid` column type.

  Behaves like an integer at the Elixir level but tells `ash_postgres`
  to emit an `oid` column in generated migrations. Required so that
  `lo_manage` can operate on the column.
  """

  use Ash.Type
  use AshPostgres.Type

  @impl Ash.Type
  def storage_type(_constraints), do: :oid

  @impl Ash.Type
  def cast_input(nil, _constraints), do: {:ok, nil}
  def cast_input(value, _constraints) when is_integer(value) and value >= 0, do: {:ok, value}
  def cast_input(_value, _constraints), do: :error

  @impl Ash.Type
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(value, _constraints) when is_integer(value), do: {:ok, value}
  def cast_stored(_value, _constraints), do: :error

  @impl Ash.Type
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(value, _constraints) when is_integer(value), do: {:ok, value}
  def dump_to_native(_value, _constraints), do: :error
end
