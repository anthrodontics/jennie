defmodule JennieTest do
  use ExUnit.Case, async: true
  doctest Jennie

  describe "interpolation" do
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

      assert Jennie.render("{{#a}}{{b.c}}{{/a}}", data) == ""
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

  describe "sections" do
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

    test "List Contexts - All elements on the context stack should be accessible within lists" do
      data = %{
        "tops" => [
          %{
            "tname" => %{"upper" => "A", "lower" => "a"},
            "middles" => [
              %{
                "mname" => "1",
                "bottoms" => [
                  %{"bname" => "x"},
                  %{"bname" => "y"}
                ]
              }
            ]
          }
        ]
      }

      template =
        "{{#tops}}{{#middles}}{{tname.lower}}{{mname}}.{{#bottoms}}{{tname.upper}}{{mname}}{{bname}}.{{/bottoms}}{{/middles}}{{/tops}}"

      expected = "a1.A1x.A1y."

      assert Jennie.render(template, data) == expected
    end

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

    test "List - Lists should be iterated; list items should visit the context stack" do
      data = %{"list" => [%{"item" => 1}, %{"item" => 2}, %{"item" => 3}]}
      template = "{{#list}}{{item}}{{/list}}"
      expected = "123"

      assert Jennie.render(template, data) == expected
    end

    test "Empty List - Empty lists should behave like falsey values" do
      data = %{"list" => []}
      template = "{{#list}}Yay lists!{{/list}}"
      expected = ""

      assert Jennie.render(template, data) == expected
    end

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

    test "Implicit Iterator - String - Implicit iterators should directly interpolate strings" do
      data = %{"list" => ["a", "b", "c", "d", "e"]}
      template = "{{#list}}({{.}}){{/list}}"
      expected = "(a)(b)(c)(d)(e)"

      assert Jennie.render(template, data) == expected
    end

    test "Implicit Iterator - Integer - Implicit iterators should cast integers to strings and interpolate" do
      data = %{"list" => [1, 2, 3, 4, 5]}
      template = "{{#list}}({{.}}){{/list}}"
      expected = "(1)(2)(3)(4)(5)"

      assert Jennie.render(template, data) == expected
    end

    test "Implicit Iterator - Decimal - Implicit iterators should cast decimals to strings and interpolate" do
      data = %{"list" => [1.1, 2.2, 3.3, 4.4, 5.5]}
      template = "{{#list}}({{.}}){{/list}}"
      expected = "(1.1)(2.2)(3.3)(4.4)(5.5)"

      assert Jennie.render(template, data) == expected
    end

    test "Implicit Iterator - Array - Implicit iterators should allow iterating over nested arrays" do
      data = %{"list" => [[1, 2, 3], ["a", "b", "c"]]}
      template = "{{#list}}({{#.}}{{.}}{{/.}}){{/list}}"
      expected = "(123)(abc)"

      assert Jennie.render(template, data) == expected
    end

    test "Implicit Iterator - Root-level - Implicit iterators should work on root-level lists" do
      data = [%{"value" => "a"}, %{"value" => "b"}]
      template = "{{#.}}({{value}}){{/.}}"
      expected = "(a)(b)"

      assert Jennie.render(template, data) == expected
    end

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
      expected = "\n\n\n"

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
      expected = "/\n"

      assert Jennie.render(template, data) == expected
    end

    test "Padding - Superfluous in-tag whitespace should be ignored" do
      data = %{"boolean" => true}
      template = "|{{# boolean }}={{/ boolean }}|"
      expected = "|=|"

      assert Jennie.render(template, data) == expected
    end

    test "Sections - newlines before the section should be removed" do
      data = %{"planets" => ["Earth", "Mars", "Venus"]}
      template = "{{#planets}}\n- {{.}}\n{{/planets}}\n"
      expected = "- Earth\n- Mars\n- Venus\n"

      assert Jennie.render(template, data) == expected
    end

    defmodule Planet do
      defstruct [:name, :colour]
    end

    test "Sections - structs can also be referenced" do
      template = "{{#planets}}{{name}}{{/planets}}"
      expected = "Earth"

      assert Jennie.render(template, %{
               "planets" => [%Planet{:name => "Earth", :colour => "blue"}]
             }) == expected
    end
  end

  describe "HTML escaping" do
    test "HTML-escapes by default" do
      assert Jennie.render("{{x}}", %{"x" => "<b>&\"'"}) == "&lt;b&gt;&amp;&quot;&#39;"
    end

    test "triple mustache is unescaped and parses correctly" do
      assert Jennie.render("{{{x}}}", %{"x" => "<b>"}) == "<b>"
    end

    test "ampersand is unescaped" do
      assert Jennie.render("{{&x}}", %{"x" => "<b>"}) == "<b>"
    end

    test "escape function is overridable" do
      up = fn s -> String.upcase(s) end
      assert Jennie.render("{{x}}", %{"x" => "hi"}, escape: up) == "HI"
    end
  end

  describe "inverted sections" do
    test "renders on missing key" do
      assert Jennie.render("{{^x}}no x{{/x}}", %{}) == "no x"
    end

    test "renders on falsey, not on truthy" do
      assert Jennie.render("{{^x}}no{{/x}}", %{"x" => false}) == "no"
      assert Jennie.render("{{^x}}no{{/x}}", %{"x" => true}) == ""
    end

    test "renders on empty list" do
      assert Jennie.render("{{^x}}empty{{/x}}", %{"x" => []}) == "empty"
    end
  end

  describe "comments" do
    test "render nothing and do not collide with data keys" do
      assert Jennie.render("a{{! ignore me }}b", %{}) == "ab"
      assert Jennie.render("{{!foo}}", %{"!foo" => "X"}) == ""
    end
  end

  describe "set delimiters" do
    test "change delimiters for subsequent tags" do
      assert Jennie.render("{{=<% %>=}}<%x%>", %{"x" => "hi"}) == "hi"
    end
  end

  describe "partials" do
    test "resolve from a map" do
      assert Jennie.render("\"{{>t}}\"", %{}, partials: %{"t" => "in"}) == "\"in\""
    end

    test "resolve from a function" do
      resolver = fn "t" -> "in" end
      assert Jennie.render("{{>t}}", %{}, partials: resolver) == "in"
    end

    test "missing partial renders empty by default" do
      assert Jennie.render("[{{>t}}]", %{}) == "[]"
    end

    test "missing partial raises when configured" do
      assert_raise ArgumentError, fn ->
        Jennie.render("{{>t}}", %{}, raise_on_missing_partial: true)
      end
    end

    test "recursion terminates" do
      data = %{"content" => "X", "nodes" => [%{"content" => "Y", "nodes" => []}]}
      partials = %{"node" => "{{content}}<{{#nodes}}{{>node}}{{/nodes}}>"}
      assert Jennie.render("{{>node}}", data, partials: partials) == "X<Y<>>"
    end
  end

  describe "single-element list iteration" do
    test "iterates over a one-element list of false" do
      assert Jennie.render("{{#l}}X{{/l}}", %{"l" => [false]}) == "X"
    end

    test "iterates over a one-element list of empty map" do
      assert Jennie.render("[{{#l}}X{{/l}}]", %{"l" => [%{}]}) == "[X]"
    end

    test "iterates over many elements" do
      assert Jennie.render("{{#l}}({{.}}){{/l}}", %{"l" => ["a", "b"]}) == "(a)(b)"
    end

    test "empty list is falsey" do
      assert Jennie.render("{{#l}}X{{/l}}", %{"l" => []}) == ""
    end
  end

  describe "safe stringification" do
    test "list value does not become raw bytes" do
      assert Jennie.render("{{l}}", %{"l" => [1, 2]}) == "[1, 2]"
    end

    test "map value does not crash" do
      assert Jennie.render("{{{m}}}", %{"m" => %{"a" => 1}}) == "%{\"a\" => 1}"
    end

    test "numbers, booleans, nil" do
      assert Jennie.render("{{n}}", %{"n" => 42}) == "42"
      assert Jennie.render("{{n}}", %{"n" => 1.21}) == "1.21"
      assert Jennie.render("{{b}}", %{"b" => false}) == "false"
      assert Jennie.render("[{{x}}]", %{"x" => nil}) == "[]"
    end
  end

  describe "same-name nested sections" do
    test "nest correctly for maps" do
      assert Jennie.render("{{#a}}[{{#a}}x{{/a}}]{{/a}}", %{"a" => %{"a" => true}}) == "[x]"
    end

    test "nest correctly for booleans" do
      assert Jennie.render("{{#a}}1{{#a}}2{{/a}}3{{/a}}", %{"a" => true}) == "123"
    end
  end

  describe "data shapes" do
    defmodule Planet do
      defstruct [:name, :colour]
    end

    test "atom keys" do
      assert Jennie.render("{{x}}", %{x: "v"}) == "v"
    end

    test "structs" do
      assert Jennie.render("{{#planets}}{{name}}{{/planets}}", %{
               "planets" => [%Planet{name: "Earth", colour: "blue"}]
             }) == "Earth"
    end

    test "nested atom-keyed maps via dotted names" do
      assert Jennie.render("{{a.b}}", %{a: %{b: "deep"}}) == "deep"
    end

    test "non-map top-level data via implicit iterator" do
      assert Jennie.render("{{.}} miles", 85) == "85 miles"
    end
  end

  describe "dotted names" do
    test "resolve to any depth" do
      data = %{"a" => %{"b" => %{"c" => %{"d" => "deep"}}}}
      assert Jennie.render("{{a.b.c.d}}", data) == "deep"
    end

    test "broken chains are falsey" do
      assert Jennie.render("[{{a.b.c}}]", %{"a" => %{}}) == "[]"
    end

    test "are not parsed as atomic keys" do
      assert Jennie.render("{{a.b}}", %{"a.b" => "c"}) == ""
    end

    test "resolve against former resolutions only" do
      data = %{"a" => %{"b" => %{}}, "b" => %{"c" => "ERROR"}}
      assert Jennie.render("{{#a}}{{b.c}}{{/a}}", data) == ""
    end
  end

  describe "ignore_nil" do
    test "leaves absent tags in place" do
      assert Jennie.render("{{x}} {{y}}", %{"x" => "X"}, ignore_nil: true) == "X {{y}}"
    end

    test "leaves absent sections in place" do
      assert Jennie.render("{{#x}}body{{/x}}", %{}, ignore_nil: true) == "{{#x}}body{{/x}}"
    end

    test "distinguishes absent from present-but-empty" do
      assert Jennie.render("[{{x}}]", %{"x" => ""}, ignore_nil: true) == "[]"
      assert Jennie.render("[{{x}}]", %{"x" => nil}, ignore_nil: true) == "[]"
    end
  end

  describe "compile / scan / missing?" do
    test "compile once render many" do
      {:ok, tpl} = Jennie.compile("Hi {{n}}")
      assert Jennie.render(tpl, %{"n" => "A"}) == "Hi A"
      assert Jennie.render(tpl, %{"n" => "B"}) == "Hi B"
    end

    test "compile returns structured error" do
      assert {:error, %Jennie.SyntaxError{}} = Jennie.compile("{{#a}}oops")
    end

    test "scan lists referenced names, excluding comments/partials/implicit" do
      assert Jennie.scan("{{a}}{{#b}}{{c}}{{.}}{{/b}}{{!x}}{{>p}}") == ["a", "b", "c"]
    end

    test "missing? reports absent top-level keys" do
      assert Jennie.missing?("{{a}}{{b}}", %{"a" => 1}) == ["b"]
    end
  end

  describe "errors" do
    test "unclosed section" do
      assert_raise Jennie.SyntaxError, fn -> Jennie.render("{{#a}}x", %{}) end
    end

    test "mismatched closing tag" do
      assert_raise Jennie.SyntaxError, fn -> Jennie.render("{{#a}}x{{/b}}", %{}) end
    end

    test "closing an unopened section" do
      assert_raise Jennie.SyntaxError, fn -> Jennie.render("x{{/a}}", %{}) end
    end

    test "unterminated tag" do
      assert_raise Jennie.SyntaxError, fn -> Jennie.render("a {{ b ", %{}) end
    end

    test "carries an accurate line and column" do
      err =
        try do
          Jennie.render("ok\nline2 {{/oops}}", %{})
          nil
        rescue
          e in Jennie.SyntaxError -> e
        end

      assert err.line == 2
      assert err.column == 7
    end
  end
end
