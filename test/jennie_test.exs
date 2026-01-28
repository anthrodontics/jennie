defmodule JennieTest do
  use ExUnit.Case
  doctest Jennie

  describe "Interpolation" do
    test "Jennie-free templates should render as-is." do
      assert Jennie.render("Hello from {Jennie}!\n") == "Hello from {Jennie}!\n"
    end

    test "Unadorned tags should interpolate content into the template." do
      assert Jennie.render("Hello, {{subject}}!\n", %{"subject" => "world"}) == "Hello, world!\n"
    end

    test "Interpolated tag output should be re-interpolated." do
      assert Jennie.render("{{template}}: {{planet}}", %{
               "template" => "{{planet}}",
               "planet" => "Earth"
             }) == "Earth: Earth"
    end

    test "Integers should interpolate seamlessly." do
      assert Jennie.render("{{kph}} kilometres an hour!", %{"kph" => 85}) ==
               "85 kilometres an hour!"
    end

    test "Decimals should interpolate seamlessly with proper significance." do
      assert Jennie.render("{{power}} jigawatts!", %{"power" => 1.21}) ==
               "1.21 jigawatts!"
    end

    test "Nulls should interpolate as the empty string." do
      assert Jennie.render("I ({{cannot}}) be seen!", %{"cannot" => nil}) == "I () be seen!"
    end

    test "Failed context lookups should default to empty strings." do
      assert Jennie.render("I ({{cannot}}) be seen!") == "I () be seen!"
    end

    test "Dotted names should be considered a form of shorthand for sections." do
      data = %{"person" => %{"name" => "Joe"}}

      assert Jennie.render("{{person.name}} == Joe", data) == "Joe == Joe"
    end

    test "Dotted names should be considered a form of shorthand for sections." do
      data = %{"person" => %{"name" => "Joe"}}

      assert Jennie.render("{{person.name}} == {{#person}}{{name}}{{/person}}", data)
    end

    test "Dotted names should be functional to any level of nesting." do
      data = %{
        "a" => %{
          "b" => %{
            "c" => %{
              "d" => %{
                "e" => %{
                  "name" => "Phil"
                }
              }
            }
          }
        }
      }

      assert Jennie.render("{{a.b.c.d.e.name}} == Phil", data) == "Phil == Phil"
    end

    test "Any falsey value prior to the last part of the name should yield ''." do
      data = %{
        "a" => %{}
      }

      assert Jennie.render("\"{{a.b.c}}\" == \"\"", data) == "\"\" == \"\""
    end

    test "The first part of a dotted name should resolve as any other name." do
      data = %{
        "a" => %{
          "b" => %{
            "c" => %{
              "d" => %{
                "e" => %{
                  "name" => "Phil"
                }
              }
            }
          },
          "b" => %{
            "c" => %{
              "d" => %{
                "e" => %{
                  "name" => "Wrong"
                }
              }
            }
          }
        }
      }

      assert Jennie.render("{{a.b.c.d.e.name}} == Phil", data) == "Phil == Phil"
    end

    test "Dotted names should be resolved against former resolutions." do
      data = %{
        "a" => %{
          "b" => %{}
        },
        "b" => %{
          "c" => "ERROR"
        }
      }

      assert Jennie.render("\"{{#a}}{{b.c}}{{/a}}", data) == ""
    end

    test "Dotted names shall not be parsed as single, atomic keys" do
      data = %{"a.b" => "c"}

      assert Jennie.render("{{a.b}}", data) == ""
    end

    test "Dotted Names in a given context are unvavailable due to dot splitting" do
      data = %{
        "a.b" => "c",
        "a" => %{"b" => "d"}
      }

      assert Jennie.render("{{a.b}}", data) == "d"
    end

    test "Implicit Iterators - Integers should interpolate seamlessly." do
      assert Jennie.render("{{.}} miles an hour!", 85)
    end

    test "Interpolation should not alter surrounding whitespace." do
      assert Jennie.render("| {{string}} |", %{"string" => "---"}) == "| --- |"
    end

    test "Superfluous in-tag whitespace should be ignored." do
      assert Jennie.render("|{{ string }}|", %{"string" => "---"}) == "|---|"
    end
  end
end
