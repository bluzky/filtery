# Filtery

**`Filtery` help you to build the query using a similar syntax with MongoDB**

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



### Supported operator

| `:eq`  | Matches values that are equal to a specified value.          |
| ------ | :----------------------------------------------------------- |
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
|        |                                                              |
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


