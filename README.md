# Debezium Helm Chart for OpenShift & Kubernetes

## Overview
This Helm chart enables the deployment of **Debezium connectors** in **OpenShift** and **Kubernetes** environments. It supports **SCRAM-SHA-256 authentication** and **SASL_PLAINTEXT** communication with Kafka.

## Features

### 🔹 Automated Kafka Topic Creation
- An init container creates necessary topics (5 system topics and 1 per table) before the main container starts.
- If the topics exist, no changes are made.
- The init container does not modify existing topic configurations.

### 🔹 Prometheus JMX Exporter Integration
- A dedicated init container downloads the JMX Exporter JAR file for Prometheus monitoring.

### 🔹 Automatic Connector Configuration Updates
- On startup, the main container sends a `PUT` request to Debezium to ensure the latest configuration is applied.

## Limitations

### ⚠️ Single Connector per Deployment
- Each Helm release manages **one** connector per deployment.
- Each connector is tied to a **single database** but can process multiple tables.
- This setup allows for fine-grained scaling and maintenance without affecting other connectors.

### ⚠️ Liveness Probe Considerations
- If the connector stalls, JMX metrics stop responding, but the liveness probe may not detect it.
- It is recommended to integrate a monitoring system for real-time alerts.

## Deployment on OpenShift & Kubernetes

### ✅ Prerequisites
- Kafka with **SCRAM-SHA-256 authentication** enabled.
- Internal Docker registry (if running in an **air-gapped** environment).
- Helm CLI installed.

### 🚀 Installation Steps
Modify `values.yaml` with your specific **Kafka brokers, database credentials, and connector configuration**.

To deploy Debezium, run:
```bash
helm upgrade --install debezium-mssql /path/to/debezium/chart -f values.yaml --namespace debezium
```

### 🛠 OpenShift-Specific Configuration
If deploying on **OpenShift**, ensure:
- The container runs as **non-root**.
- Correct **Security Context Constraints (SCC)** are applied.

Example SCC command:
```bash
oc adm policy add-scc-to-user anyuid -z debezium-sa -n debezium
```

## Kafka Topic Naming Convention

Each connector requires **5 system topics** alongside data topics. The standard naming convention is:

```bash
debezium.DB.TABLE
debezium.DB.TABLE.configs
debezium.DB.TABLE.history
debezium.DB.TABLE.offsets
debezium.DB.TABLE.schema
debezium.DB.TABLE.statuses
```

This approach ensures **clarity and standardization** across Kafka topics.

## CI/CD Deployment in OpenShift & Kubernetes

### 📦 Pushing the Helm Chart to an OCI Registry
```yaml
deploy_helm:
  stage: deploy
  image: docker:18-dind
  services:
  - docker:18-dind
  environment: { name: production }
  tags: [docker]
  only:
    refs: [master]
  script:
  - export CHART_VERSION=$(grep version Chart.yaml | awk '{print $2}')
  - chmod 400 $DOCKERCONFIG
  - mkdir registry
  - alias helm='docker run -v $(pwd)/registry:/root/.cache/helm/registry -v $(pwd):/apps -v ${DOCKERCONFIG}:/root/.docker/config.json -e DOCKER_CONFIG="/root/.docker" -e HELM_REGISTRY_CONFIG="/root/.docker/config.json" -e HELM_EXPERIMENTAL_OCI=1 alpine/helm'
  - helm chart save . registry.company.com/helm/charts/debezium:${CHART_VERSION}
  - helm chart push registry.company.com/helm/charts/debezium:${CHART_VERSION}
```

### 📥 Installing the Chart from the OCI Registry
```yaml
script:
  - chmod 400 $DOCKERCONFIG
  - chmod 400 $KUBECONFIG
  - mkdir registry
  - alias helm='docker run -v ${KUBECONFIG}:/root/.kube/config -v $(pwd)/registry:/root/.cache/helm/registry -v $(pwd):/apps -v ${DOCKERCONFIG}:/root/.docker/config.json -e DOCKER_CONFIG="/root/.docker" -e HELM_REGISTRY_CONFIG="/root/.docker/config.json" -e HELM_EXPERIMENTAL_OCI=1 alpine/helm'
  - helm chart pull company.com/helm/charts/debezium:$chart_version
  - helm chart export company.com/helm/charts/debezium:$chart_version
  - helm upgrade --install -f values.yaml --namespace debezium debezium-mssql
```

## 📊 Monitoring with Prometheus & Grafana

A **Grafana dashboard** for monitoring Debezium is in development. Once finalized, it will be published on [Grafana.com](https://grafana.com/).

## Example Configuration for MSSQL

### 🛠 Microsoft SQL Server Connector Example
```yaml
debezium:
  name: "debezium-mssql"
  image: "debezium/connect:1.7.1.Final"
  properties:
    group_id: "debezium-group"
    topics_basename: "debezium.mssql"
  connector:
    name: "mssql-connector"
    config:
      connector.class: "io.debezium.connector.sqlserver.SqlServerConnector"
      database.hostname: "mssql-server"
      database.port: "1433"
      database.user: "debezium"
      database.password: "debezium-password"
      database.dbname: "my_database"
      database.server.name: "mssql-server"
      table.include.list: "dbo.customers,dbo.orders"
      database.history.kafka.bootstrap.servers: "kafka-bootstrap:9092"
      database.history.kafka.topic: "schema-changes.mssql"
      decimal.handling.mode: "double"
      snapshot.mode: "schema_only"
      tasks.max: "1"
      include.schema.changes: "true"
      schema.history.internal.kafka.bootstrap.servers: "kafka-bootstrap:9092"
      schema.history.internal.kafka.topic: "schema-changes-history"
```

## 🔹 Final Notes

- **Ensure Kafka topics are created before running the connector.**
- **Adjust Helm values to match your deployment environment.**
- **Use Prometheus & Grafana for monitoring.**

🚀 **Debezium Helm Chart is fully optimized for OpenShift & Kubernetes!**

