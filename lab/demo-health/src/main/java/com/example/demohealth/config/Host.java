package com.example.demohealth.config;

import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.util.Enumeration;
import java.util.logging.Logger;

@Component
public class Host {

    private Logger LOGGER = Logger.getLogger(Host.class.getName());

    private String name;
    private String ipv4;

    public Host() throws Exception {
        this.update();
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getIpv4() {
        return ipv4;
    }

    public void setIpv4(String ipv4) {
        this.ipv4 = ipv4;
    }

    @PostConstruct
    public void update() throws Exception {
        LOGGER.info("created");
        final Enumeration<NetworkInterface> networkInterfaces = NetworkInterface.getNetworkInterfaces();
        while (networkInterfaces.hasMoreElements()) {
            final NetworkInterface networkInterface = networkInterfaces.nextElement();
            final InetAddress inetAddress = networkInterface.getInetAddresses().nextElement();
            if ("eth0".equalsIgnoreCase(networkInterface.getDisplayName())) {
                this.setName(inetAddress.getHostName());
                this.setIpv4(inetAddress.getHostAddress());
            }
        }
    }
}
