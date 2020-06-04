#!/bin/bash

# Source: https://medium.com/searce/glusterfs-dynamic-provisioning-using-heketi-as-external-storage-with-gke-bd9af17434e5

HEKETI_VERSION="9.0.0"
TAR_FILE="heketi-v${HEKETI_VERSION}.linux.amd64.tar.gz"

wget "https://github.com/heketi/heketi/releases/download/v${HEKETI_VERSION}/${TAR_FILE}"
tar -xzvf "${TAR_FILE}"
cd heketi
cp heketi heketi-cli /usr/local/bin/
heketi -v

groupadd -r -g 515 heketi
useradd -r -c "Heketi user" -d /var/lib/heketi -s /bin/false -m -u 515 -g heketi heketi
mkdir -p /var/lib/heketi && chown -R heketi:heketi /var/lib/heketi
mkdir -p /var/log/heketi && chown -R heketi:heketi /var/log/heketi
mkdir -p /etc/heketi

root@server1:# ssh-keygen -f /etc/heketi/heketi_key -t rsa -N ''
root@server1:# chown heketi:heketi /etc/heketi/heketi_key*

# Change Permission for ssh key files in all 3 nodes for heketi access :
root@server1:# cd /root
root@server1:# mkdir .ssh
root@server1:# cd .ssh/
root@server1:# vi authorized_keys

# paste public key file in this file
root@server1:# chmod 600 /root/.ssh/authorized_keys
root@server1:# chmod 700 /root/.ssh
root@server1:# service sshd restart

# Create the Heketi config file in/etc/heketi/heketi.json
{
  "_port_comment": "Heketi Server Port Number",
  "port": "8080",
  "_use_auth": "Enable JWT authorization. Please enable for deployment",
  "use_auth": true,
  "_jwt": "Private keys for access",
  "jwt": 
  {
    "_admin": "Admin has access to all APIs",
    "admin": {
      "key": "PASSWORD"
    },
    "_user": "User only has access to /volumes endpoint",
    "user": {
      "key": "PASSWORD"
    }
  },
 
  "_glusterfs_comment": "GlusterFS Configuration",
  "glusterfs": 
   {
    "_executor_comment": 
    [
      "Execute plugin. Possible choices: mock, ssh",
      "mock: This setting is used for testing and development.",
      "      It will not send commands to any node.",
      "ssh:  This setting will notify Heketi to ssh to the nodes.",
      "      It will need the values in sshexec to be configured.",
      "kubernetes: Communicate with GlusterFS containers over",
      "            Kubernetes exec api."
    ],
    
    "executor": "ssh",
    "_sshexec_comment": "SSH username and private key file information",
    "sshexec": 
    {
      "keyfile": "/etc/heketi/heketi_key",
      "user": "root",
      "port": "22",
      "fstab": "/etc/fstab"
    },
 
    "_kubeexec_comment": "Kubernetes configuration",
    "kubeexec": 
    {
      "host" :"https://kubernetes.host:8443",
      "cert" : "/path/to/crt.file",
      "insecure": false,
      "user": "kubernetes username",
      "password": "password for kubernetes user",
      "namespace": "OpenShift project or Kubernetes namespace",
      "fstab": "Optional: Specify fstab file on node.  Default is /etc/fstab"
    },
 
    "_db_comment": "Database file name",
    "db": "/var/lib/heketi/heketi.db",
    "brick_max_size_gb" : 1024,
    "brick_min_size_gb" : 1,
    "max_bricks_per_volume" : 33,
 
    "_loglevel_comment": 
    [
      "Set log level. Choices are:",
      "  none, critical, error, warning, info, debug",
      "Default is warning"
    ],
    
    "loglevel" : "debug"
  }
}

#Create the following Heketi service file /etc/systemd/system/heketi.service
[Unit]
Description=Heketi Server
Requires=network-online.target
After=network-online.target
 
[Service]
Type=simple
User=heketi
Group=heketi
PermissionsStartOnly=true
PIDFile=/run/heketi/heketi.pid
Restart=on-failure
RestartSec=10
WorkingDirectory=/var/lib/heketi
RuntimeDirectory=heketi
RuntimeDirectoryMode=0755
ExecStartPre=[ -f "/run/heketi/heketi.pid" ] && /bin/rm -f /run/heketi/heketi.pid
ExecStart=/usr/local/bin/heketi --config=/etc/heketi/heketi.json
ExecReload=/bin/kill -s HUP $MAINPID
KillSignal=SIGINT
TimeoutStopSec=5
 
[Install]
WantedBy=multi-user.target
EOF

# Start the service and check with journalctl:
root@server1:# systemctl daemon-reload
root@server1:# systemctl start heketi.service
root@server1:# journalctl -xe -u heketi

# Now enable the service by restarts:
[root@server1 ~]# systemctl enable heketi

# Create topology/etc/heketi/topology.json config file:
{
  "clusters": [
    {
      "nodes": [
        {
          "node": {
            "hostnames": {
              "manage": [
                "server1"
              ],
              "storage": [
                "10.1.0.1"
              ]
            },
            "zone": 1
          },
          "devices": [
            "/dev/sdb"
          ]
        },
        {
          "node": {
            "hostnames": {
              "manage": [
                "server2"
              ],
              "storage": [
                "10.1.0.2"
              ]
            },
            "zone": 2
          },
          "devices": [
            "/dev/sdb"
          ]
        },
        {
          "node": {
            "hostnames": {
              "manage": [
                "server3"
              ],
              "storage": [
                "10.1.0.3"
              ]
            },
            "zone": 3
          },
          "devices": [
            "/dev/sdb"
          ]
        }
      ]
    }
  ]
}

[root@server1 ~]# export HEKETI_CLI_SERVER=http://server1:8080
[root@server1 ~]# export HEKETI_CLI_USER=admin
[root@server1 ~]# export HEKETI_CLI_KEY=PASSWORD
root@ip-10-99-3-216:/opt/heketi# heketi-cli topology load --json=/opt/heketi/topology.json
    Found node glustera.tftest.encompasshost.internal on cluster 37cc609c4ff862bfa69017747ea4aba4
        Adding device /dev/xvdf ... OK
    Found node glusterb.tftest.encompasshost.internal on cluster 37cc609c4ff862bfa69017747ea4aba4
        Adding device /dev/xvdf ... OK
    Found node glusterc.tftest.encompasshost.internal on cluster 37cc609c4ff862bfa69017747ea4aba4
        Adding device /dev/xvdf ... OK
[root@server1 ~]# heketi-cli cluster list
Clusters:
Id:d1694da0ea9710c9ab44829db617094d [file][block]
[root@server1 ~]# heketi-cli node list
Id:2bcc7da8d6d556062cd0f72901f2ee5e     Cluster:d1694da0ea9710c9ab44829db617094d
Id:95ec22225d398a9e3fb2fd304e2ab370     Cluster:d1694da0ea9710c9ab44829db617094d
Id:ff3aeb28dcb2a6c61be7672b40bbea62     Cluster:d1694da0ea9710c9ab44829db617094d

