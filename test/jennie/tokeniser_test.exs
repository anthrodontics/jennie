defmodule Jennie.TokeniserTest do
  use ExUnit.Case, async: true
  
  require Jennie.Tokeniser, as: T
  
  @opts %{indentation: 0, trim: false}
  
  test "simple characters" do
    assert T.tokenise("foo", 1, 1, @opts) == {:ok, [{:text, 1, 1, ~c"foo"}, {:eof, 1, 4}]}  
  end
  
  test "strings with curly brackets" do
    assert T.tokenise("foo {{ bar }}", 1, 1, @opts) ==
             {:ok, [{:text, 1, 1, ~c"foo "}, {:tag, 1, 5, [], ~c" bar "}, {:eof, 1, 14}]}
  end
end