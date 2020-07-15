defmodule Ash.Api.Transformers.ValidateRelationshipAttributes do
  @moduledoc """
  Validates the all relationships point to valid fields
  """
  use Ash.Dsl.Transformer

  alias Ash.Dsl.Transformer

  @extension Ash.Api.Dsl

  def transform(_api, dsl) do
    dsl
    |> Transformer.get_entities([:resources], @extension)
    |> Enum.map(& &1.resource)
    |> Enum.each(fn resource ->
      attribute_names =
        resource
        |> Ash.Resource.attributes()
        |> Enum.map(& &1.name)

      resource
      |> Ash.Resource.relationships()
      |> Enum.each(&validate_relationship(&1, attribute_names))
    end)

    {:ok, dsl}
  end

  defp validate_relationship(relationship, attribute_names) do
    unless relationship.source_field in attribute_names do
      raise Ash.Error.Dsl.DslError,
        path: [:relationships, relationship.name],
        message:
          "Relationship `#{relationship.name}` expects source field `#{relationship.source_field}` to be defined"
    end

    destination_attributes =
      relationship.destination
      |> Ash.Resource.attributes()
      |> Enum.map(& &1.name)

    unless relationship.destination_field in destination_attributes do
      raise Ash.Error.Dsl.DslError,
        path: [:relationships, relationship.name],
        message:
          "Relationship `#{relationship.name}` expects destination field `#{
            relationship.destination_field
          }` to be defined on #{inspect(relationship.destination)}"
    end
  end

  def after?(Ash.Api.Transformers.EnsureResourcesCompiled), do: true
  def after?(_), do: false
end
