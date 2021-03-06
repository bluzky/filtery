defmodule Filtery do
  @doc """
  `Filtery` help you to build the query using a syntax which is similar to Mongo like this:

  ```elixir
  filter = %{
    status: "active",
    email: {:not, nil},
    role: ["admin", "moderator"]
  }
  Filtery.apply(User, filter)
  ```



  The result is a query like this:

  ```elixir
  from(u in User, where: u.status == "active" and not is_nil(u.email) and u.role in ["admin", "moderator"])
  ```



  ## Syntax

  - You can use `<field>: <value>` expressions to specify the equality condition and query operator expressions.

  ```elixir
  %{
    <field1>: <value1>,
    <field2>: { <operator>, <value> },
    ...
  }
  ```

  - All fields which field name starts with `_` is ignored.



  **Notes: all operator belows are reserved keywords and cannot be used as field name**



  ### Supported operator

  | Name  | Description          |
  | ------ | :----------------------------------------------------------- |
  | `:eq`  | Matches values that are equal to a specified value.          |
  | `:gt`  | Matches values that are greater than a specified value.      |
  | `:gte` | Matches values that are greater than or equal to a specified value. |
  | `:in`  | Matches any of the values specified in an array.             |
  | `:lt`  | Matches values that are less than a specified value.         |
  | `:lte` | Matches values that are less than or equal to a specified value. |
  | `:ne`  | Matches all values that are not equal to a specified value.  |
  | `:nin` | Matches none of the values specified in an array.            |



  ### Logical operator

  | Name   | Description                                                  |
  | ------ | ------------------------------------------------------------ |
  | `:and` | Joins query clauses with a logical `AND` returns all documents that match the conditions of both clauses. |
  | `:not` | Inverts the effect of a query expression and returns documents that do *not* match the query expression. |
  | `:or`  | Joins query clauses with a logical `OR` returns all documents that match the conditions of either clause. |



  ### `AND` operator

  By default, if  a map or keyword list is given, `Filtery` will join all field condition of that map using `AND`



  ```elixir
  Filtery.apply(User, %{status: "active", age: {:gt, 20}})

  # same with
  Filtery.apply(User, %{and:
                        %{status: "active", age: {:gt, 20}}
                        })

  # same with
  Filtery.apply(User, %{and:
                        [status: "active", age: {:gt, 20]}
                       })

  # same with
  from(u in User, where: u.status == "active" and u.age > 20)
  ```



  ### `OR` operator

  The `:or` operator performs a logical `OR` operation on an array of *two or more* `<expressions>` 





  ```elixir
  Filtery.apply(Product, %{or: %{
                             price: {:gt, 20},
                             category: "sport"
                           }})
  ```



  ### `NOT` operator

  Performs a logical `NOT` operation on the specified `<operator-expression>` 

  *Syntax*: `%{ field: %{ not:  <operator-expression>  } }`



  ```elixir
  Filtery.apply(Product, %{or: %{
                             price: {:gt, 20},
                             category: {:not: "sport"}
                           }})

  Filtery.apply(Product, %{or: %{
                             price: {:not, {:gt, 20}},
                             category: "sport"
                           }})
  ```




  ### 3. Extra operator

  `Filtery` provides some more useful operators to work with text and range.



  | Name                 | Description                                                  |
  | -------------------- | ------------------------------------------------------------ |
  | `:between`           | Matches values `>` lower bound and `<` upper bound           |
  | `:ibetween`          | Matches values `>=` lower bound and `<=`upper  bound         |
  | `like`, `contains`   | Match values which contains specific value                   |
  | `ilike`, `icontains` | Case insensitive version of `like`                           |
  | `has`                | For array type column, Matches array which has specific value |



  #### Syntax

  - `between` | `ibetween`

    *Syntax*:  `field: {:between, [lower_value, upper_value]}`





  ### Check `NULL` and skip `nil` filter

  By default is a value in the filter is `nil`, `Filtery` applies `is_nil` to check `NULL` value. You can tell `Filtery` to ignore all `nil` field by passing `skip_nil: true` to the options

  ```elixir
  Filtery.apply(query, filter, skip_nil: true)
  ```



  In that case, if you want to check field which is `NULL` or `NOT NULL` you use `:is_nil` instead of `nil` when passing value to the filter:

  ```elixir
  Filter.apply(query, %{email: :is_nil}, skip_nil: true)
  ```



  ## Define your operators

  You can extend `Filtery` and define your own operator. For example, here I define a new operatory `equal`  

  ```elixir
  defmodule MyFiltery do
    use Filtery.Base

    def filter(column, {:equal, value}) do
      dynamic([q], field(q, ^column) == ^value)
    end
  end
  ```



  To support a filter, you must follow this spec

  ```elixir
  @spec filter(column::atom(), {operator::atom(), value::any()}) :: Ecto.Query.dynamic()
  ```

  Within the body of `filter/2` function using `dynamic` to compose your condtion and return a `dynamic`

  ## V. Joining tables 

  **`Filtery` defines a special operator `ref` to join table**

  *Syntax*: `<field>: {:ref, <qualifier>, <filter on joined table>}`

  If `qualifier` is skipped, then `:inner` join is used by default.

  ```elixir
  query = Filtery.apply(Post, %{comments: {:ref, %{
                                      approved: true,
                                      content: {:like, "filtery"}
                                   }}})
  ```

  And then you can use **Name binding** to do further query

  ```elixir
  query = where(query, [comments: c], c.published_at > ^xday_ago)
  ```



  **Qualifiers**

  By default `Filtery` join using `:inner` qualifier. You can use one of ``:inner`, `:left`, `:right`, `:cross`, `:full`, `:inner_lateral` or `:left_lateral` qualifier as defined by Ecto.



  ### **You can filter with nested `ref`**

  ```elixir
  Filtery.apply(Post, %{comments: {:ref, %{
                                      approved: true,
                                      user: {:ref, %{
                                                name: {:like, "Tom"}
                                             }}
                                   }}})
  ```





  ### Important Notes on `ref` operator

  - Field name must be the association name in your schema because `Filtery` use `assoc` to build join query.

    In the above example, `Post` schema must define association `has_many: :comments, Comment`

  - Not allow 2 ref with same name because the name is used as alias `:as` in join query, so it can only use one.

  """

  use Filtery.Base
  @spec apply(Ecto.Queriable.t(), map() | keyword(), keyword()) :: Ecto.Query.Queriable.t()
end
