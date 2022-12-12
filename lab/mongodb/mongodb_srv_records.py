# https://www.mongodb.com/developer/products/mongodb/srv-connection-strings/
import srvlookup #pip install srvlookup
import sys 
import dns.resolver #pip install dnspython 

host = None 

if len(sys.argv) > 1 : 
   host = sys.argv[1] 

if host : 
   services = srvlookup.lookup("mongodb", domain=host)

   for i in services:
      print("%s:%i" % (i.hostname, i.port)) 

   for txtrecord in dns.resolver.resolve(host, 'TXT'): 
      print("%s: %s" % ( host, txtrecord))

else: 
  print("No host specified") 
