# Clementime Makefile
# Quick commands for development, deployment, and Docker operations

.PHONY: help
.DEFAULT_GOAL := help

# Variables
DOCKER_USER ?= yourusername
IMAGE_NAME ?= clementime
TAG ?= latest
FULL_IMAGE = $(DOCKER_USER)/$(IMAGE_NAME):$(TAG)

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

##@ Help

help: ## Display this help message
	@echo "$(BLUE)Clementime - Available Commands$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

##@ Development

dev: ## Start development environment with Docker Compose
	@echo "$(BLUE)Starting development environment...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)Development environment started!$(NC)"
	@echo "API: http://localhost:3000"
	@echo "Client: http://localhost:5173"

dev-logs: ## View logs from development containers
	docker-compose logs -f

dev-stop: ## Stop development environment
	@echo "$(YELLOW)Stopping development environment...$(NC)"
	docker-compose down

dev-clean: ## Stop and remove all development containers and volumes
	@echo "$(RED)Cleaning development environment...$(NC)"
	docker-compose down -v
	@echo "$(GREEN)Cleanup complete!$(NC)"

dev-restart: dev-stop dev ## Restart development environment

setup: ## Initial setup (install dependencies)
	@echo "$(BLUE)Installing backend dependencies...$(NC)"
	bundle install
	@echo "$(BLUE)Installing frontend dependencies...$(NC)"
	cd client && yarn install
	@echo "$(GREEN)Setup complete!$(NC)"

db-setup: ## Setup database (create, migrate, seed)
	@echo "$(BLUE)Setting up database...$(NC)"
	docker-compose exec app rails db:create db:migrate db:seed
	@echo "$(GREEN)Database ready!$(NC)"

db-migrate: ## Run database migrations
	docker-compose exec app rails db:migrate

db-seed: ## Seed database
	docker-compose exec app rails db:seed

db-reset: ## Reset database (WARNING: destroys all data)
	@echo "$(RED)Resetting database... (this will destroy all data)$(NC)"
	docker-compose exec app rails db:reset

console: ## Open Rails console
	docker-compose exec app rails console

shell: ## Open shell in app container
	docker-compose exec app /bin/bash

##@ Docker Build & Push

build: ## Build Docker image for production
	@echo "$(BLUE)Building Docker image: $(FULL_IMAGE)$(NC)"
	docker build -t $(FULL_IMAGE) .
	@echo "$(GREEN)Build complete!$(NC)"

build-no-cache: ## Build Docker image without cache
	@echo "$(BLUE)Building Docker image (no cache): $(FULL_IMAGE)$(NC)"
	docker build --no-cache -t $(FULL_IMAGE) .
	@echo "$(GREEN)Build complete!$(NC)"

tag-latest: ## Tag current build as latest
	@echo "$(BLUE)Tagging as latest...$(NC)"
	docker tag $(FULL_IMAGE) $(DOCKER_USER)/$(IMAGE_NAME):latest

push: ## Push Docker image to Docker Hub
	@echo "$(BLUE)Pushing to Docker Hub: $(FULL_IMAGE)$(NC)"
	docker push $(FULL_IMAGE)
	@echo "$(GREEN)Push complete!$(NC)"

push-latest: tag-latest ## Tag and push latest
	@echo "$(BLUE)Pushing latest to Docker Hub...$(NC)"
	docker push $(DOCKER_USER)/$(IMAGE_NAME):latest
	@echo "$(GREEN)Push complete!$(NC)"

docker-all: build push ## Build and push Docker image

docker-login: ## Login to Docker Hub
	@echo "$(BLUE)Logging into Docker Hub...$(NC)"
	docker login

##@ Git Operations

git-status: ## Show git status
	@git status

git-add: ## Stage all changes
	@echo "$(BLUE)Staging all changes...$(NC)"
	git add .
	@git status

git-commit: ## Commit with message (use MSG="your message")
	@if [ -z "$(MSG)" ]; then \
		echo "$(RED)Error: Please provide a commit message using MSG=\"your message\"$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Committing changes...$(NC)"
	git commit -m "$(MSG)"

git-push: ## Push to remote repository
	@echo "$(BLUE)Pushing to GitHub...$(NC)"
	git push origin $$(git branch --show-current)
	@echo "$(GREEN)Pushed successfully!$(NC)"

git-pull: ## Pull from remote repository
	@echo "$(BLUE)Pulling from GitHub...$(NC)"
	git pull origin $$(git branch --show-current)

deploy-commit: git-add ## Stage, commit, and push (use MSG="your message")
	@if [ -z "$(MSG)" ]; then \
		echo "$(RED)Error: Please provide a commit message using MSG=\"your message\"$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Committing and pushing...$(NC)"
	git commit -m "$(MSG)"
	git push origin $$(git branch --show-current)
	@echo "$(GREEN)Deployed to GitHub!$(NC)"

##@ Production Deployment

deploy-render: git-push ## Deploy to Render.com (pushes to GitHub)
	@echo "$(GREEN)Pushed to GitHub! Render will auto-deploy.$(NC)"
	@echo "Check deployment status at: https://dashboard.render.com"

deploy-docker: docker-all ## Build and push Docker image for production
	@echo "$(GREEN)Docker image deployed to Docker Hub!$(NC)"
	@echo "Pull and run with: docker pull $(FULL_IMAGE)"

deploy-full: deploy-commit deploy-render deploy-docker ## Full deployment (commit, push, and Docker)
	@echo "$(GREEN)Full deployment complete!$(NC)"

##@ Testing & Quality

test: ## Run test suite
	docker-compose exec app rails test

lint: ## Run linter
	docker-compose exec app bundle exec rubocop

lint-fix: ## Auto-fix linting issues
	docker-compose exec app bundle exec rubocop -a

##@ Utilities

clean: ## Clean temporary files and caches
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	rm -rf tmp/cache/*
	rm -rf log/*.log
	rm -rf client/dist
	rm -rf client/node_modules/.cache
	@echo "$(GREEN)Cleanup complete!$(NC)"

logs: ## View application logs
	docker-compose exec app tail -f log/development.log

secret: ## Generate a new Rails secret key
	@docker-compose exec app rails secret

env-example: ## Create .env from .env.example
	@if [ ! -f .env ]; then \
		echo "$(BLUE)Creating .env from .env.example...$(NC)"; \
		cp .env.example .env; \
		echo "$(GREEN).env file created! Please edit with your values.$(NC)"; \
	else \
		echo "$(YELLOW).env already exists. Not overwriting.$(NC)"; \
	fi

##@ Information

version: ## Show version information
	@echo "$(BLUE)Clementime Version Information$(NC)"
	@echo "Ruby: $$(docker-compose exec app ruby -v 2>/dev/null || echo 'Not running')"
	@echo "Rails: $$(docker-compose exec app rails -v 2>/dev/null || echo 'Not running')"
	@echo "Node: $$(docker-compose exec app node -v 2>/dev/null || echo 'Not running')"
	@echo "Docker Image: $(FULL_IMAGE)"

status: ## Show running containers
	@docker-compose ps

docker-info: ## Show Docker image information
	@echo "$(BLUE)Docker Image: $(FULL_IMAGE)$(NC)"
	@docker images | grep $(IMAGE_NAME) || echo "No local images found"

##@ Multi-Instance Management

new-instance: ## Create new instance from template (use NAME=coursename)
	@if [ -z "$(NAME)" ]; then \
		echo "$(RED)Error: Please provide instance name using NAME=coursename$(NC)"; \
		echo "Example: make new-instance NAME=psych10"; \
		exit 1; \
	fi
	@echo "$(BLUE)Creating new instance: $(NAME)$(NC)"
	@echo "1. Go to: https://github.com/$(DOCKER_USER)/clementime"
	@echo "2. Click 'Use this template' → 'Create a new repository'"
	@echo "3. Name it: clementime-$(NAME)"
	@echo "4. Clone and setup:"
	@echo "   git clone https://github.com/$(DOCKER_USER)/clementime-$(NAME).git"
	@echo "   cd clementime-$(NAME)"
	@echo "5. Deploy via Render Blueprint"
	@echo "6. Add custom domain: $(NAME).clementime.app"

sync-instance: ## Sync instance with main repo (run in instance repo)
	@echo "$(BLUE)Syncing with main repository...$(NC)"
	@if ! git remote | grep -q upstream; then \
		echo "$(YELLOW)Adding upstream remote...$(NC)"; \
		git remote add upstream https://github.com/$(DOCKER_USER)/clementime.git; \
	fi
	git fetch upstream
	@echo "$(YELLOW)Merging updates from main...$(NC)"
	git merge upstream/main --allow-unrelated-histories
	@echo "$(GREEN)Sync complete! Review changes and push.$(NC)"

push-instance: ## Push instance changes
	@echo "$(BLUE)Pushing instance updates...$(NC)"
	git push origin main
	@echo "$(GREEN)Instance updated! Check Render for deployment.$(NC)"

list-remotes: ## Show configured git remotes
	@echo "$(BLUE)Configured remotes:$(NC)"
	@git remote -v

##@ Quick Commands

quick-dev: dev db-setup ## Quick start development (start + setup DB)
	@echo "$(GREEN)Development environment ready!$(NC)"
	@echo "Visit: http://localhost:5173"

quick-deploy: ## Quick deployment (use MSG="your message")
	@if [ -z "$(MSG)" ]; then \
		echo "$(RED)Error: Please provide a commit message using MSG=\"your message\"$(NC)"; \
		exit 1; \
	fi
	@make deploy-commit MSG="$(MSG)"
	@echo "$(GREEN)Quick deployment complete!$(NC)"

quick-build-push: build push ## Quick Docker build and push
	@echo "$(GREEN)Docker image built and pushed!$(NC)"

quick-instance-sync: sync-instance push-instance ## Sync and push instance updates
	@echo "$(GREEN)Instance synced and deployed!$(NC)"
