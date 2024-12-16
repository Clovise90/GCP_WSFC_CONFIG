# Windows Server Failover Cluster on GCP

This Terraform configuration deploys a Windows Server Failover Cluster (WSFC) infrastructure on Google Cloud Platform. The setup includes SQL Server 2019 on Windows Server 2022 with high availability configuration.

## Architecture

The infrastructure consists of:
- 1 Domain Controller (DC)
- 2 Windows SQL Server nodes in a failover cluster
- Internal load balancer for high availability
- Custom VPC network with firewall rules
- Health checks for cluster monitoring

### Components
- **Domain Controller (wsfc-dc)**: Manages Active Directory and DNS
- **Node 1 (wsfc-node-1)**: Primary SQL Server instance
- **Node 2 (wsfc-node-2)**: Secondary SQL Server instance
- **Load Balancer**: Manages traffic between the cluster nodes

## Prerequisites

- Google Cloud Platform account
- Terraform installed (version 0.12+)
- GCP project with required APIs enabled
- Service account with necessary permissions
- Google Cloud SDK

## Configuration Files

- `provider.tf`: GCP provider configuration
- `main.tf`: Main infrastructure configuration
- `variables.tf`: Variable definitions
- `terraform.tfvars`: Variable values
- `.gitignore`: Git ignore patterns

## Network Configuration

- VPC: Custom network (10.0.0.0/16)
- Firewall Rules:
  - RDP access (port 3389)
  - Internal subnet communication
  - Health check access (port 59998)

## Instance Groups

wsfc-group-1 and wsfc-group-2 are essential components of the load balancing setup:

They logically group cluster nodes for Each group that contains one node of failover cluster
They enable the load balancer to direct traffic to the appropriate node
They allow health checks to monitor node availability


Specific Functions:

wsfc-group-1: Contains the first node (wsfc-node-1)
wsfc-group-2: Contains the second node (wsfc-node-2)
Both groups are configured with named ports (port 80 for HTTP)
They enable the load balancer to automatically detect the active node


Load Balancing Integration:

The groups are used as backends in the load balancer configuration
Health checks monitor the nodes through these groups
When failover occurs, the load balancer automatically routes traffic to the active node

## Post-Deployment Steps

1. Configure Active Directory on the Domain Controller
2. Join nodes to the domain
3. Configure Windows Server Failover Clustering
4. Set up SQL Server Always On Availability Groups

## Security Notes

- The RDP firewall rule (port 3389) is open to all IPs (0.0.0.0/0)
- Modify the source ranges in production
- Update service account scopes as needed

## Maintenance

- Regular backups of AD and SQL Server data
- Monitor health checks
- Keep Windows Server and SQL Server updated

## Contributors

[Clovise Lehdogha/visa]

