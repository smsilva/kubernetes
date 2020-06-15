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
primary      IN       A       10.253.228.149

;A Record for Host names
dns          IN       A       10.253.228.149
lb           IN       A       10.253.228.180
loadbalancer IN       CNAME   lb
masters      IN       CNAME   lb
k8s          IN       CNAME   lb
cluster      IN       CNAME   lb
master-1     IN       A       10.253.228.172
master-2     IN       A       10.253.228.253
master-3     IN       A       10.253.228.142
worker-1     IN       A       10.253.228.93
worker-2     IN       A       10.253.228.13
worker-3     IN       A       10.253.228.209
