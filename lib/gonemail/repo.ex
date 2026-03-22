defmodule Gonemail.Repo do
  use Ecto.Repo,
    otp_app: :gonemail,
    adapter: Ecto.Adapters.Postgres
end
