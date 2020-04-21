include .env
DOCKER_EXEC = docker-compose exec fpm
DOCKER_RUN = docker-compose run -e PHP_XDEBUG_ENABLED=0 --rm fpm
DOCKER_RUN_XDEBUG = docker-compose run -e PHP_XDEBUG_ENABLED=1 --rm fpm

.PHONY: up
up:
	docker-compose pull && docker-compose up -d

xdebug-on:
	docker-compose stop fpm
	sed -i -e "s/PHP_XDEBUG_ENABLED: 0/PHP_XDEBUG_ENABLED: 1/g" docker-compose.override.yml
	docker-compose up -d fpm

xdebug-off:
	docker-compose stop fpm
	sed -i -e "s/PHP_XDEBUG_ENABLED: 1/PHP_XDEBUG_ENABLED: 0/g" docker-compose.override.yml
	docker-compose up -d fpm

.PHONY: down
down:
	docker-compose down --remove-orphans

.env.local: .env
	cp -n .env .env.local

vendor:
	rm -rf var/cache/* var/log/*
	$(DOCKER_RUN) composer install
	$(DOCKER_RUN) bin/console --env=dev cache:warmup

.PHONY: fixtures
fixtures:
	$(DOCKER_RUN) bin/console --env=dev doctrine:schema:drop --force --no-interaction
	$(DOCKER_RUN) bin/console --env=dev doctrine:schema:create -v --no-interaction
	$(DOCKER_RUN) bin/console --env=dev doctrine:fixtures:load -v --no-interaction

.PHONY: setup
setup:
	@sed -i -e "s@\`http://localhost.*\`@\`http://localhost:${APP_HTTP_PORT}\`@g" README.md
	make down
	make .env.local
	rm -rf vendor
	make up
	make vendor
	make fixtures
	@echo \\n"Setup finished!!"\\n\\n"Open http://localhost:$(APP_HTTP_PORT) in your web browser"\\n\\n

.PHONY: tests-setup
tests-setup:
	rm -rf var/cache/* var/log/*
	make vendor
	$(DOCKER_RUN) bin/console --env=test doctrine:schema:drop --no-interaction --force
	$(DOCKER_RUN) bin/console --env=test doctrine:schema:create --no-interaction
	$(DOCKER_RUN) bin/console --env=test doctrine:fixtures:load --no-interaction
	$(DOCKER_RUN) ./vendor/bin/simple-phpunit install

.PHONY: tests
tests:
	make cs-fix
	$(DOCKER_EXEC) ./vendor/bin/simple-phpunit ${path}

.PHONY: coverage
coverage:
	$(DOCKER_RUN_XDEBUG) vendor/bin/simple-phpunit --coverage-html var/coverage

cs-fix:
	$(DOCKER_RUN) ./vendor/bin/php-cs-fixer fix --diff --config=.php_cs.dist
