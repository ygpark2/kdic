TAILWIND_DIR=./config/front
TAILWIND_INPUT=$(TAILWIND_DIR)/tailwind.input.css
TAILWIND_CONFIG=$(TAILWIND_DIR)/tailwind.config.js
TAILWIND_OUTPUT=./static/css/tailwind.css

.PHONY: tailwind
tailwind:
	@command -v tailwindcss >/dev/null 2>&1 || (cd $(TAILWIND_DIR) && npm install)
	npx --prefix $(TAILWIND_DIR) tailwindcss -c $(TAILWIND_CONFIG) -i $(TAILWIND_INPUT) -o $(TAILWIND_OUTPUT) --minify

.PHONY: rebuild
rebuild:
	@stack clean && stack build

.PHONY: start
start:
	@PORT=3004 APPROOT=http://localhost:3004 stack run kdic

.PHONY: dev-start
dev-start:
	# @stack exec -- yesod devel
	@PORT=3004 APPROOT=http://localhost:3004 stack build --flag kdic:dev && PORT=3004 APPROOT=http://localhost:3004 stack exec kdic

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

.PHONY: restart
restart:
	$(MAKE) rebuild && $(MAKE) start
