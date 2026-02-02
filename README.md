# Jennie 🩸

Logic-less templates inspired by Moustache. 

Anthrodontics is the mobile operating system for dentists. Templates are the 
best and most predictable form of automation. We need something that it is  
simple for users to understand, from beginners to experts. Curly brackets sit 
nicely in that spectrum - so there's currently Handlebars on the extreme end 
and Moustache on the other side. Jennie is a compromise that tries to achieve
the best of both worlds

## Installation

Add `jennie` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jennie, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
Jennie.render("Hello {{name}}!", %{"name" => "World"})
# Hello World!
```

You can run `mix test` to see the full code coverage.
