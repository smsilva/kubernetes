package com.example.demohealth.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class ApplicationInfo {

    @Autowired
    private Host host;

    public ApplicationInfo() {
    }

    public Host getHost() {
        return this.host;
    }

}
