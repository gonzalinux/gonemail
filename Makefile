.PHONY: help setup deps test format clean run iex db-setup db-reset prod logs stop ps

help:
	@echo "Available commands:"
	@echo "  make setup     - Install dependencies, create DB, run migrations"
	@echo "  make deps      - Install mix dependencies"
	@echo "  make test      - Run all tests"
	@echo "  make format    - Format code"
	@echo "  make run       - Start Phoenix server"
	@echo "  make iex       - Start interactive Phoenix server"
	@echo "  make db-setup  - Create and migrate database"
	@echo "  make db-reset  - Drop, create, and migrate database"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make prod      - Build and deploy with Docker Compose (minimal downtime)"
	@echo "  make logs      - Follow container logs"
	@echo "  make stop      - Stop Docker containers"
	@echo "  make ps        - Show container status"

setup:
	mix setup

deps:
	mix deps.get

test:
	mix test

format:
	mix format

run:
	@if [ -f .env ]; then \
		export $$(grep -v '^#' .env | xargs) && mix phx.server; \
	else \
		mix phx.server; \
	fi

iex:
	@if [ -f .env ]; then \
		export $$(grep -v '^#' .env | xargs) && iex -S mix phx.server; \
	else \
		iex -S mix phx.server; \
	fi

prod:
	git pull
	docker compose up -d --build --remove-orphans

logs:
	docker compose logs -f

stop:
	docker compose stop

ps:
	docker compose ps

db-setup:
	mix ecto.setup

db-reset:
	mix ecto.reset

clean:
	mix clean
