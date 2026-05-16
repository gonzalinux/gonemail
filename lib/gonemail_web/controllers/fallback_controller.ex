defmodule GonemailWeb.FallbackController do
  use GonemailWeb, :controller

  def call(conn, {:error, :invalid_sender_domain}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "from email domain must match the app's registered domain"})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not found"})
  end

  def call(conn, {:error, changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: format_errors(changeset)})
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
