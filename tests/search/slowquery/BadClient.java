// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.prelude.test;

import java.net.*;
import java.io.*;
import java.nio.charset.Charset;

public class BadClient {

    private String server;
    private int port;
    private static final Charset UTF8 = Charset.forName("UTF-8");

    public BadClient(String server, int port) {
        this.server = server;
        this.port = port;
    }

    public void connectAndMisbehave() {
        Socket s = null;
        OutputStream w;

        System.err.println("Start misbehaving");
        try {
            s = new Socket(server, port);
            w = s.getOutputStream();
            w.write("GET /search/?query=foobar&hits=400&timeout=1.0s HTTP/1.0\r\n\r\n".getBytes());
            w.flush();
            Thread.sleep(6 * 1000);
            byte[] buffer = new byte[4096];
            StringBuilder result = new StringBuilder();
            InputStream r = s.getInputStream();
            int n = 0;

            do {
                try {
                    n = r.read(buffer);
                } catch (SocketException se) {
                    System.err.println("Caught " + se);
                    n = -1;
                }

                if (n != -1) {
                  result.append(new String(buffer, 0, n, UTF8));
                }
            } while (n != -1 && !result.toString().endsWith("\r\n\r\n"));
            Thread.sleep(5 * 1000);
            s.close();
        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }

    public static void main(String[] args) {
        BadClient b = new BadClient(args[0], Integer.parseInt(args[1]));
        b.connectAndMisbehave();
        System.err.println("Exiting normally");
    }
}
