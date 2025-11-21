# Druid Local Cluster Installer

This directory contains a complete Docker Compose setup for running a full Apache Druid cluster locally. This example is perfect for development, testing, and learning about Druid cluster architecture. It is also the perfect companion for tools like [Data Philter](https://github.com/iunera/data-philter) and the [Druid MCP Server](https://github.com/iunera/druid-mcp-server), which are AI-powered gateways to simplify your interaction with Apache Druid.

## Key Features

- **Complete Druid Cluster:** All core Druid services included (Coordinator, Broker, Historical, MiddleManager, Router).
- **One-Command Install:** Automated scripts for macOS, Linux, and Windows.
- **Cross-Platform:** Runs anywhere Docker is available.
- **Pre-configured:** Comes with sensible defaults for local development.
- **Basic Security Enabled:** Includes a pre-configured admin user (`admin`/`password`).
- **Ready for Data Philter:** Designed to work out-of-the-box with [iunera/data-philter](https://github.com/iunera/data-philter).

## Automated Installation (Recommended)

This method is the easiest way to get your Druid cluster up and running. The script will automatically download the required files, create a dedicated directory for your cluster, and start all the services.

### Prerequisites

- Docker installed and running.
- For macOS/Linux, `curl` or `wget` is required.

### Instructions

Open your terminal, and execute the command for your operating system.

#### macOS / Linux

```bash
curl -sL https://raw.githubusercontent.com/iunera/druid-local-cluster-installer/main/install.sh | sh
```

#### Windows (PowerShell)

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/iunera/druid-local-cluster-installer/main/install.ps1' | Select-Object -ExpandProperty Content | Invoke-Expression"
```

The script will:
1. Create a `.druid-local-cluster` directory in your home folder.
2. Download the `docker-compose.yaml` and environment files into it.
3. Start the Druid cluster using Docker Compose.
4. Open the Druid console in your default web browser.

Once the script is finished, your Druid cluster will be accessible at [http://localhost:8888](http://localhost:8888).

- **Username:** `admin`
- **Password:** `password`

## Manual Installation

### Prerequisites

- Docker and Docker Compose installed
- At least 8GB of available RAM
- At least 10GB of free disk space

### Starting the Cluster

1.  Clone or download this repository.
2.  Navigate to this directory:
    ```bash
    cd druid-local-cluster-installer
    ```
3.  Start the cluster:
    ```bash
    docker compose up -d
    ```
4.  Open the Druid Console and confirm access:
    - URL: http://localhost:8888
    - Username: admin
    - Password: password

## Using this Cluster with Data Philter

This local Druid cluster is the perfect companion for [Data Philter](https://github.com/iunera/data-philter).

1.  **Start this Druid cluster** by following the installation steps above.
2.  Install and configure **Data Philter** to connect to this local cluster. Edit `~/.data-philter/druid.env` and set at least:
    ```bash
       DRUID_ROUTER_URL=http://localhost:8888
       DRUID_SSL_ENABLED=false
       DRUID_AUTH_USERNAME=admin
       DRUID_AUTH_PASSWORD=password
    ```
3.  Start Data Philter and open the app:
    - App URL: http://localhost:4000

## Stopping the Cluster

```bash
docker compose down
```

To also remove volumes (delete all data):
```bash
docker compose down -v
```

## Service Details

### Core Services

| Service | Container | Image | Purpose | Dependencies |
|---------|-----------|-------|---------|--------------|
| **PostgreSQL** | `postgres` | `postgres:17` | Metadata storage | None |
| **ZooKeeper** | `zookeeper` | `zookeeper:3.5.10` | Service coordination | None |
| **Coordinator** | `coordinator` | `apache/druid:34.0.0` | Segment management | postgres, zookeeper |
| **Broker** | `broker` | `apache/druid:34.0.0` | Query processing | postgres, zookeeper, coordinator |
| **Historical** | `historical` | `apache/druid:34.0.0` | Data serving | postgres, zookeeper, coordinator |
| **MiddleManager** | `middlemanager` | `apache/druid:34.0.0` | Task execution | postgres, zookeeper, coordinator |
| **Router** | `router` | `apache/druid:34.0.0` | API gateway | postgres, zookeeper, coordinator |

### Port Mappings

| Service | Internal Port | External Port | Purpose |
|---------|---------------|---------------|---------|
| Router | 8888 | 8888 | Druid Console & API |

### Volume Mappings

| Volume | Purpose | Mounted Services |
|--------|---------|------------------|
| `metadata_data` | PostgreSQL data persistence | postgres |
| `druid_shared` | Shared segment storage | coordinator, historical, middlemanager |
| `coordinator_var` | Coordinator logs and temp files | coordinator |
| `broker_var` | Broker logs and temp files | broker |
| `historical_var` | Historical logs and temp files | historical |
| `middle_var` | MiddleManager logs and temp files | middlemanager |
| `router_var` | Router logs and temp files | router |

## Configuration

### Environment Variables

The cluster uses configuration from the `environment` file. Key settings include:

#### Database Configuration
```bash
druid_metadata_storage_type=postgresql
druid_metadata_storage_connector_connectURI=jdbc:postgresql://postgres:5432/druid
druid_metadata_storage_connector_user=druid
druid_metadata_storage_connector_password=FoolishPassword
```

#### ZooKeeper Configuration
```bash
druid_zk_service_host=zookeeper
```

#### Storage Configuration
```bash
druid_storage_type=local
druid_storage_storageDirectory=/opt/shared/segments
druid_indexer_logs_directory=/opt/shared/indexing-logs
```

#### Performance Tuning
```bash
DRUID_SINGLE_NODE_CONF=micro-quickstart
druid_processing_numThreads=2
druid_processing_numMergeBuffers=2
```

#### Security

This example enables Druid Basic Security with initial credentials for convenience:

```bash
# Initial admin user and internal client passwords
druid_auth_authenticator_MyBasicMetadataAuthenticator_initialAdminPassword=password
druid_escalator_internalClientPassword=internal
```

Default login for the Druid Console:

- Username: admin
- Password: password

### Customizing Configuration

To modify the cluster configuration:

1. Edit the `environment` file
2. Restart the cluster:
   ```bash
   docker compose down
   docker compose up -d
   ```

## Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check service logs
docker compose logs [service-name]

# Check all services status
docker compose ps
```

#### Out of Memory Errors
- Increase Docker memory allocation to at least 8GB
- Modify memory settings in the `environment` file

#### Port Conflicts
- Ensure port 8888 (Druid Router) is not in use by other applications
- Modify port mappings in `docker-compose.yaml` if needed

#### Data Persistence Issues
```bash
# Remove all volumes and start fresh
docker compose down -v
docker compose up -d
```

### Health Checks

Check if all services are running:
```bash
# View running containers
docker compose ps

# Check specific service logs
docker compose logs coordinator
docker compose logs broker

# Follow logs in real-time
docker compose logs -f
```

### Performance Monitoring

Monitor resource usage:
```bash
# View resource usage
docker stats

# Check Druid metrics via API
curl http://localhost:8888/status/health
```

## Sample Data Ingestion

Once the cluster is running, you can test it with sample data:

### Using the Druid Console
1. Go to http://localhost:8888
2. Click "Load data" → "Batch - classic"
3. Use the sample data provided in Druid tutorials

## Cleanup

### Remove Everything
```bash
# Stop and remove containers, networks, and volumes
docker compose down -v --rmi all
```

## Contributing

We welcome contributions! If you would like to contribute, please feel free to create a pull request.

## License

This project is licensed under the Apache License 2.0. See the `LICENSE` file for details.

---

## About iunera

This Docker Compose example is developed and maintained by **[iunera](https://www.iunera.com)**, a leading provider of advanced AI and data analytics solutions.

iunera specializes in:
- **AI-Powered Analytics**: Cutting-edge artificial intelligence solutions for data analysis
- **Enterprise Data Platforms**: Scalable data infrastructure and analytics platforms (Druid, Flink, Kubernetes, Kafka, Spring)
- **Model Context Protocol (MCP) Solutions**: Advanced MCP server implementations for various data systems
- **Custom AI Development**: Tailored AI solutions for enterprise needs

As veterans in Apache Druid iunera deployed and maintained a large number of solutions based on [Apache Druid](https://druid.apache.org/) in productive enterprise grade scenarios.

### Need Expert Apache Druid Consulting?

**Maximize your return on data** with professional Druid implementation and optimization services. From architecture design to performance tuning and AI integration, our experts help you navigate Druid's complexity and unlock its full potential.

**[Get Expert Druid Consulting →](https://www.iunera.com/apache-druid-ai-consulting-europe/)**

For more information about our services and solutions, visit [www.iunera.com](https://www.iunera.com).

### Contact & Support

Need help? Let us know!

- **Website**: [https://www.iunera.com](https://www.iunera.com)
- **Professional Services**: Contact us through [email](mailto:consulting@iunera.com?subject=Druid%20Local%2or%20Cluster%20Installer%20inquiry) for [Apache Druid enterprise consulting, support and custom development](https://www.iunera.com/apache-druid-ai-consulting-europe/)
- **Open Source**: This project is open source and community contributions are welcome

---

*© 2025 [iunera](https://www.iunera.com). Licensed under the Apache License 2.0.*
