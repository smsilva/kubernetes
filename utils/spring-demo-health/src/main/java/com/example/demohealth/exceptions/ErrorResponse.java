package com.example.demohealth.exceptions;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

@JsonInclude(JsonInclude.Include.NON_NULL)
class ErrorResponse {

    @JsonProperty
    private String message;

    @JsonProperty
    private List<String> details;

    ErrorResponse(String message) {
        this.message = message;
    }

    ErrorResponse(final String message, final List<String> details) {
        super();
        this.message = message;
        this.details = details;
    }

}
