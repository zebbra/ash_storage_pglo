defmodule AshStoragePGLO.Type.OIDTest do
  use ExUnit.Case, async: true

  alias AshStoragePGLO.Type.OID

  test "storage_type is :oid" do
    assert OID.storage_type([]) == :oid
  end

  test "round-trips an integer through cast_input/cast_stored/dump_to_native" do
    assert {:ok, 42} = OID.cast_input(42, [])
    assert {:ok, 42} = OID.cast_stored(42, [])
    assert {:ok, 42} = OID.dump_to_native(42, [])
  end
end
