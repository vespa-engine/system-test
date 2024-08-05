// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.Charset;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.yahoo.jdisc.service.AbstractServerProvider;
import com.yahoo.jdisc.service.CurrentContainer;
import com.yahoo.text.Utf8;

/**
 * Dummy server sort of compatible with HTTP 0.9.
 *
 * @author Steinar Knutsen
 */
public class DemoServer extends AbstractServerProvider {

    private final Logger logger = Logger.getLogger(DemoServer.class.getName());
    private Listener daemon;
    private final int port;
    private final byte[] response;
    private static final byte[] header = Utf8.toBytes(
            "HTTP/1.1 200 OK\r\n"
            + "Connection: close\r\n"
            + "Content-Type: text/html\r\n"
            + "\r\n");
    private final ServerSocket serverSocket;

    private class Listener implements Runnable {
        private final Logger logger = Logger.getLogger(Listener.class.getName());
        private final ServerSocket server;
        private volatile boolean shutdown = false;
        private final byte[] response;
        private final Charset charset = Charset.forName("ISO-8859-1");

        public Listener(ServerSocket s, byte[] response) {
            server = s;
            this.response = response;
        }

        public void run() {
            while (!shutdown) {
                Socket clientSocket;
                try {
                    clientSocket = server.accept();
                } catch (IOException e) {
                    logger.log(Level.WARNING, "Failure while accepting connection.", e);
                    continue;
                }
                try {
                    BufferedReader in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream(), charset));
                    OutputStream out = clientSocket.getOutputStream();

                    in.readLine();
                    out.write(header);
                    out.write(response);
                    out.flush();
                } catch (IOException e) {
                    logger.log(Level.WARNING, "Could not write to client.", e);
                } finally {
                    try {
                        clientSocket.close();
                    } catch (IOException e) {
                        logger.log(Level.WARNING, "Error while closing client socket.", e);
                    }
                }
            }
        }


        public void stop() {
            shutdown = true;
            try {
                server.close();
            } catch (IOException e) {
                // just ignore it
            }
        }

    }

    public DemoServer(CurrentContainer container, DemoServerConfig config) {
        super(container);
        port = config.port();
        // yes, we lie about encoding. the horror... :)
        response = Utf8.toBytes(config.response());
        try {
            serverSocket = new ServerSocket(port);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public void start() {
        daemon = new Listener(serverSocket, response);
        Thread daemonThread = new Thread(daemon);
        daemonThread.setDaemon(true);
        daemonThread.start();
    }

    @Override
    public void close() {
        if (daemon == null) {
            logger.log(Level.SEVERE, "DemoServer.close() invoked without successful start()");
        } else {
            daemon.stop();
        }
    }

}

