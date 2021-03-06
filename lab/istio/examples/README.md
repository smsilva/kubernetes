# Examples

## Traffic Management

### Ingress

- [Ingress Traffic](traffic-management/ingress-gateway/README.md) - Gateway and VirtualService
- [Dark Launch](traffic-management/dark-launch/README.md) - Routing Traffic based on Headers Parameters
- [Fault Injection](traffic-management/fault-injection/README.md) - Delays and HTTP Error Codes
- [Request Timeouts](traffic-management/request-timeouts/README.md) - Using Bookinfo Application

### Egress

- [Egress Traffic](traffic-management/egress-gateway/README.md) - Gateway, ServiceEntry, DestinationRule, VirtualService - HTTPS Traffic
- [Egress Traffic with TLS Origination](traffic-management/egress-tls-origination/README.md) - ServiceEntry, DestinationRule, VirtualService - HTTPS Traffic with SNI

## Security

### Authentication

- [Mutual TLS Migration](security/authentication/mtls-strict-mode/README.md) - Using httpbin/sleep

### Authorization

- [Authorization for HTTP traffic](security/authorization/for-http-traffic/README.md) - Using Bookinfo Application
- [Authorization for TCP traffic](security/authorization/for-tcp-traffic/README.md) - Using httpbin/sleep
- [Authorization with JWT](security/authorization/with-jwt/README.md) - Using httpbin/sleep
