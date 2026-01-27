.PHONY: build test clean fmt lint run

BINARY_NAME=chaos
BUILD_DIR=bin
GO_FILES=$(shell find . -name '*.go' -type f)

# Build flags
LDFLAGS=-ldflags "-s -w"

build: $(BUILD_DIR)/$(BINARY_NAME)

$(BUILD_DIR)/$(BINARY_NAME): $(GO_FILES)
	@mkdir -p $(BUILD_DIR)
	go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/chaos

test:
	go test -v ./...

test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

clean:
	rm -rf $(BUILD_DIR)
	rm -f coverage.out coverage.html

fmt:
	go fmt ./...

lint:
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not installed, skipping"; \
	fi

deps:
	go mod download
	go mod tidy

# Install to GOPATH/bin
install: build
	cp $(BUILD_DIR)/$(BINARY_NAME) $(GOPATH)/bin/

# Run with arguments
run: build
	./$(BUILD_DIR)/$(BINARY_NAME) $(ARGS)
