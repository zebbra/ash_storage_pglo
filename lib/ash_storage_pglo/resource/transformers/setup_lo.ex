defmodule AshStoragePGLO.Resource.Transformers.SetupLO do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Ash.Resource.Builder
  alias Spark.Dsl.Extension
  alias Spark.Dsl.Transformer

  @before_transformers [
    Ash.Resource.Transformers.DefaultAccept,
    Ash.Resource.Transformers.CachePrimaryKey,
    Ash.Resource.Transformers.SetRelationshipSource
  ]

  @impl true
  def before?(transformer) when transformer in @before_transformers, do: true
  def before?(_), do: false

  @impl true
  def transform(dsl_state) do
    with {:ok, dsl_state} <- add_attributes(dsl_state),
         {:ok, dsl_state} <- add_actions(dsl_state) do
      {:ok, maybe_add_trigger(dsl_state)}
    end
  end

  defp add_attributes(dsl_state) do
    with {:ok, dsl_state} <-
           Builder.add_new_attribute(dsl_state, :key, :string,
             primary_key?: true,
             allow_nil?: false,
             public?: true,
             writable?: true
           ),
         {:ok, dsl_state} <-
           Builder.add_new_attribute(dsl_state, :oid, AshStoragePGLO.Type.OID,
             allow_nil?: false,
             public?: true,
             writable?: true
           ) do
      {:ok, dsl_state}
    end
  end

  defp add_actions(dsl_state) do
    {:ok, data_arg} =
      Builder.build_action_argument(:data, :term,
        allow_nil?: false,
        public?: true
      )

    {:ok, import_change} =
      Builder.build_action_change(AshStoragePGLO.Resource.Changes.Import)

    {:ok, key_arg} =
      Builder.build_action_argument(:key, :string,
        allow_nil?: false,
        public?: true
      )

    with {:ok, dsl_state} <-
           Builder.add_action(dsl_state, :create, :import,
             primary?: true,
             accept: [:key],
             arguments: [data_arg],
             changes: [import_change]
           ),
         {:ok, dsl_state} <-
           Builder.add_action(dsl_state, :read, :read, primary?: true),
         {:ok, dsl_state} <-
           Builder.add_action(dsl_state, :destroy, :destroy, primary?: true),
         {:ok, dsl_state} <-
           Builder.add_action(dsl_state, :action, :download,
             returns: :binary,
             allow_nil?: true,
             transaction?: true,
             run: AshStoragePGLO.Resource.Actions.Download,
             arguments: [key_arg]
           ) do
      {:ok, dsl_state}
    end
  end

  defp maybe_add_trigger(dsl_state) do
    if Extension.get_persisted(dsl_state, :data_layer) == AshPostgres.DataLayer do
      table = AshPostgres.DataLayer.Info.table(dsl_state)

      cond do
        is_nil(table) -> dsl_state
        trigger_exists?(dsl_state, trigger_name(table)) -> dsl_state
        true -> add_trigger(dsl_state, table)
      end
    else
      dsl_state
    end
  end

  defp trigger_name(table), do: String.to_atom("lo_manage_#{table}")

  defp trigger_exists?(dsl_state, name) do
    dsl_state
    |> Extension.get_entities([:postgres, :custom_statements])
    |> Enum.any?(&(&1.name == name))
  end

  defp add_trigger(dsl_state, table) do
    name = trigger_name(table)

    up =
      """
      CREATE TRIGGER #{name} BEFORE UPDATE OR DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION lo_manage(oid);
      """

    down = "DROP TRIGGER IF EXISTS #{name} ON #{table};"

    statement =
      Transformer.build_entity!(
        AshPostgres.DataLayer,
        [:postgres, :custom_statements],
        :statement,
        name: name,
        up: up,
        down: down
      )

    Transformer.add_entity(dsl_state, [:postgres, :custom_statements], statement)
  end
end
