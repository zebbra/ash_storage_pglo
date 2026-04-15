defmodule AshStoragePGLO.ResourceTest do
  use ExUnit.Case, async: true

  alias AshStoragePGLO.Test.StorageLO

  test "adds :key attribute as the primary key" do
    [pk] = Ash.Resource.Info.primary_key(StorageLO)
    assert pk == :key

    key_attr = Ash.Resource.Info.attribute(StorageLO, :key)
    assert key_attr.type == Ash.Type.String
    assert key_attr.allow_nil? == false
    assert key_attr.public? == true
  end

  test "adds :oid attribute typed as AshStoragePGLO.Type.OID" do
    oid_attr = Ash.Resource.Info.attribute(StorageLO, :oid)
    assert oid_attr.type == AshStoragePGLO.Type.OID
    assert oid_attr.allow_nil? == false
  end

  test "adds :import, :read, :destroy actions" do
    actions = StorageLO |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
    assert :import in actions
    assert :read in actions
    assert :destroy in actions
    refute :create in actions
  end

  test "import action accepts :key and takes :data as argument" do
    action = Ash.Resource.Info.action(StorageLO, :import)
    assert action.type == :create
    assert action.primary? == true
    assert :key in action.accept
    refute :oid in action.accept

    argument_names = Enum.map(action.arguments, & &1.name)
    assert :data in argument_names

    data_arg = Enum.find(action.arguments, &(&1.name == :data))
    assert data_arg.allow_nil? == false
    assert data_arg.public? == true
  end

  describe "lo_manage trigger" do
    alias AshStoragePGLO.Test.StorageLO

    test "registers a custom_statement named lo_manage_<table>" do
      statements = AshPostgres.DataLayer.Info.custom_statements(StorageLO)
      names = Enum.map(statements, & &1.name)
      assert :lo_manage_storage_los in names
    end

    test "the statement up-SQL calls lo_manage with the oid column" do
      statements = AshPostgres.DataLayer.Info.custom_statements(StorageLO)
      stmt = Enum.find(statements, &(&1.name == :lo_manage_storage_los))

      assert stmt.up == """
             CREATE TRIGGER lo_manage_storage_los BEFORE UPDATE OR DELETE ON storage_los
               FOR EACH ROW EXECUTE FUNCTION lo_manage(oid);
             """

      assert stmt.down ==
               "DROP TRIGGER IF EXISTS lo_manage_storage_los ON storage_los;"
    end
  end
end
