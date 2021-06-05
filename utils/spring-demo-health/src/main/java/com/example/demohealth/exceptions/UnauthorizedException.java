package com.example.demohealth.exceptions;

import org.springframework.http.HttpStatus;

public class UnauthorizedException extends ApplicationException {

    private static final long serialVersionUID = 1L;

    public UnauthorizedException(final String message) {
        super(message, HttpStatus.UNAUTHORIZED);
    }

}
