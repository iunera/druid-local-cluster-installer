# Development Guidelines

This document provides guidelines for developers who want to either use this local Druid cluster for their own projects or contribute to the `druid-local-cluster-installer` itself.

## Project Structure

The repository is structured to be simple and easy to understand. Here are the key files:

-   `docker-compose.yaml`: The main Docker Compose file that defines all the Druid services.
-   `environment`: A file containing environment variables for configuring the Druid cluster. This is where you can customize cluster settings.
-   `install.sh`: The installation script for macOS and Linux. It downloads the necessary files to the user's home directory and starts the cluster.
-   `install.ps1`: The installation script for Windows (PowerShell). It performs the same function as the shell script.
-   `README.md`: The main documentation for the project.
-   `LICENSE`: The Apache 2.0 license file.
-   `development.md`: This file.

## Using the Cluster for Development

This local Druid cluster is ideal for developing and testing applications that interact with Druid.

### Prerequisites

-   Docker and Docker Compose installed.
-   At least 8GB of RAM allocated to Docker.

### Starting and Stopping the Cluster

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/iunera/druid-local-cluster-installer.git
    cd druid-local-cluster-installer
    ```

2.  **Start the cluster:**
    ```bash
    docker compose up -d
    ```

3.  **Stop the cluster:**
    ```bash
    docker compose down
    ```

### Accessing Services

-   **Druid Router (UI and API):** `http://localhost:8888`
-   **Default Credentials:** `admin` / `password`
-   **PostgreSQL (Metadata Store):** The `postgres` service is available on port `5432` within the Docker network.

### Wiping Data

To completely reset the cluster, including all metadata and ingested data, run:
```bash
docker compose down -v
```

### Customizing the Cluster

You can customize the Druid cluster by modifying the `environment` file. For example, you can change memory settings, enable or disable features, or change logging levels. After making changes, restart the cluster for them to take effect:
```bash
docker compose down && docker compose up -d
```

## Developing the Installer

The installation scripts (`install.sh` and `install.ps1`) are simple wrappers that download the project files and run `docker compose`.

### Testing Installer Changes

To test changes to the installer scripts, you should run them locally.

**For `install.sh`:**
```bash
# Make sure the script is executable
chmod +x install.sh

# Run the script
./install.sh
```

**For `install.ps1`:**
```powershell
# You may need to adjust your execution policy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Run the script
.\install.ps1
```

Be aware that the scripts are designed to create a `.druid-local-cluster` directory in your home folder. You may want to modify the script to use a temporary directory during development.

## Troubleshooting for Developers

-   **Check service logs:**
    ```bash
    docker compose logs -f [service-name]
    ```
    (e.g., `coordinator`, `broker`, `router`)

-   **Port conflicts:** If you have another service running on port `8888`, the Druid router will fail to start. You can change the port mapping in `docker-compose.yaml`.

-   **Insufficient resources:** If services are unstable, ensure Docker has at least 8GB of RAM allocated in the Docker Desktop settings.

## Updating Service Versions

To update the version of Druid or other services (PostgreSQL, ZooKeeper), you need to change the image tag in `docker-compose.yaml`.

For example, to update Druid from `apache/druid:34.0.0` to a new version, you would change the `image` tag for all the Druid services.

After updating the image versions, it's a good idea to pull the new images before starting the cluster:
```bash
docker compose pull
```

## Contributing

We welcome contributions to improve the `druid-local-cluster-installer`.

### Contribution Workflow

1.  **Fork the repository** on GitHub.
2.  **Create a new branch** for your feature or bug fix.
3.  **Make your changes** and commit them with clear, descriptive messages.
4.  **Test your changes** locally.
5.  **Push your branch** to your fork.
6.  **Create a pull request** to the `main` branch of the original repository.

### Reporting Issues

If you find a bug or have a suggestion, please open an issue on the GitHub repository. Provide as much detail as possible, including:
-   Your operating system.
-   The steps to reproduce the issue.
-   The output of `docker compose ps` and any relevant logs.

---

*© 2025 [iunera](https://www.iunera.com). Licensed under the Apache License 2.0.*
