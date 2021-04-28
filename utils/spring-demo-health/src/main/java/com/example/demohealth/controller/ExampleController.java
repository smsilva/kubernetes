package com.example.demohealth.controller;

import com.example.demohealth.config.ApplicationInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.net.InetAddress;
import java.net.NetworkInterface;
import java.util.Enumeration;

@Controller
public class ExampleController {

    @Autowired
    private ApplicationInfo info;

    @GetMapping("/")
    @ResponseBody
    public ResponseEntity<ApplicationInfo>  sayHello() throws Exception {
        HttpHeaders responseHeaders = new HttpHeaders();
        responseHeaders.set("hostname", info.getHostname());

        final Enumeration<NetworkInterface> networkInterfaces = NetworkInterface.getNetworkInterfaces();
        while (networkInterfaces.hasMoreElements()) {
            final NetworkInterface networkInterface = networkInterfaces.nextElement();
            final InetAddress inetAddress = networkInterface.getInetAddresses().nextElement();
            if ("eth0".equalsIgnoreCase(networkInterface.getDisplayName())) {
                responseHeaders.set("ipv4-address-" + networkInterface.getDisplayName(), inetAddress.getHostAddress());
            }
        }

        return ResponseEntity.ok()
                .headers(responseHeaders)
                .body(info);
    }

}
