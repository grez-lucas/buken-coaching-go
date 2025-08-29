# Change these variables as necessary
main_package_path = ./cmd/server/
binary_name = server
docker_image_name = buken-coaching

# ==================================================================================== #
# HELPERS
# ==================================================================================== #

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

.PHONY: confirm
confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]

# ==================================================================================== #
# ENVIRONMENT
# ==================================================================================== #

## env: create .env file from .env.example if it doesn't exist
.PHONY: env
env:
	@if [ ! -f .env ]; then \
		echo "Creating .env file from .env.example..."; \
		cp .env.example .env; \
		echo ".env file created. Please update it with your settings."; \
	else \
		echo ".env file already exists."; \
	fi

## env/check: check if .env file exists
.PHONY: env/check
env/check:
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found. Run 'make env' to create one."; \
		exit 1; \
	fi

# ==================================================================================== #
# DEVELOPMENT
# ==================================================================================== #

## tidy: tidy modfiles and format .go files
.PHONY: tidy
tidy:
	go mod tidy -v
	go fmt ./...

## vendor: download and vendor dependencies
.PHONY: vendor
vendor:
	go mod download
	go mod vendor

## clean: remove build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf ./bin
	@rm -rf ./tmp
	@rm -rf ./vendor
	@go clean -cache

## build: build the application
.PHONY: build
build: env/check tidy templ/generate
	@echo "Building ${binary_name}..."
	@go build -o=./bin/${binary_name} ${main_package_path}

## build/prod: build the application for production with optimizations
.PHONY: build/prod
build/prod: env/check vendor templ/generate assets/build
	@echo "Building ${binary_name} for production..."
	@go build -ldflags="-s -w" -o=./bin/${binary_name} ${main_package_path}

## run: run the application
.PHONY: run
run: build
	./bin/${binary_name}

## run/live: run the application with reloading on file changes
.PHONY: run/live
run/live: env/check
	@air

## css/build: build CSS with Tailwind
.PHONY: css/build
css/build:
	@echo "Building CSS..."
	@npx tailwindcss -i ./web/static/css/tailwind.input.css -o ./web/static/css/styles.css --minify

## css/live: run tailwindcss to generate the styles.css bundle in watch mode
.PHONY: css/live
css/live:
	@echo "Watching CSS changes..."
	@npx tailwindcss -i ./web/static/css/tailwind.input.css -o ./web/static/css/styles.css --watch

## js/build: build JavaScript/TypeScript bundles
.PHONY: js/build
js/build:
	@echo "Building JavaScript..."
	@if [ -f ./web/static/js/index.ts ]; then \
		npx esbuild ./web/static/js/index.ts --bundle --minify --sourcemap --target=es2015 --outdir=./web/static/js/dist/; \
	else \
		echo "No TypeScript files found, skipping JS build"; \
	fi

## js/live: run esbuild in watch mode
.PHONY: js/live
js/live:
	@echo "Watching JavaScript changes..."
	@if [ -f ./web/static/js/index.ts ]; then \
		npx esbuild ./web/static/js/index.ts --bundle --sourcemap --target=es2015 --outdir=./web/static/js/dist/ --watch; \
	else \
		echo "No TypeScript files found, skipping JS watch"; \
	fi

## templ/generate: generate Go code from templ files
.PHONY: templ/generate
templ/generate:
	@echo "Generating templ files..."
	@templ generate

## templ/fmt: format templ files
.PHONY: templ/fmt
templ/fmt:
	@echo "Formatting templ files..."
	@templ fmt .

## templ/live: run templ generation in watch mode
.PHONY: templ/live
templ/live:
	@echo "Watching templ files..."
	@templ generate --watch --proxy="http://localhost:8080" --open-browser=false

## assets/build: build all static assets (CSS and JS)
.PHONY: assets/build
assets/build: css/build js/build templ/generate

## live: start all watch processes in parallel
.PHONY: live
live: env/check
	@echo "Starting live development environment..."
	make -j4 run/live css/live js/live templ/live

## deps: install project dependencies
.PHONY: deps
deps:
	@echo "==> Installing Go dependencies..."
	@go mod download
	@echo "==> Installing Node dependencies..."
	@npm install
	@echo "==> Installing development tools..."
	@go install github.com/air-verse/air@latest
	@go install golang.org/x/tools/cmd/goimports@latest
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@go install github.com/a-h/templ/cmd/templ@latest
	@echo "==> Dependencies installed successfully"

# ==================================================================================== #
# QUALITY CONTROL
# ==================================================================================== #

## audit: run quality control checks
.PHONY: audit
audit: test
	@echo "==> Running static analysis..."
	@go mod tidy -diff
	@go mod verify
	@test -z "$(shell gofmt -l .)" || (echo "Go files need formatting. Run 'make tidy'" && exit 1)
	@go vet ./...
	@golangci-lint run ./...
	@go run golang.org/x/vuln/cmd/govulncheck@latest ./...
	@echo "==> Audit successful"

## test: run all tests
.PHONY: test
test:
	@echo "==> Running unit tests..."
	@go test -v -race -buildvcs ./...

## test/cover: run all tests and display coverage
.PHONY: test/cover
test/cover:
	@echo "==> Running tests with coverage..."
	@go test -v -race -buildvcs -coverprofile=/tmp/coverage.out ./...
	@go tool cover -html=/tmp/coverage.out

## test/integration: run integration tests
.PHONY: test/integration
test/integration: env/check
	@echo "==> Running integration tests..."
	@go test -v -race -tags=integration ./test/integration/...

# ==================================================================================== #
# DOCKER
# ==================================================================================== #

## docker/build: build docker image
.PHONY: docker/build
docker/build:
	@echo "Building Docker image..."
	@docker build -t ${docker_image_name}:latest .

## docker/run: run docker container
.PHONY: docker/run
docker/run: docker/build
	@echo "Running Docker container..."
	@docker run -p 8080:8080 --env-file .env ${docker_image_name}:latest

## docker/compose: run with docker-compose
.PHONY: docker/compose
docker/compose: env/check
	@echo "Starting services with docker-compose..."
	@docker-compose up

## docker/compose/build: rebuild and run with docker-compose
.PHONY: docker/compose/build
docker/compose/build: env/check
	@echo "Rebuilding and starting services with docker-compose..."
	@docker-compose up --build

## docker/clean: remove docker containers and images
.PHONY: docker/clean
docker/clean:
	@echo "Cleaning Docker resources..."
	@docker-compose down --volumes --remove-orphans
	@docker rmi ${docker_image_name}:latest 2>/dev/null || true