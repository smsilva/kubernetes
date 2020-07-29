package com.example.demohealth.controller;

import com.example.demohealth.config.ApplicationInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
public class ExampleController {

    @Autowired
    private ApplicationInfo info;

    @GetMapping("/")
    @ResponseBody
    public ResponseEntity<ApplicationInfo>  sayHello() throws Exception {
        HttpHeaders responseHeaders = new HttpHeaders();
        responseHeaders.set("hostname", info.getHost().getName());
        responseHeaders.set("ipv4-address-eth0", info.getHost().getIpv4());

        return ResponseEntity.ok()
                .headers(responseHeaders)
                .body(info);
    }

}
