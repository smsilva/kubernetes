$TTL    604800

@            IN      SOA primary.example.com. root.primary.example.com. (
                              6         ; Serial
                         604820         ; Refresh
                          86600         ; Retry
                        2419600         ; Expire
                         604600 )       ; Negative Cache TTL

;Name Server Information
@            IN       NS      primary.example.com.

;IP address of Your Domain Name Server(DNS)
primary      IN       A       10.45.144.238

;A Record for Host names
dns          IN       A       10.45.144.238
lb           IN       A       10.45.144.123
loadbalancer IN       CNAME   lb
masters      IN       CNAME   lb
k8s          IN       CNAME   lb
cluster      IN       CNAME   lb
master-1     IN       A       10.45.144.45
master-2     IN       A       10.45.144.214
master-3     IN       A       10.45.144.171
worker-1     IN       A       10.45.144.106
worker-2     IN       A       10.45.144.121
worker-3     IN       A       10.45.144.162
