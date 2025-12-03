# Oracle Database on Kubernetes Sample

This sample provides Kubernetes manifests and examples for deploying Oracle Database in Kubernetes environments, including Azure Kubernetes Service (AKS) and Google Kubernetes Engine (GKE).

## Overview

This sample demonstrates how to:
- Deploy Oracle Database in Kubernetes pods
- Configure persistent storage for Oracle data
- Set up services for database access
- Integrate Oracle Database with Spring Boot applications
- Implement best practices for production deployments

## Prerequisites

- A running Kubernetes cluster (AKS, GKE, or other)
- `kubectl` installed and configured
- Oracle Container Registry account
- Sufficient cluster resources (see resource requirements below)

## Quick Start

### 1. Create Oracle Container Registry Secret

```bash
kubectl create secret docker-registry oracle-registry \
  --docker-server=container-registry.oracle.com \
  --docker-username=your-oracle-username \
  --docker-password=your-oracle-password \
  --docker-email=your-email@example.com
```

### 2. Create Oracle Password Secret

```bash
kubectl create secret generic oracle-secrets \
  --from-literal=oracle-password=YourStrongPassword123
```

### 3. Deploy Oracle Database

For Oracle Express Edition (development/testing):
```bash
kubectl apply -f oracle-xe-deployment.yaml
```

For Oracle Enterprise Edition (production):
```bash
kubectl apply -f oracle-enterprise-statefulset.yaml
```

### 4. Verify Deployment

```bash
kubectl get pods
kubectl logs <oracle-pod-name>
```

### 5. Connect to Oracle Database

From within the cluster:
```bash
# Using environment variable (recommended)
kubectl exec -it <oracle-pod-name> -- sqlplus system/${ORACLE_PASSWORD}@localhost:1521/XE

# Or with password prompt for security
kubectl exec -it <oracle-pod-name> -- sqlplus system@localhost:1521/XE
```

## Files in This Sample

- `oracle-xe-deployment.yaml` - Basic Oracle XE deployment for development
- `oracle-enterprise-statefulset.yaml` - Production-ready Oracle Enterprise StatefulSet
- `oracle-pvc.yaml` - PersistentVolumeClaim for data storage
- `oracle-service.yaml` - Service definitions for accessing Oracle
- `oracle-configmap.yaml` - ConfigMap with initialization scripts
- `oracle-complete.yaml` - Complete deployment with all components
- `spring-boot-app.yaml` - Example Spring Boot application deployment
- `application.properties.example` - Spring Boot configuration example

## Resource Requirements

### Oracle XE (Development/Testing)
- Memory: 2-4 Gi
- CPU: 1-2 cores
- Storage: 10-20 Gi

### Oracle Enterprise (Production)
- Memory: 8-16 Gi
- CPU: 4-8 cores
- Storage: 100-500 Gi

## Storage Configuration

### Azure Kubernetes Service (AKS)
Use `managed-premium` storage class for production:
```yaml
storageClassName: managed-premium
```

### Google Kubernetes Engine (GKE)
Use `premium-rwo` storage class for production:
```yaml
storageClassName: premium-rwo
```

## Spring Boot Integration

Add Oracle JDBC driver dependency to your `pom.xml`:
```xml
<dependency>
    <groupId>com.oracle.database.jdbc</groupId>
    <artifactId>ojdbc8</artifactId>
    <version>21.5.0.0</version>
</dependency>
```

Configure `application.properties`:
```properties
spring.datasource.url=jdbc:oracle:thin:@oracle-db-service:1521/ORCLPDB1
spring.datasource.username=appuser
spring.datasource.password=${ORACLE_PASSWORD}
spring.datasource.driver-class-name=oracle.jdbc.OracleDriver
spring.jpa.database-platform=org.hibernate.dialect.Oracle12cDialect
```

## Monitoring and Troubleshooting

### Check Pod Status
```bash
kubectl describe pod <oracle-pod-name>
kubectl logs -f <oracle-pod-name>
```

### Monitor Resources
```bash
kubectl top pod <oracle-pod-name>
```

### Test Database Connectivity
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  telnet oracle-db-service 1521
```

### Check Listener Status
```bash
kubectl exec -it <oracle-pod-name> -- lsnrctl status
```

## Security Best Practices

1. Always use Kubernetes Secrets for passwords
2. Enable RBAC and network policies
3. Use TLS/SSL for database connections in production
4. Regularly update Oracle Database images
5. Implement proper backup and recovery procedures
6. Monitor database access and audit logs

## Backup and Recovery

### Create Backup
```bash
kubectl exec -it <oracle-pod-name> -- rman target /
# Run RMAN backup commands
```

### Volume Snapshots
Use Kubernetes VolumeSnapshot for quick backups:
```bash
kubectl create -f volume-snapshot.yaml
```

## Scaling Considerations

- Oracle Database typically runs as a single instance (replicas: 1)
- For high availability, consider Oracle RAC (Enterprise Edition)
- Use StatefulSet for production deployments
- Implement Oracle Data Guard for disaster recovery

## Additional Resources

- [Oracle Container Registry](https://container-registry.oracle.com/)
- [Oracle Database Documentation](https://docs.oracle.com/en/database/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)

## License

Ensure compliance with Oracle licensing terms when running Oracle Database in containers.
Oracle Database Express Edition (XE) is free for development and limited production use.
Enterprise and Standard editions require appropriate licensing.

## Support

For issues with:
- Oracle Database: Contact Oracle Support
- Kubernetes: Refer to your cluster provider's support
- Spring Boot integration: Check Spring documentation

## Contributing

To contribute improvements to this sample:
1. Fork the repository
2. Make your changes
3. Submit a pull request with clear description of changes
