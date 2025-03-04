#!/bin/bash

echo "🚀 Setting up complete Debezium CDC environment with SQL Server and Kafka..."

# עצירת והסרת כל המיכלים
echo "🧹 Cleaning up existing containers..."
docker compose down -v

# יצירת docker-compose.yml חדש עם ההגדרות הנכונות
echo "📝 Creating docker-compose.yml file..."
cat > docker-compose.yml << 'EOF'
volumes:
  broker1:
  broker2:
  broker3:
  mssql-data:

networks:
  kafka-net:

services:
  # Microsoft SQL Server
  mssql-primary:
    image: mcr.microsoft.com/mssql/server:2019-latest
    platform: linux/amd64
    container_name: mssql-primary
    hostname: mssql-primary
    user: root
    ports:
      - "1433:1433"
    environment:
      ACCEPT_EULA: "Y"
      MSSQL_SA_PASSWORD: "P@ssw0rd123"
      MSSQL_PID: "Developer"
      MSSQL_AGENT_ENABLED: "true"
    networks:
      - kafka-net
    volumes:
      - mssql-data:/var/opt/mssql
    restart: always

  # Kafka Broker 1
  broker1:
    image: 'bitnami/kafka:latest'
    container_name: broker1
    ports:
      - "9091:9092"
    environment:
      KAFKA_ENABLE_KRAFT: yes
      KAFKA_CFG_PROCESS_ROLES: 'broker,controller'
      KAFKA_CFG_CONTROLLER_LISTENER_NAMES: 'CONTROLLER'
      KAFKA_CFG_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CFG_ADVERTISED_LISTENERS: PLAINTEXT://broker1:9092
      KAFKA_CFG_BROKER_ID: 1
      KAFKA_CFG_NODE_ID: 1
      KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: '1@broker1:9093,2@broker2:9093,3@broker3:9093'
      ALLOW_PLAINTEXT_LISTENER: yes
      KAFKA_KRAFT_CLUSTER_ID: 9Fe32R9TTRCr2cVolz95pw
    volumes:
      - broker1:/bitnami/kafka
    networks:
      - kafka-net

  # Kafka Broker 2
  broker2:
    image: 'bitnami/kafka:latest'
    container_name: broker2
    ports:
      - "9092:9092"
    environment:
      KAFKA_ENABLE_KRAFT: yes
      KAFKA_CFG_PROCESS_ROLES: 'broker,controller'
      KAFKA_CFG_CONTROLLER_LISTENER_NAMES: 'CONTROLLER'
      KAFKA_CFG_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CFG_ADVERTISED_LISTENERS: PLAINTEXT://broker2:9092
      KAFKA_CFG_BROKER_ID: 2
      KAFKA_CFG_NODE_ID: 2
      KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: '1@broker1:9093,2@broker2:9093,3@broker3:9093'
      ALLOW_PLAINTEXT_LISTENER: yes
      KAFKA_KRAFT_CLUSTER_ID: 9Fe32R9TTRCr2cVolz95pw
    volumes:
      - broker2:/bitnami/kafka
    networks:
      - kafka-net
    depends_on:
      - broker1
  
  # Kafka Broker 3
  broker3:
    image: 'bitnami/kafka:latest'
    container_name: broker3
    ports:
      - "9094:9092"
    environment:
      KAFKA_ENABLE_KRAFT: yes
      KAFKA_CFG_PROCESS_ROLES: 'broker,controller'
      KAFKA_CFG_CONTROLLER_LISTENER_NAMES: 'CONTROLLER'
      KAFKA_CFG_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CFG_ADVERTISED_LISTENERS: PLAINTEXT://broker3:9092
      KAFKA_CFG_BROKER_ID: 3
      KAFKA_CFG_NODE_ID: 3
      KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: '1@broker1:9093,2@broker2:9093,3@broker3:9093'
      ALLOW_PLAINTEXT_LISTENER: yes
      KAFKA_KRAFT_CLUSTER_ID: 9Fe32R9TTRCr2cVolz95pw
    volumes:
      - broker3:/bitnami/kafka
    networks:
      - kafka-net
    depends_on:
      - broker1

  # Kafka UI (ניהול Kafka דרך דפדפן)
  kafka-ui:
    container_name: kafka-ui
    image: 'provectuslabs/kafka-ui:latest'
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_BOOTSTRAP_SERVERS: "broker1:9092,broker2:9092,broker3:9092"
      KAFKA_CLUSTERS_0_NAME: "kafka-cluster"
    networks:
      - kafka-net
    depends_on:
      - broker1
      - broker2
      - broker3
    restart: always

  # Kafka Connect עם Debezium
  kafka-connect-source:
    image: debezium/connect:2.4
    container_name: kafka-connect-source
    ports:
      - "8083:8083"
    environment:
      GROUP_ID: "1"
      CONFIG_STORAGE_TOPIC: "connect-configs"
      OFFSET_STORAGE_TOPIC: "connect-offsets"
      STATUS_STORAGE_TOPIC: "connect-status"
      BOOTSTRAP_SERVERS: "broker1:9092,broker2:9092,broker3:9092"
      KEY_CONVERTER: "org.apache.kafka.connect.json.JsonConverter"
      VALUE_CONVERTER: "org.apache.kafka.connect.json.JsonConverter"
      KEY_CONVERTER_SCHEMAS_ENABLE: "false"
      VALUE_CONVERTER_SCHEMAS_ENABLE: "false"
    volumes:
      - ./entrypoint.sh:/entrypoint.sh
    networks:
      - kafka-net
    depends_on:
      - mssql-primary
      - broker1
      - broker2
      - broker3
    restart: always
EOF

# Dockerfile לקאפקה קונקט
echo "📝 Creating entrypoint.sh for Kafka Connect..."
cat > entrypoint.sh << 'EOF'
#!/bin/bash

echo "📌 Waiting for Kafka to be ready..."
until (echo > /dev/tcp/broker1/9092) >/dev/null 2>&1; do
  echo "⏳ Kafka broker is not ready yet. Waiting..."
  sleep 5
done

echo "📌 Waiting for SQL Server to initialize..."
until (echo > /dev/tcp/mssql-primary/1433) >/dev/null 2>&1; do
  echo "⏳ SQL Server is not ready yet. Waiting..."
  sleep 5
done

echo "🚀 Starting Kafka Connect..."
/etc/confluent/docker/run &

# Keep container running
tail -f /dev/null
EOF

# הפיכת entrypoint.sh להרצה
echo "🔑 Making entrypoint.sh executable..."
chmod +x entrypoint.sh

# יצירת קובץ להקמת מסד הנתונים
echo "📝 Creating setup-database.sql..."
cat > setup-database.sql << 'EOF'
-- יצירת מסד נתונים חדש
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'TestDB')
BEGIN
    CREATE DATABASE TestDB;
END
GO

USE TestDB;
GO

-- הפעלת CDC במסד הנתונים
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'TestDB' AND is_cdc_enabled = 1)
BEGIN
    EXEC sys.sp_cdc_enable_db;
END
GO

-- יצירת טבלה לדוגמה
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TestTable')
BEGIN
    CREATE TABLE TestTable (
        id INT IDENTITY PRIMARY KEY,
        name NVARCHAR(50),
        age INT
    );
END
GO

-- הפעלת CDC בטבלה
IF NOT EXISTS (SELECT 1 FROM sys.tables t
              INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
              LEFT JOIN cdc.change_tables ct ON t.object_id = ct.source_object_id
              WHERE t.name = 'TestTable' AND s.name = 'dbo' AND ct.source_object_id IS NOT NULL)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = N'dbo',
        @source_name = N'TestTable',
        @role_name = NULL;
END
GO

-- הוספת נתונים לדוגמה
IF NOT EXISTS (SELECT 1 FROM TestTable)
BEGIN
    INSERT INTO TestTable (name, age) VALUES ('Alice', 30);
    INSERT INTO TestTable (name, age) VALUES ('Bob', 25);
    INSERT INTO TestTable (name, age) VALUES ('Charlie', 35);
END
GO

-- בדיקת הגדרות CDC
SELECT name, is_cdc_enabled FROM sys.databases WHERE name = 'TestDB';
GO

SELECT 
    s.name AS schema_name, 
    t.name AS table_name, 
    CASE WHEN ct.source_object_id IS NOT NULL THEN 'Enabled' ELSE 'Disabled' END AS cdc_status
FROM 
    sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN cdc.change_tables ct ON t.object_id = ct.source_object_id
WHERE 
    t.name = 'TestTable' AND s.name = 'dbo';
GO
EOF

# הרצת המערכת
echo "🚀 Starting services..."
docker compose up -d

# וידוא שכלי jq מותקן
echo "🔧 Checking for jq tool..."
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Installing jq..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    elif command -v brew &> /dev/null; then
        brew install jq
    else
        echo "⚠️ Cannot install jq automatically. Please install jq manually to parse JSON outputs."
    fi
fi

# המתנה לעליית השירותים
echo "⏳ Waiting for services to start (60 seconds)..."
sleep 60

# התקנת כלי SQL Server במיכל
echo "🔧 Installing SQL Server tools in container..."
docker exec -it mssql-primary bash -c "apt-get update && apt-get install -y curl gnupg && \
  curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
  curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
  apt-get update && ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev && \
  ln -s /opt/mssql-tools/bin/sqlcmd /usr/bin/sqlcmd"

# העתקת קובץ ה-SQL והרצתו
echo "🗃️ Setting up database and CDC..."
docker cp setup-database.sql mssql-primary:/tmp/
docker exec -it mssql-primary bash -c "sqlcmd -S localhost -U SA -P 'P@ssw0rd123' -i /tmp/setup-database.sql" || \
  docker exec -it mssql-primary bash -c "/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'P@ssw0rd123' -i /tmp/setup-database.sql"

# יצירת נושא היסטוריית סכמה עם הגדרות נכונות
echo "📦 Creating schema history topic with proper settings..."
docker exec -it broker1 /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server broker1:9092 --delete --topic schema-history.sqlserver 2>/dev/null || echo "Topic does not exist yet"
sleep 3
docker exec -it broker1 /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server broker1:9092 --create --topic schema-history.sqlserver --partitions 1 --replication-factor 1 --config cleanup.policy=delete

# הגדרת מחבר Debezium
echo "🔌 Configuring Debezium connector..."
sleep 5
curl -X DELETE http://localhost:8083/connectors/sqlserver-connector 2>/dev/null || echo "No connector to delete"
sleep 3

# הגדרת מחבר עם פרמטרים נכונים
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" \
  http://localhost:8083/connectors/ -d '{
  "name": "sqlserver-connector",
  "config": {
    "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
    "tasks.max": "1",
    "database.hostname": "mssql-primary",
    "database.port": "1433",
    "database.user": "SA",
    "database.password": "P@ssw0rd123",
    "database.names": "TestDB",
    "database.server.name": "sqlserver",
    "table.include.list": "dbo.TestTable",
    "topic.prefix": "sqlserver.dbo",
    "schema.history.internal.kafka.bootstrap.servers": "broker1:9092",
    "schema.history.internal.kafka.topic": "schema-history.sqlserver",
    "schema.history.internal.store.only.captured.tables.ddl": "true",
    "database.encrypt": "false",
    "database.trustServerCertificate": "true",
    "include.schema.changes": "true",
    "snapshot.mode": "initial"
  }
}'

# המתנה להתאתחלות המחבר
echo "⏳ Waiting for connector to initialize (20 seconds)..."
sleep 20

# בדיקת סטטוס המחבר
echo "🔍 Checking connector status:"
if command -v jq &> /dev/null; then
    curl -s http://localhost:8083/connectors/sqlserver-connector/status | jq
else
    echo "jq not available. Showing raw output:"
    curl -s http://localhost:8083/connectors/sqlserver-connector/status
fi

# הוספת נתון חדש לבדיקה
echo "📝 Adding a test record to SQL Server..."
docker exec -it mssql-primary bash -c "sqlcmd -S localhost -U SA -P 'P@ssw0rd123' -d TestDB -Q \"INSERT INTO TestTable (name, age) VALUES ('Test CDC', 42); SELECT * FROM TestTable WHERE name = 'Test CDC';\""

# המתנה להופעת הנתון בקאפקה
echo "⏳ Waiting for data to propagate to Kafka (15 seconds)..."
sleep 15

# בדיקת נושאי קאפקה
echo "📋 Available Kafka topics:"
docker exec -it broker1 /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server broker1:9092 --list

# בדיקת הנתונים בקאפקה
echo "📊 Checking data in Kafka topic (this might take a moment):"
docker exec -it broker1 /opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server broker1:9092 --topic sqlserver.dbo.TestTable --from-beginning --max-messages 4 --timeout-ms 10000 || echo "Finished reading messages or no data available"

echo "✅ Debezium CDC environment setup complete!"
echo "📊 Kafka UI is available at: http://localhost:8080"
echo "🔧 Kafka Connect REST API is available at: http://localhost:8083"
echo "💾 SQL Server is available at: localhost:1433"
echo ""
echo "To test the CDC functionality, run:"
echo "docker exec -it mssql-primary bash -c \"sqlcmd -S localhost -U SA -P 'P@ssw0rd123' -d TestDB -Q \\\"INSERT INTO TestTable (name, age) VALUES ('New User', 50);\\\"\"" 
echo ""
echo "To view messages in Kafka:"
echo "docker exec -it broker1 /opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server broker1:9092 --topic sqlserver.dbo.TestTable --from-beginning"
