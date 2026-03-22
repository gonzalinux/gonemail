defmodule Gonemail.Auth.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Gonemail.Repo

  @slug_regex ~r/^[a-z0-9-]+$/

  schema "api_keys" do
    field :name, :string
    field :key_hash, :string
    field :active, :boolean, default: true
    timestamps(updated_at: false)
  end

  def generate(name) do
    secret = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    "#{name}:#{secret}"
  end

  def create(name) do
    raw_key = generate(name)
    hash = Argon2.hash_pwd_salt(raw_key)

    changeset(%__MODULE__{}, %{name: name, key_hash: hash})
    |> Repo.insert()
    |> case do
      {:ok, api_key} -> {:ok, raw_key, api_key}
      error -> error
    end
  end

  def validate(raw_key) when is_binary(raw_key) do
    with [name, _secret] <- String.split(raw_key, ":", parts: 2),
         hash = :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower),
         changeset = changeset(%__MODULE__{}, %{name: name, key_hash: hash}),
         true <- changeset.valid?,
         elements <- Repo.all(from k in __MODULE__, where: k.name == ^name) do
      Enum.find_value(elements, false, fn key ->
        if Argon2.verify_pass(raw_key, key.key_hash) do
          {:ok, key}
        end
      end)
    else
      _ -> false
    end
  end

  def validate(_), do: false

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :key_hash, :active])
    |> validate_required([:name, :key_hash])
    |> validate_format(:name, @slug_regex)
  end
end
