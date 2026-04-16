.PHONY: serve stop test test-callback-handler test-tenant-frontend test-platform-frontend test-discovery

SERVICES_DIR := services

serve:
	@echo "http://localhost:8080/design"
	python3 -m http.server 8080

stop:
	@pkill --full "python3 -m http.server 8080" || true

test: test-callback-handler test-tenant-frontend test-platform-frontend test-discovery

test-callback-handler:
	@echo "==> callback-handler"
	@cd $(SERVICES_DIR)/callback-handler && .venv/bin/pytest tests/ -v

test-tenant-frontend:
	@echo "==> tenant-frontend"
	@cd $(SERVICES_DIR)/tenant-frontend && .venv/bin/pytest tests/ -v

test-platform-frontend:
	@echo "==> platform-frontend"
	@cd $(SERVICES_DIR)/platform-frontend && .venv/bin/pytest tests/ -v

test-discovery:
	@echo "==> discovery"
	@cd $(SERVICES_DIR)/discovery && .venv/bin/pytest tests/ -v
