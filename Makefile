.ONESHELL:
ENV_PREFIX=$(shell python3 -c "if __import__('pathlib').Path('.venv/bin/pip').exists(): print('.venv/bin/')")
USING_POETRY=$(shell grep "tool.poetry" pyproject.toml && echo "yes")

.PHONY: help
help:             ## Show the help.
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@fgrep "##" Makefile | fgrep -v fgrep


.PHONY: show
show:             ## Show the current environment.
	@echo "Current environment:"
	@if [ "$(USING_POETRY)" ]; then poetry env info && exit; fi
	@echo "Running using $(ENV_PREFIX)"
	@$(ENV_PREFIX)python -V
	@$(ENV_PREFIX)python -m site

.PHONY: install
install:          ## Install the project in dev mode.
	@if [ "$(USING_POETRY)" ]; then poetry install && exit; fi
	@echo "Don't forget to run 'make virtualenv' if you got errors."
	$(ENV_PREFIX)pip install -e .[test]

.PHONY: fmt
fmt:              ## Format code using black & isort.
	$(ENV_PREFIX)isort project_name/
	$(ENV_PREFIX)black -l 79 project_name/
	$(ENV_PREFIX)black -l 79 tests/

.PHONY: lint
lint:             ## Run pep8, black, mypy linters.
	$(ENV_PREFIX)flake8 project_name/
	$(ENV_PREFIX)black -l 79 --check project_name/
	$(ENV_PREFIX)black -l 79 --check tests/
	$(ENV_PREFIX)mypy --ignore-missing-imports project_name/

.PHONY: test
test: lint        ## Run tests and generate coverage report.
	$(ENV_PREFIX)pytest -v --cov-config .coveragerc --cov=project_name -l --tb=short --maxfail=1 tests/
	$(ENV_PREFIX)coverage xml
	$(ENV_PREFIX)coverage html

.PHONY: watch
watch:            ## Run tests on every change.
	ls **/**.py | entr $(ENV_PREFIX)pytest -s -vvv -l --tb=long --maxfail=1 tests/

.PHONY: clean
clean:            ## Clean unused files.
	-find ./ -name '*.pyc' -exec rm -f {} \;
	-find ./ -name '__pycache__' -exec rm -rf {} \;
	-find ./ -name 'Thumbs.db' -exec rm -f {} \;
	-find ./ -name '*~' -exec rm -f {} \;
	-rm -rf .cache
	-rm -rf .pytest_cache
	-rm -rf .mypy_cache
	-rm -rf build
	-rm -rf dist
	-rm -rf *.egg-info
	-rm -rf htmlcov
	-rm -rf .tox/
	-rm -rf docs/_build

.PHONY: virtualenv
virtualenv:       ## Create a virtual environment.
	@if [ "$(USING_POETRY)" ]; then poetry install && exit; fi
	@echo "creating virtualenv ..."
	@rm -rf .venv
	@python3 -m venv .venv
	@./.venv/bin/pip install -U pip
	@./.venv/bin/pip install -e .[test]
	@echo
	@echo "!!! Please run 'source .venv/bin/activate' to enable the environment !!!"

.PHONY: release
release:          ## Create a new tag for release.	
	@$(ENV_PREFIX)gitchangelog > HISTORY.md
	@TAG=v$(shell cat project_name/VERSION);\
	sed -i "s=unreleased=$${TAG}=g" HISTORY.md||True;\
	git add project_name/VERSION HISTORY.md;\
	git commit -m "release: version $${TAG} 🚀";\
	echo "creating git tag : $${TAG}";\
	git tag $${TAG}; 
	@git push -u origin HEAD --tags
	@echo "Github Actions will detect the new tag and release the new version."

.PHONY: docs
docs:             ## Build the documentation.
	@echo "building documentation ..."
	@$(ENV_PREFIX)mkdocs build
	URL="site/index.html"; xdg-open $$URL || sensible-browser $$URL || x-www-browser $$URL || gnome-open $$URL

.PHONY: switch-to-poetry
switch-to-poetry: ## Switch to poetry package manager.
	@echo "Switching to poetry ..."
	@if ! poetry --version > /dev/null; then echo 'poetry is required, install from https://python-poetry.org/'; exit 1; fi
	@rm -rf .venv
	@poetry init --no-interaction --name=a_flask_test --author=rochacbruno
	@echo "" >> pyproject.toml
	@echo "[tool.poetry.scripts]" >> pyproject.toml
	@echo "project_name = 'project_name.__main__:main'" >> pyproject.toml
	@cat requirements.txt | while read in; do poetry add --no-interaction "$${in}"; done
	@cat requirements-test.txt | while read in; do poetry add --no-interaction "$${in}" --dev; done
	@poetry install --no-interaction
	@mkdir -p .github/backup
	@mv requirements* .github/backup
	@mv setup.py .github/backup
	@echo "You have switched to https://python-poetry.org/ package manager."
	@echo "Please run 'poetry shell' or 'poetry run project_name'"

.PHONY: init
init:             ## Initialize the project based on an application template.
	@./.github/init.sh

.PHONY: testdist
testdist:
	python setup.py sdist bdist_wheel
	twine upload --repository-url https://test.pypi.org/legacy/ dist/*

.PHONY: sdist
sdist:
	twine upload dist/*

# Make container image by podman
#You would need podman for this
.PHONY: image systest looptest
image:
	https_prox=http://192.168.2.15:3128 podman build -f Containerfile . -t default-route-openshift-image-registry.apps.ocp1.galaxy.io/classic-dev/project_name:latest
	podman push default-route-openshift-image-registry.apps.ocp1.galaxy.io/classic-dev/project_name:latest --tls-verify=false

systest:
	rm -rf .systestpass
	@oc apply -f .openshift/dev/cm.yaml
	-oc delete job systest-project_name -n classic-dev
	@oc apply -f .openshift/dev/systest-job-project_name-deployment.yaml
	# Wait 5 seconds
	@sleep  5
	@for i in 1 2 3 4 ; do \
		sleep 3;\
		rc=`oc get job systest-project_name --template '{{.status.succeeded}}'`;\
		echo -e ".$${rc}" ;\
		test "$${rc}" == 1 && echo "pass" && touch .systestpass; \
		if [ -a .systestpass ];then \
			break;\
		fi \
	done
	@if [[ ! -a .systestpass ]];then \
		echo "Failed" && exit 1;\
	fi


.PHONY: deploy-dev tag-dev deploy-prod
tag-dev:
	@oc apply -f .openshift/dev/cm.yaml
	@git checkout project_name/VERSION
	@sleep 1
	@PRE_TAG=$(shell cat project_name/VERSION);\
	read -p "Version? (provide the next x.y.z version,Previous tag, $${PRE_TAG}) : " TAG ;\
	echo "$${TAG}" > project_name/VERSION;\
	oc tag classic-dev/project_name:latest classic-dev/project_name:$${TAG};\
	oc set image cronjob/project_name project_name=image-registry.openshift-image-registry.svc:5000/classic-dev/project_name:$${TAG} -n classic-dev;\
	echo "Release $${TAG} has been deployed successfullyto stage environment!"

stagedeploy: test image systest tag-dev release

proddeploy:
	@TAG=$(shell cat project_name/VERSION);\
	oc tag classic-dev/project_name:$${TAG} quant-invest/project_name:$${TAG};\
	oc set image cronjob/project_name project_name=image-registry.openshift-image-registry.svc:5000/quant-invest/project_name:$${TAG} -n quant-invest;\
	echo "Release $${TAG} has been deployed successfullyto production🚀!"
	

# This project has been generated from ryanzhang/python-project-template which is forked from 
# rochacbruno/python-project-template
# __author__ = 'rochacbruno'
# __repo__ = https://github.com/rochacbruno/python-project-template
# __sponsor__ = https://github.com/sponsors/rochacbruno/
