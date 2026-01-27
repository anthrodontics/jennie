defmodule Jennnie.Token do
  @type t ::
          {:variable, String.t(), boolean()}
          | {:section, String.t(), [t()]}
          | {:inverted, String.t(), [t()]}
          | {:comment, String.t()}
          | {:partial, String.t()}
          | {:text, String.t()}
          | {:delimiter, String.t(), String.t()}
end
