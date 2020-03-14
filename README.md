# aws-app-mesh-cloudwatch-agent
AWS Cloud Watch Agent optimized for App Mesh usage.

This is a custom Cloud Watch agent built using the steps under https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights-build-docker-image.html to support using in App Mesh context. Cloud Watch agent is installed as a sidecar to application, for e.g. ECS Task, Kubernetes Pod, daemon on EC2 instance. 

In App Mesh, all traffic is intercepted by Envoy unless the sidecar process is running using a specific UID (default=1337). Containers running using non-root user cannot create files unless the image is built with that user created and appropriate permissions. This project provides a Dockerfile that can be used to build a Cloud Watch agent Docker image that runs as non-root user.

# Build Docker Image
1. Clone this repository.
2. Set following environment variables
    ```
    $ export AWS_ACCOUNT=...
    $ export AWS_REGION=...
    ```
2. Build image
	```
	$ make image
	```
3. Push image
    ```
    $ aws ecr create-repository --repository-name amazon/aws-app-mesh-cloudwatch-agent
    $ make push
    ```

# Usage
## ECS
Update your task-definition to include cloudwatch-agent as sidecar that exposes statsd endpoint. With App Mesh Envoy configured with environment variable `ENABLE_ENVOY_DOG_STATSD: 1`, Envoy will publish stats to Cloud Watch under namespace `CW_NAMESPACE` via cloudwatch-agent sidecar.

Alternately you can inject `CW_CONFIG_CONTENT` using SSM parameter as explained [here](https://github.com/aws-samples/amazon-cloudwatch-container-insights/tree/master/ecs-task-definition-templates/deployment-mode/sidecar/cwagent-statsd).

```yaml
- Name: 'cwagent'
  Image: <image generated above>
  Essential: true
  User: '1337'
  Environment:
    - Name: CW_CONFIG_CONTENT
      Value:
        Fn::Sub: "{ \"metrics\": { \"namespace\":\"${CW_NAMESPACE}\", \"metrics_collected\": { \"statsd\": {}}}}"
- Name: envoy
  Image: !Ref EnvoyImage
  Essential: true
  User: '1337'
  HealthCheck:
    Command:
      - 'CMD-SHELL'
      - 'curl -s http://localhost:9901/server_info | grep state | grep -q LIVE'
    Interval: 5
    Timeout: 10
    Retries: 10
  Environment:
    - Name: 'ENABLE_ENVOY_STATS_TAGS'
      Value: '1'
    - Name: 'ENABLE_ENVOY_DOG_STATSD'
      Value: '1'
    - Name: 'APPMESH_VIRTUAL_NODE_NAME'
      Value:
        Fn::Join:
          - ''
          -
            - 'mesh/'
            - <mesh-name>
            - '/virtualNode/'
            - <virtual-node-name>
```

## Kubernetes
Update your pod-spec to include cloudwatch-agent as sidecar that exposes statsd endpoint.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app # the name of the deployment
spec:
  replicas: 1 # tells deployment to run 1 pods matching the template
  selector:
    matchLabels:
      name: demo-app
  template: # create pods using pod definition in this template
    metadata:
      labels:
        name: demo-app
    spec:
      containers:
        - name: demo-app
          ...
        - name: cloudwatch-agent
          image: <image generated above>
          resources:
            limits:
              cpu:  100m
              memory: 100Mi
            requests:
              cpu: 32m
              memory: 24Mi
          volumeMounts:
            - name: cwagentconfig
              mountPath: /etc/cwagentconfig
      volumes:
        - name: cwagentconfig
          configMap:
            name: cwagentconfig-sidecar
---
# create configmap for cwagent sidecar config
apiVersion: v1
data:
  # Configuration is in Json format. No matter what configure change you make,
  # please keep the Json blob valid.
  cwagentconfig.json: |
    {
      "agent": {
        "omit_hostname": true
      },
      "metrics": {
        "namespace": <cloudwatch namespace>,
        "metrics_collected": {
          "statsd": {}
        }
      }
    }
kind: ConfigMap
metadata:
  name: cwagentconfig-sidecar
```

For more information see [here](https://github.com/aws-samples/amazon-cloudwatch-container-insights/tree/master/k8s-deployment-manifest-templates/deployment-mode/sidecar/cwagent-statsd).

## Security disclosures

If you think you’ve found a potential security issue, please do not post it in the Issues.  Instead, please follow the instructions [here](https://aws.amazon.com/security/vulnerability-reporting/) or [email AWS security directly](mailto:aws-security@amazon.com).

## Contributing

Contributions welcome!  Please read our [guidelines](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

## License

This library is licensed under the MIT-0 License. See the LICENSE file.


