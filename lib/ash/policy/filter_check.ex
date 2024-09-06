defmodule Ash.Policy.FilterCheck do
  @moduledoc """
  A type of check that is represented by a filter statement

  That filter statement can be templated, currently only supporting `{:_actor, field}`
  which will replace that portion of the filter with the appropriate field value from the actor and
  `{:_actor, :_primary_key}` which will replace the value with a keyword list of the primary key
  fields of an actor to their values, like `[id: 1]`. If the actor is not present `{:_actor, field}`
  becomes `nil`, and `{:_actor, :_primary_key}` becomes `false`.

  You can customize what the "negative" filter looks like by defining `c:reject/3`. This is important for
  filters over related data. For example, given an `owner` relationship and a data layer like `ash_postgres`
  where `column != NULL` does *not* evaluate to true (see postgres docs on NULL for more):

      # The opposite of
      `owner.id == 1`
      # in most cases is not
      `not(owner.id == 1)`
      # because in postgres that would be `NOT (owner.id = NULL)` in cases where there was no owner
      # A better opposite would be
      `owner.id != 1 or is_nil(owner.id)`
      # alternatively
      `not(owner.id == 1) or is_nil(owner.id)`

  By being able to customize the `reject` filter, you can use related filters in your policies. Without it,
  they will likely have undesired effects.
  """
  @type options :: Keyword.t()
  @type context :: %{
          required(:action) => Ash.Resource.Actions.action(),
          required(:resource) => Ash.Resource.t(),
          required(:domain) => Ash.Domain.t(),
          optional(:query) => Ash.Query.t(),
          optional(:changeset) => Ash.Changeset.t(),
          optional(:action_input) => Ash.ActionInput.t(),
          optional(any) => any
        }

  @callback filter(actor :: term, context(), options()) :: Keyword.t() | Ash.Expr.t()
  @callback reject(actor :: term, context(), options()) :: Keyword.t() | Ash.Expr.t()
  @optional_callbacks [reject: 3]

  defmacro __using__(_) do
    quote do
      @behaviour Ash.Policy.FilterCheck
      @behaviour Ash.Policy.Check

      import Ash.Expr
      require Ash.Query

      def type, do: :filter

      def requires_original_data?(_, _), do: false

      def strict_check_context(opts) do
        []
      end

      def strict_check(nil, authorizer, opts) do
        opts = Keyword.put_new(opts, :resource, authorizer.resource)

        if Ash.Expr.template_references_actor?(filter(nil, authorizer, opts)) do
          {:ok, false}
        else
          try_strict_check(nil, authorizer, opts)
        end
      end

      def strict_check(actor, authorizer, opts) do
        try_strict_check(actor, authorizer, opts)
      end

      defp try_strict_check(actor, authorizer, opts) do
        opts = Keyword.put_new(opts, :resource, authorizer.resource)

        context =
          case authorizer.subject do
            %{context: context} -> context
            _ -> %{}
          end

        actor
        |> filter(authorizer, opts)
        |> Ash.Expr.fill_template(actor, Ash.Policy.FilterCheck.args(authorizer), context)
        |> then(fn expr ->
          no_filter_static_forbidden_reads? =
            Keyword.get(
              Application.get_env(:ash, :policies, []),
              :no_filter_static_forbidden_reads?,
              true
            )

          if no_filter_static_forbidden_reads? || authorizer.for_fields ||
               authorizer.action.type != :read ||
               context[:private][:pre_flight_authorization?] do
            try_eval(expr, authorizer)
          else
            case expr do
              true ->
                {:ok, true}

              false ->
                {:ok, false}

              other ->
                other
            end
          end
        end)
        |> case do
          {:ok, v} when v in [true, false] ->
            {:ok, v}

          {:ok, nil} ->
            {:ok, false}

          _ ->
            {:ok, :unknown}
        end
      end

      defp try_eval(expression, %{
             resource: resource,
             action_input: %Ash.ActionInput{tenant: tenant} = action_input,
             actor: actor
           }) do
        expression =
          Ash.Expr.fill_template(
            expression,
            actor,
            action_input.arguments,
            action_input.context
          )

        case Ash.Filter.hydrate_refs(expression, %{
               resource: resource,
               unknown_on_unknown_refs?: true,
               aggregates: %{},
               calculations: %{},
               public?: false
             }) do
          {:ok, hydrated} ->
            Ash.Expr.eval_hydrated(hydrated,
              resource: resource,
              unknown_on_unknown_refs?: true,
              actor: actor,
              tenant: tenant
            )

          {:error, error} ->
            {:error, error}
        end
      end

      defp try_eval(expression, %{
             resource: resource,
             query: %Ash.Query{tenant: tenant} = query,
             actor: actor
           }) do
        case Ash.Filter.hydrate_refs(expression, %{
               resource: resource,
               aggregates: query.aggregates,
               calculations: query.calculations,
               public?: false
             }) do
          {:ok, hydrated} ->
            Ash.Expr.eval_hydrated(hydrated,
              resource: resource,
              unknown_on_unknown_refs?: true,
              actor: actor,
              tenant: tenant
            )

          {:error, error} ->
            {:error, error}
        end
      end

      defp try_eval(expression, %{
             resource: resource,
             changeset: %Ash.Changeset{action_type: :create, tenant: tenant} = changeset,
             actor: actor
           }) do
        expression =
          Ash.Expr.fill_template(
            expression,
            actor,
            changeset.arguments,
            changeset.context,
            changeset
          )

        case Ash.Filter.hydrate_refs(expression, %{
               resource: resource,
               unknown_on_unknown_refs?: true,
               aggregates: %{},
               calculations: %{},
               public?: false
             }) do
          {:ok, hydrated} ->
            Ash.Expr.eval_hydrated(hydrated,
              resource: resource,
              unknown_on_unknown_refs?: true,
              actor: actor,
              tenant: tenant
            )

          {:error, error} ->
            {:error, error}
        end
      end

      defp try_eval(expression, %{
             resource: resource,
             changeset: %Ash.Changeset{data: data, tenant: tenant} = changeset,
             actor: actor
           }) do
        case Ash.Filter.hydrate_refs(expression, %{
               resource: resource,
               aggregates: %{},
               calculations: %{},
               public?: false
             }) do
          {:ok, hydrated} ->
            opts = [
              resource: resource,
              unknown_on_unknown_refs?: true,
              actor: actor,
              tenant: tenant
            ]

            # We don't want to authorize on stale data in real life
            # but when using utilities to check if something *will* be authorized
            # that is our intent
            opts =
              if changeset.context[:private][:pre_flight_authorization?] do
                case data do
                  %Ash.Changeset.OriginalDataNotAvailable{reason: :atomic_query_destroy} ->
                    opts

                  data ->
                    Keyword.put(opts, :record, data)
                end
              else
                opts
              end

            hydrated
            |> Ash.Expr.eval_hydrated(opts)

          {:error, error} ->
            {:error, error}
        end
      end

      defp try_eval(expression, %{resource: resource, actor: actor}) do
        case Ash.Filter.hydrate_refs(expression, %{
               resource: resource,
               aggregates: %{},
               calculations: %{},
               public?: false
             }) do
          {:ok, hydrated} ->
            Ash.Expr.eval_hydrated(hydrated,
              resource: resource,
              unknown_on_unknown_refs?: true,
              actor: actor
            )

          {:error, error} ->
            {:error, error}
        end
      end

      defp no_related_references?(expression) do
        expression
        |> Ash.Filter.list_refs()
        |> Enum.any?(&(&1.relationship_path != []))
      end

      def auto_filter(actor, authorizer, opts) do
        opts = Keyword.put_new(opts, :resource, authorizer.resource)

        context =
          case authorizer.subject do
            %{context: context} -> context
            _ -> %{}
          end

        Ash.Expr.fill_template(
          filter(actor, authorizer, opts),
          actor,
          Ash.Policy.FilterCheck.args(authorizer),
          context
        )
      end

      def auto_filter_not(actor, authorizer, opts) do
        opts = Keyword.put_new(opts, :resource, authorizer.resource)

        context =
          case authorizer.subject do
            %{context: context} -> context
            _ -> %{}
          end

        Ash.Expr.fill_template(
          reject(actor, authorizer, opts),
          actor,
          Ash.Policy.FilterCheck.args(authorizer),
          context
        )
      end

      def reject(actor, authorizer, opts) do
        opts = Keyword.put_new(opts, :resource, authorizer.resource)
        [not: filter(actor, authorizer, opts)]
      end

      def check(actor, data, authorizer, opts) do
        pkey = Ash.Resource.Info.primary_key(authorizer.resource)

        filter =
          case data do
            [record] -> Map.take(record, pkey)
            records -> [or: Enum.map(data, &Map.take(&1, pkey))]
          end

        authorizer.resource
        |> Ash.Query.filter(^filter)
        |> Ash.Query.filter(^auto_filter(actor, authorizer, opts))
        |> Ash.read(domain: authorizer.domain)
        |> case do
          {:ok, authorized_data} ->
            authorized_pkeys = Enum.map(authorized_data, &Map.take(&1, pkey))

            Enum.filter(data, fn record ->
              Map.take(record, pkey) in authorized_pkeys
            end)

          {:error, error} ->
            {:error, error}
        end
      end

      def expand_description(actor, authorizer, opts) do
        changeset =
          case authorizer.subject do
            %Ash.Changeset{} = changeset -> changeset
            _ -> nil
          end

        {:ok,
         actor
         |> filter(authorizer, opts)
         |> Ash.Expr.fill_template(
           actor,
           authorizer.subject.arguments,
           authorizer.subject.context,
           changeset
         )
         |> inspect()}
      end

      def prefer_expanded_description?, do: false

      defoverridable reject: 3,
                     requires_original_data?: 2,
                     expand_description: 3,
                     prefer_expanded_description?: 0
    end
  end

  def is_filter_check?(module) do
    :erlang.function_exported(module, :filter, 1)
  end

  @doc false
  def args(%{changeset: %{arguments: arguments}}) do
    arguments
  end

  def args(%{query: %{arguments: arguments}}) do
    arguments
  end

  def args(%{action_input: %{arguments: arguments}}) do
    arguments
  end

  def args(_), do: %{}
end
