BINARY_NAME := termtosvg
CMD_DIR     := ./cmd/termtosvg
BUILD_DIR   := bin
GO          := go

VERSION     ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT      ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE        ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LDFLAGS     := -s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(DATE)

.PHONY: all build run test clean examples lint fmt help

all: build

## build: Compile the CLI application binary
build:
	@echo "==> Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(GO) build -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME) $(CMD_DIR)
	@cp $(BUILD_DIR)/$(BINARY_NAME) ./$(BINARY_NAME)
	@echo "==> Built ./$(BINARY_NAME)"

## run: Run the application CLI
run: build
	@./$(BINARY_NAME) $(ARGS)

## test: Run all tests
test:
	@echo "==> Running tests..."
	$(GO) test -v -race ./...

## fmt: Format all Go source files
fmt:
	@echo "==> Formatting code..."
	$(GO) fmt ./...

## lint: Run code formatting checks and go vet
lint:
	@echo "==> Running code standards and lint..."
	@unformatted=$$($(GO) fmt ./...); if [ -n "$$unformatted" ]; then echo "Unformatted files:"; echo "$$unformatted"; exit 1; fi
	$(GO) vet ./...

## tidy: Tidy and verify go.mod
tidy:
	@echo "==> Tidying module dependencies..."
	$(GO) mod tidy

## pre-commit: Run pre-commit hooks on all files
pre-commit:
	@echo "==> Running pre-commit hooks..."
	@command -v pre-commit >/dev/null && pre-commit run --all-files || echo "pre-commit not installed locally (brew install pre-commit)"

## clean: Remove build artifacts and temporary files
clean:
	@echo "==> Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) $(BINARY_NAME)
	@echo "==> Cleaned."

## examples: Regenerate all example SVG graphics
examples: build
	@echo "==> Regenerating all feature example SVGs..."
	@mkdir -p examples
	@printf "\033[1;36m➜  git status\033[0m\nOn branch \033[1;32mmain\033[0m\nYour branch is up to date.\n\nChanges to be committed:\n\t\033[32mmodified:   termtosvg.go\033[0m\n\nUntracked files:\n\t\033[31mexamples/\033[0m\n" | ./$(BINARY_NAME) -o examples/01-autocrop.svg -title "git status — compact view" -auto-crop -cursor
	@printf "\033[38;5;242m2026-10-10 22:30:00\033[0m \033[1;32mINFO\033[0m  HTTP GET /api/v2/metrics \033[34mstatus\033[0m=200 \033[34mduration\033[0m=4.2ms\n\033[38;5;242m2026-10-10 22:30:01\033[0m \033[1;32mINFO\033[0m  gRPC ListEndpoints \033[34mcount\033[0m=48 \033[34mhealthy\033[0m=48\n\033[38;5;242m2026-10-10 22:30:03\033[0m \033[1;33mWARN\033[0m  Cache evictions high \033[34mrate\033[0m=420/s \033[34mthreshold\033[0m=350/s\n" | ./$(BINARY_NAME) -o examples/02-theme-light.svg -theme light -title "Telemetry Collector" -header "Observability Daemon" -badge "STATE: HEALTHY" -auto-crop
	@printf "\033[1;35m╭── kubectl get pods -n observability ──────────────────────────────────────╮\033[0m\n│  \033[1mNAME                             READY   STATUS    RESTARTS   AGE        │\033[0m\n│  \033[32motel-collector-7b94d9-a41        1/1     Running   0          42d\033[0m        │\n│  \033[32mloki-distributor-89c5-f90        1/1     Running   0          18d\033[0m        │\n│  \033[32mprometheus-k8s-0                 2/2     Running   1 (14d)    60d\033[0m        │\n│  \033[33mtempo-ingester-5f96b-k82         1/1     Running   3 (1h)     4d\033[0m         │\n\033[1;35m╰───────────────────────────────────────────────────────────────────────────╯\033[0m\n" | ./$(BINARY_NAME) -o examples/03-theme-catppuccin.svg -theme catppuccin -title "Kubernetes Cluster" -tabs "Workloads,Pods,Ingresses,ConfigMaps" -active-tab 1 -auto-crop
	@printf "\033[1;36m┌── Core Infrastructure Health Matrix ──────────────────────────────────────┐\033[0m\n│  Service         Region       Status       P99 Latency    Error Budget     │\n│  \033[1mAuth-V2\033[0m         eu-west-1    \033[1;32mONLINE\033[0m       14.2ms         \033[32m99.98%%\033[0m          │\n│  \033[1mPayment-GW\033[0m      eu-west-1    \033[1;32mONLINE\033[0m       48.1ms         \033[32m99.95%%\033[0m          │\n│  \033[1mCatalog-DB\033[0m      eu-west-1    \033[1;33mDEGRADED\033[0m     120.4ms        \033[33m99.40%%\033[0m          │\n\033[1;36m└───────────────────────────────────────────────────────────────────────────┘\033[0m\n" | ./$(BINARY_NAME) -o examples/04-theme-nord.svg -theme nord -title "SRE Production Dashboard" -tabs "Global Matrix,EU Region,US Region" -active-tab 1 -header "SLO / Error Budget Burn Rate" -badge "SRE ON-CALL: ACTIVE" -auto-crop
	@printf "\033[1;34m$$ curl -i https://status.internal/healthz\033[0m\n\033[1mHTTP/2 200 OK\033[0m\n{\n  \033[32m\"status\"\033[0m: \033[32m\"healthy\"\033[0m,\n  \033[32m\"cluster\"\033[0m: \033[32m\"prod-k8s-eu\"\033[0m\n}\n" | ./$(BINARY_NAME) -o examples/05-theme-frameless.svg -theme frameless -auto-crop
	@printf "\033[1;35m==> Incident Mitigation Workflow\033[0m\n  \033[32m✔\033[0m \033[1mStep 1:\033[0m Detect canary failure       [\033[32mCOMPLETED\033[0m]\n  \033[32m✔\033[0m \033[1mStep 2:\033[0m Route traffic to replica 02 [\033[32mCOMPLETED\033[0m]\n  \033[33m➜\033[0m \033[1mStep 3:\033[0m Flush stale Redis cache     [\033[33mIN PROGRESS\033[0m]\n" | ./$(BINARY_NAME) -o examples/06-cursor.svg -title "Runbook Execution Engine" -header "Automated Remediation — INC-8491" -badge "STAGE: 3 OF 4" -auto-crop -cursor
	@printf "\033[1;36m➜  curl -H \"Authorization: Bearer secret_live_token_991823123\" https://192.168.1.55/api/login\033[0m\n\033[32mHTTP/2 200 OK\033[0m\n\033[34mclient_ip:\033[0m 10.240.12.9\n\033[34mauth_token:\033[0m sample_redacted_auth_token_value_xyz\n" | ./$(BINARY_NAME) -o examples/07-redaction.svg -title "Security Redaction Demo" -header "Sanitized Audit Log" -badge "SANITIZED: TRUE" -mask-secrets -auto-crop
	@printf "  \033[44;37m[1] Auth Service     CPU: 12%%  MEM:  420MB  STATUS: RUNNING  \033[0m\n  \033[42;30m[2] Payment Gateway  CPU: 45%%  MEM: 1240MB  STATUS: RUNNING  \033[0m\n  \033[41;37m[3] Cache Replica 03 CPU: 98%%  MEM: 3800MB  STATUS: CRITICAL \033[0m\n" | ./$(BINARY_NAME) -o examples/09-background-fills.svg -title "TUI Dashboard (Background Fills)" -header "Service Monitor — Cluster Nodes" -badge "NODES: 3" -auto-crop
	@echo "==> All example SVGs generated in ./examples/"

## open: Open all example SVGs in Google Chrome
open:
	@echo "==> Opening example SVGs in Chrome..."
	@open -a "Google Chrome" examples/*.svg

## help: Display this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/ /'
