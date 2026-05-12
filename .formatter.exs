[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  inputs: ["*.{ex,exs,heex,eex}", "{config,lib,test}/**/*.{ex,exs,heex,eex}", "priv/*/seeds.exs"]
]
