IMAGE=amazon/aws-app-mesh-cloudwatch-agent
REPO=$(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION).amazonaws.com/$(IMAGE)
VERSION=v0.1

.PHONY: image
image:
	docker build -t $(IMAGE):$(VERSION) .

.PHONY: push
push:
ifeq ($(AWS_ACCOUNT),)
	$(error AWS_ACCOUNT is not set)
endif
ifeq ($(AWS_REGION),)
	$(error AWS_REGION is not set)
endif
	aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
	docker tag $(IMAGE):$(VERSION) $(REPO):$(VERSION)
	docker push $(REPO):$(VERSION)
