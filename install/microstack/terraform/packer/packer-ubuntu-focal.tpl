{
    "builders": [
        {
            "type": "openstack",
            "cloud": "openstack",
            "region": "microstack",
            "image_name": "${image_name}-base",
            "source_image": "${image_id}",
            "flavor": "3",
            "ssh_ip_version": "4",
            "ssh_timeout": "15m",
            "ssh_keypair_name": "${ssh_keypair_name}",
            "ssh_private_key_file": "${ssh_private_key_file}",
            "ssh_username": "ubuntu",
            "ssh_host": "${floating_ip_address}",
            "floating_ip": "${floating_ip_id}",
            "networks": [
                "${network_internal_id}"
            ]
        }
    ],
    "provisioners": [
        {
            "script": "setup_vm.sh",
            "type": "shell"
        }
    ]
}
