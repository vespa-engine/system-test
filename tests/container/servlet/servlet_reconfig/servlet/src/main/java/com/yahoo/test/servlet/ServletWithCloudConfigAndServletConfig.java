// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.servlet;

import javax.servlet.http.HttpServlet;
import javax.servlet.ServletConfig;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.ServletException;
import java.io.IOException;
import java.lang.Override;
import com.yahoo.test.MessageConfig;
import com.fasterxml.jackson.databind.ObjectMapper;

public class ServletWithCloudConfigAndServletConfig extends HttpServlet {
    private final String cloudConfigValue;

    public ServletWithCloudConfigAndServletConfig(MessageConfig messageConfig) {
        cloudConfigValue = messageConfig.message();
    }

    @Override
    protected void doGet( HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        Message message = new Message(cloudConfigValue, getServletConfig().getInitParameter("message"));

        ObjectMapper mapper = new ObjectMapper();

        response.getWriter().write(mapper.writeValueAsString(message));
    }

    private static class Message {
        public String cloudConfigValue;
        public String servletConfigValue;

        Message(String cloudConfigValue, String servletConfigValue) {
            this.cloudConfigValue = (cloudConfigValue != null) ? cloudConfigValue : "";
            this.servletConfigValue = (servletConfigValue != null) ? servletConfigValue : "";
        }
    }
}
