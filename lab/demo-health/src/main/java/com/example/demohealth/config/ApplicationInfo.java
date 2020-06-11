package com.example.demohealth.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class ApplicationInfo {

    @Value("${HOSTNAME:undefined}")
    private String hostname;

    public ApplicationInfo() {
    }

    public String getHostname() {
        return hostname;
    }

}
