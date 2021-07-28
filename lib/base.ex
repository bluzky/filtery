defmodule Filtery.Base do
  defmacro __using__(_) do
    quote do
      import Ecto.Query
      import Kernel, except: [apply: 2, apply: 3]

      @before_compile Filtery.Base

      def apply(query, filters, opts \\ []) do
        do_apply(query, filters, opts)
      end

      defp do_apply(query, filters, opts) when is_map(filters) do
        filters = Map.to_list(filters)
        do_apply(query, filters, opts)
      end

      defp do_apply(query, filters, opts) when is_list(filters) do
        {sort, filters} = Keyword.pop(filters, :_sort, [])

        # skip field starts with underscore
        grouped_by_type =
          filters
          |> Enum.reject(fn
            {column, _} -> String.starts_with?(to_string(column), "_")
            _ -> false
          end)
          |> Enum.group_by(fn
            {_, {:ref, _}} -> :ref
            {_, {:ref, _, _}} -> :ref
            _ -> :filter
          end)

        column_filter = grouped_by_type[:filter] || []

        query
        |> filter_columns(column_filter, opts)
        |> join_ref(grouped_by_type[:ref], opts)
        |> sort(sort)
      end

      defp filter_columns(query, filters, opts) do
        filters =
          if opts[:skip_nil] do
            Enum.reject(filters, fn
              {_, nil} -> true
              {_, {_, nil}} -> true
              {_, {_, {_, nil}}} -> true
              _ -> false
            end)
          else
            filters
          end

        # build dynamic conditions
        case filter(:and, filters) do
          nil -> query
          d_query -> where(query, [q], ^d_query)
        end
      end

      # add single column query condition to existing query
      def filter(query, column, params) do
        case filter(column, params) do
          nil -> query
          d_query -> where(query, [q], ^d_query)
        end
      end

      @doc """
      Apply filter on single column
      If filter value is list, filter row that match any value in the list
      """

      def filter(:and, filters) when is_map(filters) or is_list(filters) do
        Enum.reduce(filters, nil, fn {key, val}, acc ->
          ft = filter(key, val)

          cond do
            is_nil(ft) -> acc
            is_nil(acc) -> dynamic([..., q], ^ft)
            ft -> dynamic([..., q], ^acc and ^ft)
            true -> acc
          end
        end)
      end

      def filter(:or, filters) when is_map(filters) or is_list(filters) do
        Enum.reduce(filters, nil, fn {key, val}, acc ->
          ft = filter(key, val)

          cond do
            is_nil(ft) -> acc
            is_nil(acc) -> dynamic([..., q], ^ft)
            ft -> dynamic([..., q], ^acc or ^ft)
            true -> acc
          end
        end)
      end

      def filter(:not, filters) when is_map(filters) or is_list(filters) do
        d_query = filter(:and, filters)

        if d_query do
          dynamic([..., q], not (^d_query))
        end
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def filter(column, {:gt, value}) do
        dynamic([..., q], field(q, ^column) > ^value)
      end

      def filter(column, {:gte, value}) do
        dynamic([..., q], field(q, ^column) >= ^value)
      end

      def filter(column, {:lt, value}) do
        dynamic([..., q], field(q, ^column) < ^value)
      end

      def filter(column, {:lte, value}) do
        dynamic([..., q], field(q, ^column) <= ^value)
      end

      def filter(column, {:eq, nil}) do
        dynamic([..., q], is_nil(field(q, ^column)))
      end

      def filter(column, {:eq, :is_nil}) do
        dynamic([..., q], is_nil(field(q, ^column)))
      end

      def filter(column, {:eq, value}) do
        dynamic([..., q], field(q, ^column) == ^value)
      end

      def filter(column, {:ne, value}) when value in [nil, :is_nil] do
        dynamic([..., q], not is_nil(field(q, ^column)))
      end

      def filter(column, {:ne, value}) do
        dynamic([..., q], field(q, ^column) != ^value)
      end

      def filter(column, {:not, value}) do
        ft = filter(column, value)

        if ft do
          dynamic([..., q], not (^ft))
        end
      end

      def filter(_column, {:in, nil}) do
        nil
      end

      def filter(column, {:in, values}) do
        dynamic([..., q], field(q, ^column) in ^values)
      end

      def filter(column, {:nin, values}) do
        dynamic([..., q], field(q, ^column) not in ^values)
      end

      # extra filters
      def filter(column, {:between, [lower, upper]}) do
        case [lower, upper] do
          [nil, nil] ->
            nil

          [nil, upper] ->
            filter(column, {:lt, upper})

          [lower, nil] ->
            filter(column, {:gt, lower})

          _ ->
            filter(:and, [
              {column, {:gt, lower}},
              {column, {:lt, upper}}
            ])
        end
      end

      # between inclusive
      def filter(column, {:ibetween, [lower, upper]}) do
        case [lower, upper] do
          [nil, nil] ->
            nil

          [nil, upper] ->
            filter(column, {:lte, upper})

          [lower, nil] ->
            filter(column, {:gte, lower})

          _ ->
            filter(:and, [
              {column, {:gte, lower}},
              {column, {:lte, upper}}
            ])
        end
      end

      def filter(_, {:between, _}), do: nil
      def filter(_, {:ibetween, _}), do: nil

      def filter(column, {:has, value}) do
        dynamic([..., q], ^value in field(q, ^column))
      end

      def filter(column, {:like, value}) do
        dynamic([..., q], like(field(q, ^column), ^"%#{value}%"))
      end

      def filter(column, {:ilike, value}) do
        dynamic([..., q], ilike(field(q, ^column), ^"%#{value}%"))
      end

      def filter(column, {:contains, value}) do
        filter(column, {:like, value})
      end

      def filter(column, {:icontains, value}) do
        filter(column, {:ilike, value})
      end

      # apply multiple condition on one column
      def filter(column, %{} = value) do
        conditions = Enum.map(value, &{column, &1})
        filter(:and, conditions)
      end

      # DONE: default filter equal
      def filter(column, values) when is_list(values) do
        filter(column, {:in, values})
      end

      def filter(column, value) do
        filter(column, {:eq, value})
      end

      defp sort(query, fields) do
        if is_nil(fields) or Enum.empty?(fields) do
          query
        else
          order =
            fields
            |> Enum.map(fn {column, direction} ->
              {direction, column}
            end)

          order_by(query, ^order)
        end
      end

      def join_ref(query, ref, opts \\ [])
      def join_ref(query, nil, _), do: query

      def join_ref(query, refs, opts) when is_list(refs) do
        Enum.reduce(refs, query, fn
          {column, {:ref, join_qual, ref_filter}}, query ->
            do_join(query, join_qual, {column, ref_filter}, opts)

          {column, {:ref, ref_filter}}, query ->
            do_join(query, {column, ref_filter}, opts)
        end)
      end

      defp do_join(query, qual \\ :inner, {column, filter}, opts)
           when qual in [:inner, :left, :right, :cross, :full, :inner_lateral, :left_lateral] do
        binding = opts[:binding]

        query =
          if binding do
            join(query, qual, [{^binding, a}], b in assoc(a, ^column))
          else
            join(query, qual, [a], b in assoc(a, ^column))
          end

        # WARNING this is a hack because Ecto only allow hard-coded `:as` name binding

        aliases = query.aliases

        if Map.has_key?(aliases, column) do
          raise ArgumentError, "Do not allow 2 ref binding with the same name"
        end

        aliases =
          case Enum.map(aliases, &elem(&1, 1)) do
            [] ->
              %{column => 1}

            positions ->
              max = Enum.max(positions)
              Map.put(aliases, column, max + 1)
          end

        # Update the alias map
        query = struct(query, aliases: aliases)

        # udpate option with new name binding
        opts = Keyword.put(opts, :binding, column)
        __MODULE__.apply(query, filter, opts)
      end

      def join_ref(query, _, _), do: query
    end
  end
end
