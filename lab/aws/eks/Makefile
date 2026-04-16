.PHONY: serve stop

serve:
	@echo "http://localhost:8080/design"
	python3 -m http.server 8080

stop:
	@pkill --full "python3 -m http.server 8080" || true
