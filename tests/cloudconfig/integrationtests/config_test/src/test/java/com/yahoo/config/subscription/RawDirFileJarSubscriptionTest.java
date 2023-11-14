// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.config.subscription;

import com.yahoo.config.AppConfig;
import com.yahoo.config.StringConfig;
import com.yahoo.foo.BarConfig;
import com.yahoo.io.IOUtils;
import org.junit.After;
import org.junit.Test;

import java.io.File;
import java.io.IOException;
import java.util.jar.JarFile;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/**
 * Test cases for raw:, dir:, jar: and file: subscriptions
 *
 * @author vegardh
 */
public class RawDirFileJarSubscriptionTest {

    File tmpFile1;
    File tmpFile2;
    File tmpDir;

    @Test
    public void testRaw() {
        ConfigSubscriber subscriber = new ConfigSubscriber();
        ConfigHandle<AppConfig> h = subscriber.subscribe(AppConfig.class, "raw:message \"I'm raw\"\ntimes 90\n");
        assertTrue(subscriber.nextConfig(0, false));
        assertTrue(h.isChanged());
        assertEquals(h.getConfig().message(), "I'm raw");
        assertFalse(subscriber.nextConfig(0, false));
        assertFalse(h.isChanged());
        assertEquals(h.getConfig().message(), "I'm raw");
        assertFalse(subscriber.nextConfig(0, false));
        assertFalse(h.isChanged());
        assertEquals(h.getConfig().message(), "I'm raw");
        assertFalse(subscriber.nextConfig(0, false));
        assertFalse(h.isChanged());
        assertEquals(h.getConfig().message(), "I'm raw");
        subscriber.close();
    }

    @Test
    public void testRawSource() {
        ConfigSubscriber subscriber = new ConfigSubscriber(new RawSource("message \"I'm properly abstracted\"\ntimes 99\n"));
        ConfigHandle<AppConfig> h = subscriber.subscribe(AppConfig.class, null);
        assertTrue(subscriber.nextConfig(0, false));
        assertTrue(h.isChanged());
        assertEquals(h.getConfig().message(), "I'm properly abstracted");
        assertFalse(subscriber.nextConfig(0, false));
        assertFalse(h.isChanged());
        assertEquals(h.getConfig().message(), "I'm properly abstracted");
        assertFalse(subscriber.nextConfig(0, false));
        assertFalse(h.isChanged());
        assertEquals(h.getConfig().message(), "I'm properly abstracted");
        assertFalse(subscriber.nextConfig(0, false));
        assertFalse(h.isChanged());
        assertEquals(h.getConfig().message(), "I'm properly abstracted");
        subscriber.close();
    }

    @Test
    public void testFile() throws IOException, InterruptedException {
        ConfigSubscriber subscriber = new ConfigSubscriber();
        tmpFile1 = new File("configs/" + System.currentTimeMillis() + ".app.cfg");
        IOUtils.copy(new File("configs/bar/app.cfg"), tmpFile1);
        ConfigHandle<AppConfig> h = subscriber.subscribe(AppConfig.class, "file:" + tmpFile1.getCanonicalPath());
        assertTrue(subscriber.nextConfig(300, false));
        assertTrue(h.isChanged());
        assertEquals(h.getConfig().message(), "msg2");
        assertFalse(subscriber.nextConfig(100, false));
        assertFalse(h.isChanged());
        assertEquals(h.getConfig().message(), "msg2");
        Thread.sleep(1100);
        IOUtils.writeFile(tmpFile1, "message \"msg3YeYe\"\n", false);
        assertTrue(subscriber.nextConfig(300, false));
        assertTrue(h.isChanged());
        assertEquals(h.getConfig().message(), "msg3YeYe");
        assertFalse(subscriber.nextConfig(100, false));
        assertFalse(h.isChanged());
        assertEquals(h.getConfig().message(), "msg3YeYe");
        subscriber.close();
    }

    @Test
    public void testFileSource() throws IOException, InterruptedException {
        tmpFile1 = new File("configs/" + System.currentTimeMillis() + ".app.cfg");
        IOUtils.copy(new File("configs/bar/app.cfg"), tmpFile1);
        ConfigSubscriber subscriber = new ConfigSubscriber(new FileSource(new File(tmpFile1.getCanonicalPath())));
        ConfigHandle<AppConfig> h = subscriber.subscribe(AppConfig.class, null);
        assertTrue(subscriber.nextConfig(300, false));
        assertTrue(h.isChanged());
        assertEquals(h.getConfig().message(), "msg2");
        assertFalse(subscriber.nextConfig(100, false));
        assertFalse(h.isChanged());
        assertEquals(h.getConfig().message(), "msg2");
        Thread.sleep(1100);
        IOUtils.writeFile(tmpFile1, "message \"msg3YeYe\"\n", false);
        assertTrue(subscriber.nextConfig(300, false));
        assertTrue(h.isChanged());
        assertEquals(h.getConfig().message(), "msg3YeYe");
        assertFalse(subscriber.nextConfig(100, false));
        assertFalse(h.isChanged());
        assertEquals(h.getConfig().message(), "msg3YeYe");
        subscriber.close();
    }

    @Test
    public void testDir() throws IOException, InterruptedException {
        ConfigSubscriber subscriber = new ConfigSubscriber();
        tmpDir = new File("configs/" + System.currentTimeMillis() + "/");
        assertTrue(tmpDir.mkdir());
        tmpFile1 = new File(tmpDir, "app.cfg");
        tmpFile2 = new File(tmpDir, "string.cfg");
        IOUtils.copy(new File("configs/bar/app.cfg"), tmpFile1);
        IOUtils.copy(new File("configs/bar/string.cfg"), tmpFile2);

        ConfigHandle<AppConfig> hApp = subscriber.subscribe(AppConfig.class, "dir:" + tmpDir.getCanonicalPath());
        assertTrue(subscriber.nextConfig(300, false));
        assertTrue(hApp.isChanged());
        assertEquals(hApp.getConfig().message(), "msg2");
        assertFalse(subscriber.nextConfig(100, false));
        assertFalse(hApp.isChanged());
        assertEquals(hApp.getConfig().message(), "msg2");
        Thread.sleep(1100);
        IOUtils.writeFile(tmpFile1, "message \"msg3YeYe\"\n", false);
        assertTrue(subscriber.nextConfig(300, false));
        assertTrue(hApp.isChanged());
        assertEquals(hApp.getConfig().message(), "msg3YeYe");
        assertFalse(subscriber.nextConfig(100, false));
        assertFalse(hApp.isChanged());
        assertEquals(hApp.getConfig().message(), "msg3YeYe");

        subscriber.close();
        subscriber = new ConfigSubscriber();
        ConfigHandle<StringConfig> hString = subscriber
                .subscribe(StringConfig.class, "dir:" + tmpDir.getCanonicalPath());
        assertTrue(subscriber.nextConfig(10, false));
        assertTrue(hString.isChanged());
        assertEquals(hString.getConfig().stringVal(), "My mess");
        subscriber.close();
    }

    @Test
    public void testDirSource() throws IOException, InterruptedException {
        tmpDir = new File("configs/" + System.currentTimeMillis() + "/");
        assertTrue(tmpDir.mkdir());
        tmpFile1 = new File(tmpDir, "app.cfg");
        tmpFile2 = new File(tmpDir, "string.cfg");
        IOUtils.copy(new File("configs/bar/app.cfg"), tmpFile1);
        IOUtils.copy(new File("configs/bar/string.cfg"), tmpFile2);
        ConfigSubscriber subscriber = new ConfigSubscriber(new DirSource(new File(tmpDir.getCanonicalPath())));
        ConfigHandle<AppConfig> hApp = subscriber.subscribe(AppConfig.class, null);
        assertTrue(subscriber.nextConfig(300, false));
        assertTrue(hApp.isChanged());
        assertEquals(hApp.getConfig().message(), "msg2");
        assertFalse(subscriber.nextConfig(100, false));
        assertFalse(hApp.isChanged());
        assertEquals(hApp.getConfig().message(), "msg2");
        Thread.sleep(1100);
        IOUtils.writeFile(tmpFile1, "message \"msg3YeYe\"\n", false);
        assertTrue(subscriber.nextConfig(300, false));
        assertTrue(hApp.isChanged());
        assertEquals(hApp.getConfig().message(), "msg3YeYe");
        assertFalse(subscriber.nextConfig(100, false));
        assertFalse(hApp.isChanged());
        assertEquals(hApp.getConfig().message(), "msg3YeYe");

        subscriber.close();
        subscriber = new ConfigSubscriber(new DirSource(new File(tmpDir.getCanonicalPath())));
        ConfigHandle<StringConfig> hString = subscriber.subscribe(StringConfig.class, null);
        assertTrue(subscriber.nextConfig(10, false));
        assertTrue(hString.isChanged());
        assertEquals(hString.getConfig().stringVal(), "My mess");
        subscriber.close();
    }

    /**
     * Tests subscribing with jar:... configid
     */
    @Test
    public void testJar() {
        ConfigSubscriber subscriber = new ConfigSubscriber();
        ConfigHandle<AppConfig> aHDefaultDir = subscriber.subscribe(AppConfig.class, "jar:configs/app.jar");
        ConfigHandle<AppConfig> aHNonDefaultDir = subscriber
                .subscribe(AppConfig.class, "jar:configs/app.jar!/configs/");
        assertTrue(subscriber.nextConfig(300, false));
        assertTrue(aHDefaultDir.isChanged());
        assertEquals(aHDefaultDir.getConfig().message(), "jar-test with default directory");
        assertTrue(aHNonDefaultDir.isChanged());
        assertEquals(aHNonDefaultDir.getConfig().message(), "jar-test with non-default directory");
        assertFalse(subscriber.nextConfig(100, false));
        assertFalse(aHDefaultDir.isChanged());
        assertFalse(aHNonDefaultDir.isChanged());
        assertEquals(aHDefaultDir.getConfig().message(), "jar-test with default directory");
        assertEquals(aHNonDefaultDir.getConfig().message(), "jar-test with non-default directory");
        subscriber.close();
    }


    /**
     * Tests subscribing with non-existing jar
     */
    @Test(expected = IllegalArgumentException.class)
    public void testNonExistingJar() {
        ConfigSubscriber subscriber = new ConfigSubscriber();
        subscriber.subscribe(AppConfig.class, "jar:configs/nonexisting.jar");
        subscriber.nextConfig(300, false);
        subscriber.close();
    }

    /**
     * Tests subscribing with config that is not in jar
     */
    @Test(expected = IllegalArgumentException.class)
    public void testJarWrongConfig() {
        ConfigSubscriber subscriber = new ConfigSubscriber();
        subscriber.subscribe(BarConfig.class, "jar:configs/app.jar");
        subscriber.nextConfig(300, false);
        subscriber.close();
    }

    @Test
    public void testJarSource() throws IOException {
        ConfigSubscriber subscriber1 = new ConfigSubscriber(new JarSource(new JarFile("configs/app.jar"), null));
        ConfigSubscriber subscriber2 = new ConfigSubscriber(new JarSource(new JarFile("configs/app.jar"), "configs/"));

        ConfigHandle<AppConfig> aHDefaultDir = subscriber1.subscribe(AppConfig.class, null);
        ConfigHandle<AppConfig> aHNonDefaultDir = subscriber2.subscribe(AppConfig.class, null);
        assertTrue(subscriber1.nextConfig(300, false));
        assertTrue(subscriber2.nextConfig(300, false));
        assertTrue(aHDefaultDir.isChanged());
        assertEquals(aHDefaultDir.getConfig().message(), "jar-test with default directory");
        assertTrue(aHNonDefaultDir.isChanged());
        assertEquals(aHNonDefaultDir.getConfig().message(), "jar-test with non-default directory");
        assertFalse(subscriber1.nextConfig(100, false));
        assertFalse(subscriber2.nextConfig(100, false));
        assertFalse(aHDefaultDir.isChanged());
        assertFalse(aHNonDefaultDir.isChanged());
        assertEquals(aHDefaultDir.getConfig().message(), "jar-test with default directory");
        assertEquals(aHNonDefaultDir.getConfig().message(), "jar-test with non-default directory");
        subscriber1.close();
        subscriber2.close();
    }


    @SuppressWarnings("ResultOfMethodCallIgnored")
    @After
    public void tearDown() {
        if (tmpFile1 != null) tmpFile1.delete();
        if (tmpFile2 != null) tmpFile2.delete();
        if (tmpDir != null) IOUtils.recursiveDeleteDir(tmpDir);
    }

}
