# Change these variables as necessary
main_package_path = ./cmd/server/
binary_name = server

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
# DEVELOPMENT
# ==================================================================================== #

## tidy: tidy modfiles and format .go files
.PHONY: tidy
tidy:
	go mod tidy -v
	go fmt ./...

## build: build the application
.PHONY: build
build: tidy
	go build -o=./bin/${binary_name} ${main_package_path}

## run: run the application
.PHONY: run
run: build
	./bin/${binary_name}

## run/live: run the application with reloading on file changes
.PHONY: run/live
run/live:
	go run github.com/cosmtrek/air@v1.43.0 \
		--build.cmd "make build" --build.bin "./bin/${binary_name}" --build.delay "100" \
		--build.exclude_dir "" \
		--build.include_ext "go, tpl, tmpl, html, css, scss, js, ts, sql, jpeg, jpg, git, png, bmp, wbp, ico" \
		--misc.clean_on_exit "true"

## templ/generate: generate go code from the templ file
.PHONY: templ/generate
templ/generate:
	@templ generate

## templ/live: automatically re-generate Go code from templ on changes
.PHONY: templ/live
templ/live:
	@templ generate --watch --proxy="http://localhost:8080" --open-browser=false -v

## css/live: run tailwindcss to generate the styles.css bundle in watch mode
.PHONY: css/live
css/live:
	@npx --yes tailwindcss -i ./input.css -o ./assets/styles.css --minify --watch

## esbuild/live: run esbuild to generate the index.js bundle in watch mode.
.PHONY: esbuild/live
esbuild/live:
	@npx --yes esbuild js/index.ts --bundle --outdir=assets/ --watch

# live/sync_assets: watch for any js or css change in the assets/ folder, then reload the browser via templ proxy.
.PHONY: live/sync_assets
live/sync_assets:
	go run github.com/air-verse/air@v1.51.0 \
	--build.cmd "templ generate --notify-proxy" \
	--build.bin "true" \
	--build.delay "100" \
	--build.exclude_dir "" \
	--build.include_dir "assets" \
	--build.include_ext "js,css"

## live: start all 5 watch processes in parallel.
.PHONY: live
live:
	make -j5 templ/live run/live css/live esbuild/live live/sync_assets

## deps: download project dependencies
.PHONY: deps
deps:
	@echo "==> Downloading project dependencies..."
	@go install github.com/air-verse/air@latest # live reload
	@go install github.com/a-h/templ/cmd/templ@latest #templ templating
	@npm install -D tailwindcss
	@npm install -D @tailwindcss/forms
	@npm install -D @tailwindcss/typography
	@go install golang.org/x/tools/cmd/goimports@latest
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# ==================================================================================== #
# QUALITY CONTROL
# ==================================================================================== #

## audit: run quality control checks (static, vulnerabilities, etc)
.PHONY: audit
audit: test
	@echo "==> Running static analysis..."
	@go mod tidy -diff
	@go mod verify
	@test -z "$(shell gofmt -l .)" 
	@go vet ./...
	@go run honnef.co/go/tools/cmd/staticcheck@master -checks=all,-ST1000,-U1000 ./...
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
	go test -v -race -buildvcs -coverprofile=/tmp/coverage.out ./...
	go tool cover -html=/tmp/coverage.out


