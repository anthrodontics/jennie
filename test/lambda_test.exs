defmodule Jennie.LambdaTest do
  use ExUnit.Case, async: true

  test "Interpolation" do
    assert Jennie.render("Hello, {{lambda}}!", %{"lambda" => fn -> "world" end}) ==
             "Hello, world!"
  end

  test "Interpolation - Expansion" do
    data = %{"lambda" => fn -> "{{planet}}" end, "planet" => "world"}
    assert Jennie.render("Hello, {{lambda}}!", data) == "Hello, world!"
  end

  test "Escaping" do
    data = %{"lambda" => fn -> ">" end}
    assert Jennie.render("<{{lambda}}{{{lambda}}}", data) == "<&gt;>"
  end

  test "Section" do
    lambda = fn text -> if text == "{{x}}", do: "yes", else: "no" end
    assert Jennie.render("<{{#lambda}}{{x}}{{/lambda}}>", %{"lambda" => lambda}) == "<yes>"
  end

  test "Section - Expansion" do
    data = %{"lambda" => fn text -> "#{text}{{planet}}#{text}" end, "planet" => "Earth"}
    assert Jennie.render("<{{#lambda}}-{{/lambda}}>", data) == "<-Earth->"
  end

  test "Section - Multiple Calls" do
    lambda = fn text -> "__#{text}__" end
    data = %{"lambda" => lambda}

    assert Jennie.render("{{#lambda}}FILE{{/lambda}} != {{#lambda}}LINE{{/lambda}}", data) ==
             "__FILE__ != __LINE__"
  end

  test "Inverted Section (a function is truthy, so nothing renders)" do
    data = %{"lambda" => fn _text -> false end, "static" => "static"}
    assert Jennie.render("<{{^lambda}}{{static}}{{/lambda}}>", data) == "<>"
  end

  test "arity-0 function in section position is treated as a thunk" do
    assert Jennie.render("{{#l}}body{{/l}}", %{"l" => fn -> true end}) == "body"
  end

  test "unsupported interpolation arity raises a clear error" do
    assert_raise ArgumentError, ~r/interpolation lambda must have arity 0/, fn ->
      Jennie.render("{{l}}", %{"l" => fn _a, _b -> "x" end})
    end
  end
end
