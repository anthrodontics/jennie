defmodule JennieTest do
  use ExUnit.Case, async: true
  doctest Jennie

  describe "Interpolation" do
    test "Jennie-free templates should render as-is." do
      assert Jennie.render("Hello from {Jennie}!\n") == "Hello from {Jennie}!\n"
    end

    test "Unadorned tags should interpolate content into the template." do
      assert Jennie.render("Hello, {{subject}}!\n", %{"subject" => "world"}) == "Hello, world!\n"
    end

    test "Interpolated tag output should be not re-interpolated." do
      assert Jennie.render("{{template}}: {{planet}}", %{
               "template" => "{{planet}}",
               "planet" => "Earth"
             }) == "{{planet}}: Earth"
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

    test "Dotted names are a form of shorthand for sections." do
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

    test "The second part of a dotted name should resolve as any other name." do
      # Elixir will override the key in the map. So we listen dutifully.
      data = %{
        "a" => %{
          "b" => %{
            "c" => %{
              "d" => %{
                "e" => %{
                  "name" => "Wrong"
                }
              }
            }
          },
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

    test "Dotted names should be resolved against former resolutions." do
      data = %{
        "a" => %{
          "b" => %{}
        },
        "b" => %{
          "c" => "ERROR"
        }
      }

      assert Jennie.render("{{#a}}{{b.c}}{{/a}}", data) == "ERROR"
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
      assert Jennie.render("{{.}} miles an hour!", 85) == "85 miles an hour!"
    end

    test "Interpolation should not alter surrounding whitespace." do
      assert Jennie.render("| {{string}} |", %{"string" => "---"}) == "| --- |"
    end

    test "Superfluous in-tag whitespace should be ignored." do
      assert Jennie.render("|{{ string }}|", %{"string" => "---"}) == "|---|"
    end
  end

  describe "Sections" do
    test "Truthy - Truthy sections should have their contents rendered" do
      data = %{"boolean" => true}
      template = "{{#boolean}}This should be rendered.{{/boolean}}"
      expected = "This should be rendered."

      assert Jennie.render(template, data) == expected
    end

    test "Falsey - Falsey sections should have their contents omitted" do
      data = %{"boolean" => false}
      template = "{{#boolean}}This should not be rendered.{{/boolean}}"
      expected = ""

      assert Jennie.render(template, data) == expected
    end

    test "Null is falsey - Null is falsey" do
      data = %{"null" => nil}
      template = "{{#null}}This should not be rendered.{{/null}}"
      expected = ""

      assert Jennie.render(template, data) == expected
    end

    test "Context - Objects and hashes should be pushed onto the context stack" do
      data = %{"context" => %{"name" => "Joe"}}
      template = "{{#context}}Hi {{name}}.{{/context}}"
      expected = "Hi Joe."

      assert Jennie.render(template, data) == expected
    end

    test "Parent contexts - Names missing in the current context are looked up in the stack" do
      data = %{
        "a" => "foo",
        "b" => "wrong",
        "sec" => %{"b" => "bar"},
        "c" => %{"d" => "baz"}
      }

      template = "{{#sec}}{{a}}, {{b}}, {{c.d}}{{/sec}}"
      expected = "foo, bar, baz"

      assert Jennie.render(template, data) == expected
    end

    test "Variable test - Non-false sections have their value at the top of context" do
      data = %{"foo" => "bar"}
      template = "{{#foo}}{{.}} is {{foo}}{{/foo}}"
      expected = "bar is bar"

      assert Jennie.render(template, data) == expected
    end

    #   test "List Contexts - All elements on the context stack should be accessible within lists" do
    #     data = %{
    #       "tops" => [
    #         %{
    #           "tname" => %{"upper" => "A", "lower" => "a"},
    #           "middles" => [
    #             %{
    #               "mname" => "1",
    #               "bottoms" => [
    #                 %{"bname" => "x"},
    #                 %{"bname" => "y"}
    #               ]
    #             }
    #           ]
    #         }
    #       ]
    #     }

    #     template =
    #       "{{#tops}}{{#middles}}{{tname.lower}}{{mname}}.{{#bottoms}}{{tname.upper}}{{mname}}{{bname}}.{{/bottoms}}{{/middles}}{{/tops}}"

    #     expected = "a1.A1x.A1y."

    #     assert Jennie.render(template, data) == expected
    #   end

    test "Deeply Nested Contexts - All elements on the context stack should be accessible" do
      data = %{
        "a" => %{"one" => 1},
        "b" => %{"two" => 2},
        "c" => %{
          "three" => 3,
          "d" => %{"four" => 4, "five" => 5}
        }
      }

      template = """
      {{#a}}
      {{one}}
      {{#b}}
      {{one}}{{two}}{{one}}
      {{#c}}
      {{one}}{{two}}{{three}}{{two}}{{one}}
      {{#d}}
      {{one}}{{two}}{{three}}{{four}}{{three}}{{two}}{{one}}
      {{#five}}
      {{one}}{{two}}{{three}}{{four}}{{five}}{{four}}{{three}}{{two}}{{one}}
      {{one}}{{two}}{{three}}{{four}}{{.}}6{{.}}{{four}}{{three}}{{two}}{{one}}
      {{one}}{{two}}{{three}}{{four}}{{five}}{{four}}{{three}}{{two}}{{one}}
      {{/five}}
      {{one}}{{two}}{{three}}{{four}}{{three}}{{two}}{{one}}
      {{/d}}
      {{one}}{{two}}{{three}}{{two}}{{one}}
      {{/c}}
      {{one}}{{two}}{{one}}
      {{/b}}
      {{one}}
      {{/a}}
      """

      expected = """

      1
      121
      12321
      1234321
      123454321
      12345654321
      123454321
      1234321
      12321
      121
      1
      """

      assert Jennie.render(template, data) == expected
    end

    #   test "List - Lists should be iterated; list items should visit the context stack" do
    #     data = %{"list" => [%{"item" => 1}, %{"item" => 2}, %{"item" => 3}]}
    #     template = "{{#list}}{{item}}{{/list}}"
    #     expected = "123"

    #     assert Jennie.render(template, data) == expected
    #   end

    #   test "Empty List - Empty lists should behave like falsey values" do
    #     data = %{"list" => []}
    #     template = "{{#list}}Yay lists!{{/list}}"
    #     expected = ""

    #     assert Jennie.render(template, data) == expected
    #   end

    test "Doubled - Multiple sections per template should be permitted" do
      data = %{"bool" => true, "two" => "second"}

      template = """
      {{#bool}}
      * first
      {{/bool}}
      * {{two}}
      {{#bool}}
      * third
      {{/bool}}
      """

      expected = """

      * first
      * second
      * third
      """

      assert Jennie.render(template, data) == expected
    end

    test "Nested (Truthy) - Nested truthy sections should have their contents rendered" do
      data = %{"bool" => true}
      template = "| A {{#bool}}B {{#bool}}C{{/bool}} D{{/bool}} E |"
      expected = "| A B C D E |"

      assert Jennie.render(template, data) == expected
    end

    test "Nested (Falsey) - Nested falsey sections should be omitted" do
      data = %{"bool" => false}
      template = "| A {{#bool}}B {{#bool}}C{{/bool}} D{{/bool}} E |"
      expected = "| A  E |"

      assert Jennie.render(template, data) == expected
    end

    test "Context Misses - Failed context lookups should be considered falsey" do
      data = %{}
      template = "[{{#missing}}Found key 'missing'!{{/missing}}]"
      expected = "[]"

      assert Jennie.render(template, data) == expected
    end

    #   test "Implicit Iterator - String - Implicit iterators should directly interpolate strings" do
    #     data = %{"list" => ["a", "b", "c", "d", "e"]}
    #     template = "{{#list}}({{.}}){{/list}}"
    #     expected = "(a)(b)(c)(d)(e)"

    #     assert Jennie.render(template, data) == expected
    #   end

    #   test "Implicit Iterator - Integer - Implicit iterators should cast integers to strings and interpolate" do
    #     data = %{"list" => [1, 2, 3, 4, 5]}
    #     template = "{{#list}}({{.}}){{/list}}"
    #     expected = "(1)(2)(3)(4)(5)"

    #     assert Jennie.render(template, data) == expected
    #   end

    #   test "Implicit Iterator - Decimal - Implicit iterators should cast decimals to strings and interpolate" do
    #     data = %{"list" => [1.1, 2.2, 3.3, 4.4, 5.5]}
    #     template = "{{#list}}({{.}}){{/list}}"
    #     expected = "(1.1)(2.2)(3.3)(4.4)(5.5)"

    #     assert Jennie.render(template, data) == expected
    #   end

    #   test "Implicit Iterator - Array - Implicit iterators should allow iterating over nested arrays" do
    #     data = %{"list" => [[1, 2, 3], ["a", "b", "c"]]}
    #     template = "{{#list}}({{#.}}{{.}}{{/.}}){{/list}}"
    #     expected = "(123)(abc)"

    #     assert Jennie.render(template, data) == expected
    #   end

    #   test "Implicit Iterator - Root-level - Implicit iterators should work on root-level lists" do
    #     data = [%{"value" => "a"}, %{"value" => "b"}]
    #     template = "{{#.}}({{value}}){{/.}}"
    #     expected = "(a)(b)"

    #     assert Jennie.render(template, data) == expected
    #   end

    test "Dotted Names - Truthy - Dotted names should be valid for Section tags" do
      data = %{"a" => %{"b" => %{"c" => true}}}
      template = "{{#a.b.c}}Here{{/a.b.c}}"
      expected = "Here"

      assert Jennie.render(template, data) == expected
    end

    test "Dotted Names - Falsey - Dotted names should be valid for Section tags" do
      data = %{"a" => %{"b" => %{"c" => false}}}
      template = "{{#a.b.c}}Here{{/a.b.c}}"
      expected = ""

      assert Jennie.render(template, data) == expected
    end

    test "Dotted Names - Broken Chains - Dotted names that cannot be resolved should be considered falsey" do
      data = %{"a" => %{}}
      template = "{{#a.b.c}}Here{{/a.b.c}}"
      expected = ""

      assert Jennie.render(template, data) == expected
    end

    test "Surrounding Whitespace - Sections should not alter surrounding whitespace" do
      data = %{"boolean" => true}
      template = " | {{#boolean}}\t|\t{{/boolean}} | \n"
      expected = " | \t|\t | \n"

      assert Jennie.render(template, data) == expected
    end

    test "Indented Inline Sections - Single-line sections should not alter surrounding whitespace" do
      data = %{"boolean" => true}
      template = " {{#boolean}}YES{{/boolean}}\n {{#boolean}}GOOD{{/boolean}}\n"
      expected = " YES\n GOOD\n"

      assert Jennie.render(template, data) == expected
    end

    test "Standalone Lines - Standalone lines should be removed from the template" do
      data = %{"boolean" => true}
      template = "| This Is\n{{#boolean}}\n|\n{{/boolean}}\n| A Line\n"
      expected = "| This Is\n|\n| A Line\n"

      assert Jennie.render(template, data) == expected
    end

    test "Indented Standalone Lines - Indented standalone lines should be removed from the template" do
      data = %{"boolean" => true}
      template = "| This Is\n  {{#boolean}}\n|\n  {{/boolean}}\n| A Line\n"
      expected = "| This Is\n|\n| A Line\n"

      assert Jennie.render(template, data) == expected
    end

    test "Standalone Line Endings - \\r\\n should be considered a newline for standalone tags" do
      data = %{"boolean" => true}
      template = "\n\n{{#boolean}}\r\n{{/boolean}}\n\n"
      expected = "\n\n"

      assert Jennie.render(template, data) == expected
    end

    test "Standalone Without Previous Line - Standalone tags should not require a newline to precede them" do
      data = %{"boolean" => true}
      template = "  {{#boolean}}\n{{/boolean}}\n/"
      expected = "/"

      assert Jennie.render(template, data) == expected
    end

    test "Standalone Without Newline - Standalone tags should not require a newline to follow them" do
      data = %{"boolean" => true}
      template = "{{#boolean}}\n/\n  {{/boolean}}"
      expected = "\n/"

      assert Jennie.render(template, data) == expected
    end

    test "Padding - Superfluous in-tag whitespace should be ignored" do
      data = %{"boolean" => true}
      template = "|{{# boolean }}={{/ boolean }}|"
      expected = "|=|"

      assert Jennie.render(template, data) == expected
    end
  end
end
