defmodule JennieTest do
  use ExUnit.Case
  doctest Jennie

  test "Basic Variables" do
    assert Jennie.render("Hello {{name}}", %{"name" => "World"}) == "Hello World"

    assert Jennie.render("{{#items}}<b>{{.}}</b>{{/items}}", %{"items" => ["a", "b", "c"]}) ==
             "<b>a</b><b>b</b><b>c</b>"

    assert Jennie.render("{{> header}}", %{"title" => "Hello"}, %{
             "header" => "<h1>{{title}}</h1>"
           }) == "<h1>Hello</h1>"
  end
end
