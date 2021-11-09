PROJECT_ID=dtg-storybooks-331601
ZONE=us-central1-c

run-local:
	docker-compose up

###

create-tf-backend-bucket:
	gsutil mb -p $(PROJECT_ID) gs://$(PROJECT_ID)-terraform

###

check-env:
ifndef ENV
	$(error Please set ENV=[staging|prod])
endif

define get-secret
$(shell gcloud secrets versions access latest --secret=$(1) --project=$(PROJECT_ID))
endef

###

terraform-create-workspace: check-env
	cd terraform && \
		terraform workspace new $(ENV)

terraform-init: check-env
	cd terraform && \
		terraform workspace select $(ENV) && \
		terraform init

TF_ACTION?=plan

terraform-action: check-env
	cd terraform && \
		terraform workspace select $(ENV) && \
		terraform $(TF_ACTION) \
		-var-file="./environments/common.tfvars" \
		-var-file="./environments/$(ENV)/config.tfvars" \
		-var="atlas_dtg_owner_id=$(call get-secret,atlas_dtg_owner_id)" \
		-var="atlas_dtg_public_key=$(call get-secret,atlas_dtg_public_key)" \
		-var="atlas_dtg_private_key=$(call get-secret,atlas_dtg_private_key)" \
		-var="atlas_user_password=$(call get-secret,atlas_user_password_$(ENV))" \
		-var="cloudflare_api_token=$(call get-secret,cloudflare_api_token)"

###

SSH_STRING = vaxroute@storybooks-vm-$(ENV)

GITHUB_SHA?=latest
LOCAL_TAG=storybooks-app:$(GITHUB_SHA)
REMOTE_TAG=gcr.io/$(PROJECT_ID)/$(LOCAL_TAG)
CONTAINER_NAME=storybooks-api
DB_NAME=storybooks-$(ENV)

ssh: check-env
	gcloud compute ssh $(SSH_STRING) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE)

ssh-cmd: check-env
	@gcloud compute ssh $(SSH_STRING) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE) \
		--command="$(CMD)"

build:
	docker build -t $(LOCAL_TAG) .

push:
	docker tag $(LOCAL_TAG) $(REMOTE_TAG)
	docker push $(REMOTE_TAG)

deploy: check-env
	$(MAKE) ssh-cmd CMD='docker-credential-gcr configure-docker'
	@echo "pulling new container image..."
	$(MAKE) ssh-cmd CMD='docker pull $(REMOTE_TAG)'
	@echo "removing old container..."
	-$(MAKE) ssh-cmd CMD='docker container stop $(CONTAINER_NAME)'
	-$(MAKE) ssh-cmd CMD='docker container rm $(CONTAINER_NAME)'
	@echo "starting new container..."
	@$(MAKE) ssh-cmd CMD='\
		docker run -d --name=$(CONTAINER_NAME) \
			--restart=unless-stopped \
			-p 80:3000 \
			-e PORT=3000 \
			-e \"MONGO_URI=mongodb+srv://storybooks-user-$(ENV):$(call get-secret,atlas_user_password_$(ENV))@storybooks-$(ENV).$(call get-secret,atlas_tenant_id_$(ENV)).mongodb.net/$(DB_NAME)?retryWrites=true\" \
			-e GOOGLE_CLIENT_ID=309761888613-r8qoleoe8hkfcn8dj2hemiu0dpg59frb.apps.googleusercontent.com \
			-e GOOGLE_CLIENT_SECRET=$(call get-secret,google_oauth_client_secret) \
			$(REMOTE_TAG) \
			'