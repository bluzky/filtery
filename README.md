# Filtery

**`Filtery` help you to build the query using a syntax which is similar to Mongo**

## Installation

Add `filtery` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:filtery, "~> 0.1.0"}
  ]
end
```

Documentation is published here [https://hexdocs.pm/filtery](https://hexdocs.pm/filtery).


## Usage

`Filtery` help you to build the query using a similar syntax with MongoDB like this:

```elixir
filter = %{
	status: "active",
	email: %{not: nil},
	role: ["admin", "moderator"]
}
Filtery.apply(User, filter)
```



The result is a query like this:

```elixir
from(u in User, where: u.status == "active" and not is_nil(u.email) and u.role in ["admin", "moderator"])
```



## Syntax

You can use `<field>: <value>` expressions to specify the equality condition and query operator expressions.

```
%{
  <field1>: <value1>,
  <field2>: { <operator>, <value> },
  ...
}
```



**Notes: all operator belows are reserved keywords and cannot be used as field name**



## Supported operator



### 1. Comparition operator

| `:eq`  | Matches values that are equal to a specified value.          |
| ------ | :----------------------------------------------------------- |
| `:gt`  | Matches values that are greater than a specified value.      |
| `:gte` | Matches values that are greater than or equal to a specified value. |
| `:in`  | Matches any of the values specified in an array.             |
| `:lt`  | Matches values that are less than a specified value.         |
| `:lte` | Matches values that are less than or equal to a specified value. |
| `:ne`  | Matches all values that are not equal to a specified value.  |
| `:nin` | Matches none of the values specified in an array.            |



### 2. Logical operator

| Name   | Description                                                  |
| ------ | ------------------------------------------------------------ |
| `:and` | Joins query clauses with a logical `AND` returns all documents that match the conditions of both clauses. |
| `:not` | Inverts the effect of a query expression and returns documents that do *not* match the query expression. |
|        |                                                              |
| `:or`  | Joins query clauses with a logical `OR` returns all documents that match the conditions of either clause. |



#### `AND` operator

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



#### `OR` operator

The `:or` operator performs a logical `OR` operation on an array of *two or more* `<expressions>` 





```elixir
Filtery.apply(Product, %{or: %{
                           price: {:gt, 20},
                           category: "sport"
                         }})
```



#### `NOT` operator

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

