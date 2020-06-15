$TTL    604800
@       IN      SOA     example.com. root.example.com. (
                             21         ; Serial
                         604820         ; Refresh
                          864500        ; Retry
                        2419270         ; Expire
                         604880 )       ; Negative Cache TTL

;Your Name Server Info
@        IN      NS      primary.example.com.
primary  IN      A       10.253.228.149

;Reverse Lookup for Your DNS Server
149      IN      PTR     primary.example.com.

;PTR Record IP address to HostName
149      IN      PTR     dns.example.com.
180      IN      PTR     lb.example.com.
180      IN      PTR     loadbalancer.example.com.
172      IN      PTR     master-1.example.com.
253      IN      PTR     master-2.example.com.
142      IN      PTR     master-3.example.com.
93      IN      PTR     worker-1.example.com.
13      IN      PTR     worker-2.example.com.
209      IN      PTR     worker-3.example.com.
