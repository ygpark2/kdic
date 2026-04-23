TAILWIND_DIR=./config/front
TAILWIND_INPUT=$(TAILWIND_DIR)/tailwind.input.css
TAILWIND_CONFIG=$(TAILWIND_DIR)/tailwind.config.js
TAILWIND_OUTPUT=./static/css/tailwind.css
FRONTEND_DIR=./frontend

.PHONY: tailwind
tailwind:
	@command -v tailwindcss >/dev/null 2>&1 || (cd $(TAILWIND_DIR) && npm install)
	npx --prefix $(TAILWIND_DIR) tailwindcss -c $(TAILWIND_CONFIG) -i $(TAILWIND_INPUT) -o $(TAILWIND_OUTPUT) --minify

.PHONY: rebuild
rebuild:
	@stack clean && stack build

.PHONY: frontend-build
frontend-build:
	@command -d $(FRONTEND_DIR)/node_modules >/dev/null 2>&1 || (cd $(FRONTEND_DIR) && npm install)
	@cd $(FRONTEND_DIR) && npm run build

.PHONY: start
start:
	@PORT=3004 APPROOT=http://localhost:3004 stack run kdic

.PHONY: dev-start
dev-start:
	# @stack exec -- yesod devel
	@$(MAKE) frontend-build
	@PORT=3004 APPROOT=http://localhost:3004 stack build --flag kdic:dev
	@PORT=3004 APPROOT=http://localhost:3004 stack exec kdic & \
		pid=$$!; \
		trap 'kill $$pid >/dev/null 2>&1 || true' INT TERM EXIT; \
		sleep 2; \
		echo ""; \
		echo "Accessible at: http://localhost:3004"; \
		wait $$pid

.PHONY: start-bg
start-bg:
	@nohup PORT=3004 APPROOT=http://localhost:3004 stack run kdic > ./kdic.log 2>&1 & echo $$! > ./kdic.pid

.PHONY: stop
stop:
	@if [ -f ./kdic.pid ]; then \
		kill $$(cat ./kdic.pid) || true; \
		rm -f ./kdic.pid; \
	else \
		echo "No kdic.pid found."; \
	fi

.PHONY: clean
clean:
	@rm ./data/*.sqlite*

.PHONY: backup
backup:
	@./scripts/backup.sh

.PHONY: restore
restore:
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "Usage: make restore BACKUP_FILE=/path/to/archive.tar.gz"; \
		exit 1; \
	fi
	@./scripts/restore.sh "$(BACKUP_FILE)"

.PHONY: restart
restart:
	$(MAKE) rebuild && $(MAKE) start
