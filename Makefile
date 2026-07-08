WORKER_IMAGE := usabilitydynamics/udx-worker:latest

.PHONY: test test-real test-docker test-docker-pull test-shell

# Run tests locally
test:
	bash tests/suite.sh

# Run optional local integration checks against real repos
test-real:
	bash tests/real-repos.sh

# Run tests inside the worker container without the deprecated worker-deployment manifest.
test-docker:
	docker run --rm -v "$(CURDIR):/workspace" -w /workspace $(WORKER_IMAGE) bash tests/suite.sh

# Interactive shell inside the worker container for debugging
test-shell:
	docker run --rm -it -v "$(CURDIR):/workspace" -w /workspace $(WORKER_IMAGE) bash

# Pull the worker image explicitly
test-docker-pull:
	docker pull $(WORKER_IMAGE)
