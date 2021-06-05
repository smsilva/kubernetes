package com.example.demohealth.services;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class DemoHealthService {

    private static final Logger LOGGER = LoggerFactory.getLogger(DemoHealthService.class);
    private static final String BEARER_SPACE = "Bearer ";

    @Autowired
    public DemoHealthService() {
        LOGGER.info("Constructor");
    }

    public void test() {
        LOGGER.info("This is a INFO message: {}", "parameter value");
        LOGGER.warn("This is a WARN message: {}", "parameter value");
    }

}