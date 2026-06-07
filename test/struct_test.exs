defmodule Jennie.StructTest.Address do
  @moduledoc false
  defstruct [:city, :zip]
end

defmodule Jennie.StructTest.User do
  @moduledoc false
  defstruct [:name, :address, :tags]
end

defmodule Jennie.StructTest.Box do
  @moduledoc false
  defstruct [:user, :address]
end

defmodule Jennie.StructTest do
  @moduledoc """
  Elixir structs must be usable anywhere a map is: as the top-level
  context, nested inside maps/structs, reached via dotted names, pushed by
  sections, and iterated in lists. `Jennie.Utils.normalize/1` strips the
  `__struct__` field and stringifies the atom keys lazily as each frame is
  visited.
  """
  use ExUnit.Case, async: true

  alias Jennie.StructTest.{Address, Box, User}

  describe "first-level structs" do
    test "a struct is the top-level context" do
      assert Jennie.render("{{name}}", %User{name: "Jennie"}) == "Jennie"
    end

    test "a missing (nil) struct field renders as empty" do
      assert Jennie.render("[{{address}}]", %User{name: "J"}) == "[]"
    end

    test "the __struct__ key is not exposed" do
      assert Jennie.render("[{{__struct__}}]", %User{name: "J"}) == "[]"
    end

    test "a struct field that is a list iterates" do
      assert Jennie.render("{{#tags}}[{{.}}]{{/tags}}", %User{tags: ["x", "y"]}) == "[x][y]"
    end

    test "a struct works as a section value pushed onto the stack" do
      data = %{"self" => %User{name: "Lisa"}}
      assert Jennie.render("{{#self}}{{name}}{{/self}}", data) == "Lisa"
    end

    test "a struct works as the top-level implicit iterator" do
      assert Jennie.render("{{#tags}}{{.}}{{/tags}}", %User{tags: ["a", "b"]}) == "ab"
    end
  end

  describe "nested structs via sections" do
    test "a struct field that is a struct is pushed by a section" do
      data = %User{address: %Address{city: "Seoul", zip: "01"}}
      assert Jennie.render("{{#address}}{{city}} {{zip}}{{/address}}", data) == "Seoul 01"
    end

    test "an inverted section sees a nil struct field as falsey" do
      assert Jennie.render("{{^address}}none{{/address}}", %User{name: "J"}) == "none"
    end

    test "a list of structs iterates" do
      data = %{"users" => [%User{name: "A"}, %User{name: "B"}]}
      assert Jennie.render("{{#users}}({{name}}){{/users}}", data) == "(A)(B)"
    end

    test "parent struct fields are reachable from a nested section" do
      data = %User{name: "Top", address: %Address{city: "Seoul"}}

      assert Jennie.render("{{#address}}{{name}} lives in {{city}}{{/address}}", data) ==
               "Top lives in Seoul"
    end
  end

  describe "nested structs via dotted names" do
    test "a struct field is reachable with a dotted name" do
      data = %User{name: "J", address: %Address{city: "Seoul", zip: "01"}}
      assert Jennie.render("{{address.city}}", data) == "Seoul"
    end

    test "a struct nested inside a map is reachable with a dotted name" do
      assert Jennie.render("{{user.name}}", %{"user" => %User{name: "Rose"}}) == "Rose"
    end

    test "struct-in-struct-in-struct resolves to any depth" do
      data = %Box{user: %User{name: "J", address: %Address{city: "Busan"}}}
      assert Jennie.render("{{user.address.city}}", data) == "Busan"
    end

    test "a broken chain through a struct is falsey" do
      data = %Box{user: %User{name: "J", address: nil}}
      assert Jennie.render("[{{user.address.city}}]", data) == "[]"
    end
  end

  describe "mixing structs and maps" do
    test "a plain map nested inside a struct works" do
      assert Jennie.render("{{#address}}{{city}}{{/address}}", %Box{address: %{"city" => "X"}}) ==
               "X"
    end

    test "a struct nested inside a map nested inside a struct works" do
      data = %Box{user: %{"profile" => %Address{city: "Incheon"}}}
      assert Jennie.render("{{user.profile.city}}", data) == "Incheon"
    end
  end

  describe "compiled templates with struct data" do
    test "a compiled template renders against struct data" do
      {:ok, tpl} = Jennie.compile("{{name}} @ {{address.city}}")
      data = %User{name: "Jennie", address: %Address{city: "Seoul"}}
      assert Jennie.render(tpl, data) == "Jennie @ Seoul"
    end
  end
end
