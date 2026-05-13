WORKER_IMAGE := usabilitydynamics/udx-worker:latest

.PHONY: test test-real test-docker test-docker-pull test-shell

# Run tests locally
test:
	bash tests/suite.sh

# Run optional local integration checks against real repos
test-real:
	bash tests/real-repos.sh

# Run tests inside the worker container via deploy.yml
# Requires @udx/worker-deployment: npm install -g @udx/worker-deployment
test-docker:
	worker run

# Interactive shell inside the worker container for debugging
test-shell:
	worker run run-it

# Pull the worker image explicitly
test-docker-pull:
	docker pull $(WORKER_IMAGE)