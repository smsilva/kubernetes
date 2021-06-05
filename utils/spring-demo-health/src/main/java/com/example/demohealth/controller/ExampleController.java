package com.example.demohealth.controller;

import com.example.demohealth.config.ApplicationInfo;
import com.example.demohealth.services.DemoHealthService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.RestController;

import java.net.InetAddress;
import java.net.NetworkInterface;
import java.util.Enumeration;

@RestController
public class ExampleController {

    @Autowired
    private ApplicationInfo info;

    @Autowired
    private DemoHealthService service;

    @GetMapping("/hello")
    @ResponseBody
    public ResponseEntity<ApplicationInfo> sayHello() throws Exception {
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

        service.test();

        return ResponseEntity.ok()
                .headers(responseHeaders)
                .body(info);
    }

}
