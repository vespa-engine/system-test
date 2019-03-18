// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.servlet;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.ServletException;
import javax.servlet.ServletConfig;
import java.io.IOException;
import java.lang.Override;
import com.yahoo.component.ComponentId;

public class ServletWithId extends HttpServlet {

    private final ComponentId id;

    public ServletWithId(ComponentId id) {
        this.id = id;
    }

    @Override
    public void init() throws ServletException {
        System.err.println("init " + id);
    }

    @Override
    public void destroy() {
        System.err.println("destroy " + id);
    }

    @Override
    protected void doGet( HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        response.getWriter().write("Hello " + id);
    }
}
