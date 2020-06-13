$TTL    604800
@       IN      SOA     example.com. root.example.com. (
                             21         ; Serial
                         604820         ; Refresh
                          864500        ; Retry
                        2419270         ; Expire
                         604880 )       ; Negative Cache TTL

;Your Name Server Info
@        IN      NS      primary.example.com.
primary  IN      A       10.45.144.238

;Reverse Lookup for Your DNS Server
238      IN      PTR     primary.example.com.

;PTR Record IP address to HostName
238      IN      PTR     dns.example.com.
123      IN      PTR     lb.example.com.
123      IN      PTR     loadbalancer.example.com.
45      IN      PTR     master-1.example.com.
214      IN      PTR     master-2.example.com.
171      IN      PTR     master-3.example.com.
106      IN      PTR     worker-1.example.com.
121      IN      PTR     worker-2.example.com.
162      IN      PTR     worker-3.example.com.
