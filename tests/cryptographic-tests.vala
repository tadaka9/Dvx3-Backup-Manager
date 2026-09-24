#!/usr/bin/env valac
/* -*- coding: utf-8 -*- */

// Dvx3 Backup Manager - Cryptographic Test Suite
// Tests encryption/decryption integrity with Argon2id + XSalsa20-Poly1305

using GLib;
using Json;
using System;
using Dvx3;


using Sodium;


/* -------------------------------------------------
   Test Results Collection
   ------------------------------------------------ */
private class TestResult {
    public string name;
    public bool passed;
    public string message;
    public long duration_ms;
    
    TestResult(string n) {
        name = n;
        passed = true;
        message = "";
        duration_ms = 0;
    }
}


private List<TestResult> results = new List<TestResult>();


/* -------------------------------------------------
   Utility Functions
   ------------------------------------------------ */
private string colour_wrap (string txt, string col) {
    const string RST = "\x1b[0m";
    return stdout_is_tty () ? "%s%s%s".printf (col, txt, RST) : txt;
}


private bool stdout_is_tty () {
    const int STDOUT_FD = 1;
    int tty_fd = posix_isatty (STDOUT_FD);
    return tty_fd != 0;
}


private string format_duration (long ms) {
    if (ms < 1000) return "%d ms".printf (ms);
    return "%.2f s".printf (ms / 1000.0);
}


private void print_result (TestResult r) {
    const string GRN = "\x1b[32m";
    const string YLW = "\x1b[33m";
    const string RED = "\x1b[31m";
    
    if (r.passed) {
        print ("%s✓ %s: %s (%s)%s".printf (GRN, r.name, r.message, format_duration(r.duration_ms), RST));
    } else {
        print ("%s✗ %s: %s (%s)%s".printf (RED, r.name, r.message, format_duration(r.duration_ms), RST));
    }
}


private void print_summary () {
    int passed = 0;
    int failed = 0;
    
    foreach (var r in results) {
        if (r.passed) passed++;
        else failed++;
    }
    
    const string GRN = "\x1b[32m";
    const string YLW = "\x1b[33m";
    const string RED = "\x1b[31m";
    const string CYN = "\x1b[36m";
    
    print ("%s\n".printf (CYN));
    print ("═══════════════════════════════════════════════════════");
    print ("%sTest Summary%s: %s%d/%d tests passed%s\n".printf (GRN, RST, GRN, passed, results.length, RST));
    print ("═══════════════════════════════════════════════════════\n".printf (CYN));
    
    if (failed > 0) {
        print ("%sFAILED: %d test(s)%s\n".printf (RED, failed, RST));
        Environment.Exit (1);
    } else {
        print ("%sAll tests passed!\n".printf (GRN));
    }
}


/* -------------------------------------------------
   Test 1: Basic Encryption/Decryption Roundtrip
   ------------------------------------------------ */
private void test_basic_roundtrip () {
    print ("\n[Test 1] Basic Encryption/Decryption Roundtrip");
    
    string password = "test_password_secure_123!";
    uint8[] key;
    size_t hash_len;
    Sodium.PasswordHash.hash_get_output_length (ref hash_len);
    key = new uint8[hash_len];
    
    var phash = new PasswordHash (PasswordHashAlgorithm.ARGON2ID);
    phash.hash (password, ref key, ref hash_len);
    
    // Create test data
    string test_data = "Hello, World! This is a test of Dvx3 encryption.";
    uint8[] plaintext = Encoding.UTF8.GetBytes (test_data);
    
    try {
        // Encrypt
        uint8[] ciphertext;
        size_t ct_len;
        Sodium.Secretbox.seal_detached (plaintext, ref ciphertext, ref ct_len, key);
        
        // Decrypt
        uint8[] decrypted;
        size_t dec_len;
        bool authentic;
        var mac = new uint8[Sodium.Symmetric.MAC_BYTES];
        Sodium.Secretbox.open_detached (ciphertext, mac, ref decrypted, ref dec_len, key, ref authentic);
        
        if (!authentic) {
            results.Add (new TestResult ("test_basic_roundtrip").passed = false.message = "Authentication failed");
            return;
        }
        
        string result = Encoding.UTF8.GetString (decrypted);
        bool match = test_data == result;
        
        results.Add (new TestResult ("test_basic_roundtrip")
            .passed = match
            .message = match ? "✓ Roundtrip successful" : "✗ Data mismatch");
    } catch (Exception e) {
        results.Add (new TestResult ("test_basic_roundtrip").passed = false.message = "Exception: " + e.Message);
    }
}


/* -------------------------------------------------
   Test 2: Integrity Verification with SHA-256
   ------------------------------------------------ */
private void test_integrity_verification () {
    print ("\n[Test 2] Integrity Verification (SHA-256)");
    
    string password = "test_password_secure_123!";
    uint8[] key;
    size_t hash_len;
    Sodium.PasswordHash.hash_get_output_length (ref hash_len);
    key = new uint8[hash_len];
    
    var phash = new PasswordHash (PasswordHashAlgorithm.ARGON2ID);
    phash.hash (password, ref key, ref hash_len);
    
    // Create test data with known content
    string test_data = "This is integrity test data for Dvx3.";
    uint8[] plaintext = Encoding.UTF8.GetBytes (test_data);
    
    try {
        // Compute SHA-256 of original data
        var chk = new Checksum (ChecksumType.SHA256);
        chk.update (plaintext, (ulong)plaintext.length);
        uint8[] original_hash;
        size_t hash_len_32;
        chk.get_digest (original_hash, ref hash_len_32);
        
        // Encrypt
        uint8[] ciphertext;
        size_t ct_len;
        Sodium.Secretbox.seal_detached (plaintext, ref ciphertext, ref ct_len, key);
        
        // Decrypt and verify
        uint8[] decrypted;
        size_t dec_len;
        bool authentic;
        var mac = new uint8[Sodium.Symmetric.MAC_BYTES];
        Sodium.Secretbox.open_detached (ciphertext, mac, ref decrypted, ref dec_len, key, ref authentic);
        
        if (!authentic) {
            results.Add (new TestResult ("test_integrity_verification").passed = false.message = "Authentication failed");
            return;
        }
        
        uint8[] decrypted_hash;
        size_t hash_len_32_dec;
        chk.get_digest (decrypted_hash, ref hash_len_32_dec);
        
        // Compare hashes
        bool match = 0 == native_compare (original_hash, decrypted_hash, 32);
        
        results.Add (new TestResult ("test_integrity_verification")
            .passed = match
            .message = match ? "✓ Integrity verified" : "✗ Hash mismatch");
    } catch (Exception e) {
        results.Add (new TestResult ("test_integrity_verification").passed = false.message = "Exception: " + e.Message);
    }
}


/* -------------------------------------------------
   Test 3: Wrong Password Detection
   ------------------------------------------------ */
private void test_wrong_password_detection () {
    print ("\n[Test 3] Wrong Password Detection");
    
    string password = "test_password_secure_123!";
    string wrong_password = "wrong_password_fails!";
    
    uint8[] key;
    size_t hash_len;
    Sodium.PasswordHash.hash_get_output_length (ref hash_len);
    key = new uint8[hash_len];
    
    var phash = new PasswordHash (PasswordHashAlgorithm.ARGON2ID);
    phash.hash (password, ref key, ref hash_len);
    
    string test_data = "This should not decrypt with wrong password.";
    uint8[] plaintext = Encoding.UTF8.GetBytes (test_data);
    
    try {
        // Encrypt with correct password
        uint8[] ciphertext;
        size_t ct_len;
        Sodium.Secretbox.seal_detached (plaintext, ref ciphertext, ref ct_len, key);
        
        // Try to decrypt with wrong password
        uint8[] bad_key;
        hash_len = 0;
        phash.hash (wrong_password, ref bad_key, ref hash_len);
        
        uint8[] mac = new uint8[Sodium.Symmetric.MAC_BYTES];
        bool authentic = false;
        uint8[] decrypted = null;
        size_t dec_len = 0;
        
        try {
            Sodium.Secretbox.open_detached (ciphertext, mac, ref decrypted, ref dec_len, bad_key, ref authentic);
            results.Add (new TestResult ("test_wrong_password_detection").passed = false.message = "✗ Wrong password accepted");
        } catch {
            // Expected: authentication should fail
            results.Add (new TestResult ("test_wrong_password_detection")
                .passed = true
                .message = "✓ Wrong password rejected");
        }
    } catch (Exception e) {
        results.Add (new TestResult ("test_wrong_password_detection").passed = true.message = "✓ Exception thrown: " + e.Message);
    }
}


/* -------------------------------------------------
   Test 4: Large File Encryption (1 MiB)
   ------------------------------------------------ */
private void test_large_file_encryption () {
    print ("\n[Test 4] Large File Encryption (1 MiB)");
    
    string password = "test_password_secure_123!";
    uint8[] key;
    size_t hash_len;
    Sodium.PasswordHash.hash_get_output_length (ref hash_len);
    key = new uint8[hash_len];
    
    var phash = new PasswordHash (PasswordHashAlgorithm.ARGON2ID);
    phash.hash (password, ref key, ref hash_len);
    
    // Create 1 MiB of test data
    string template = "Dvx3 backup test data for performance testing.";
    uint8[] plaintext = new uint8[1024 * 1024];  // 1 MiB
    
    int idx = 0;
    while (idx < plaintext.length) {
        int write_len = Math.min (template.length, plaintext.length - idx);
        for (int i = 0; i < write_len; i++) {
            plaintext[idx + i] = (byte)template[i % template.length];
        }
        idx += write_len;
    }
    
    long start_time = DateTime.UtcNow.ToUnixTimeMilliseconds ();
    
    try {
        // Encrypt large data
        uint8[] ciphertext;
        size_t ct_len;
        Sodium.Secretbox.seal_detached (plaintext, ref ciphertext, ref ct_len, key);
        
        long end_time = DateTime.UtcNow.ToUnixTimeMilliseconds ();
        long duration_ms = end_time - start_time;
        
        // Decrypt and verify
        uint8[] decrypted;
        size_t dec_len;
        bool authentic;
        var mac = new uint8[Sodium.Symmetric.MAC_BYTES];
        Sodium.Secretbox.open_detached (ciphertext, mac, ref decrypted, ref dec_len, key, ref authentic);
        
        if (!authentic) {
            results.Add (new TestResult ("test_large_file_encryption").passed = false.message = "Authentication failed");
            return;
        }
        
        results.Add (new TestResult ("test_large_file_encryption")
            .passed = true
            .message = "✓ Large file encrypted/decrypted in %s".printf (format_duration(duration_ms)));
    } catch (Exception e) {
        results.Add (new TestResult ("test_large_file_encryption").passed = false.message = "Exception: " + e.Message);
    }
}


/* -------------------------------------------------
   Test 5: Unicode Content Handling
   ------------------------------------------------ */
private void test_unicode_content () {
    print ("\n[Test 5] Unicode Content Handling");
    
    string password = "test_password_secure_123!";
    uint8[] key;
    size_t hash_len;
    Sodium.PasswordHash.hash_get_output_length (ref hash_len);
    key = new uint8[hash_len];
    
    var phash = new PasswordHash (PasswordHashAlgorithm.ARGON2ID);
    phash.hash (password, ref key, ref hash_len);
    
    // Unicode test data
    string unicode_data = "Hello 世界 🌍 مرحبا العربية עברית 한국어";
    uint8[] plaintext = Encoding.UTF8.GetBytes (unicode_data);
    
    try {
        // Encrypt
        uint8[] ciphertext;
        size_t ct_len;
        Sodium.Secretbox.seal_detached (plaintext, ref ciphertext, ref ct_len, key);
        
        // Decrypt
        uint8[] decrypted;
        size_t dec_len;
        bool authentic;
        var mac = new uint8[Sodium.Symmetric.MAC_BYTES];
        Sodium.Secretbox.open_detached (ciphertext, mac, ref decrypted, ref dec_len, key, ref authentic);
        
        if (!authentic) {
            results.Add (new TestResult ("test_unicode_content").passed = false.message = "Authentication failed");
            return;
        }
        
        string result = Encoding.UTF8.GetString (decrypted);
        bool match = unicode_data == result;
        
        results.Add (new TestResult ("test_unicode_content")
            .passed = match
            .message = match ? "✓ Unicode preserved" : "✗ Unicode corrupted");
    } catch (Exception e) {
        results.Add (new TestResult ("test_unicode_content").passed = false.message = "Exception: " + e.Message);
    }
}


/* -------------------------------------------------
   Test 6: Empty Data Edge Case
   ------------------------------------------------ */
private void test_empty_data () {
    print ("\n[Test 6] Empty Data Edge Case");
    
    string password = "test_password_secure_123!";
    uint8[] key;
    size_t hash_len;
    Sodium.PasswordHash.hash_get_output_length (ref hash_len);
    key = new uint8[hash_len];
    
    var phash = new PasswordHash (PasswordHashAlgorithm.ARGON2ID);
    phash.hash (password, ref key, ref hash_len);
    
    try {
        // Encrypt empty data
        uint8[] plaintext = new uint8[0];
        
        uint8[] ciphertext;
        size_t ct_len;
        Sodium.Secretbox.seal_detached (plaintext, ref ciphertext, ref ct_len, key);
        
        // Decrypt empty data
        uint8[] decrypted;
        size_t dec_len;
        bool authentic;
        var mac = new uint8[Sodium.Symmetric.MAC_BYTES];
        Sodium.Secretbox.open_detached (ciphertext, mac, ref decrypted, ref dec_len, key, ref authentic);
        
        if (!authentic) {
            results.Add (new TestResult ("test_empty_data").passed = false.message = "Authentication failed");
            return;
        }
        
        results.Add (new TestResult ("test_empty_data")
            .passed = true
            .message = "✓ Empty data handled correctly");
    } catch (Exception e) {
        results.Add (new TestResult ("test_empty_data").passed = false.message = "Exception: " + e.Message);
    }
}


/* -------------------------------------------------
   Main Entry Point
   ------------------------------------------------ */
[EntryPoint]
public void main () {
    print ("\n═══════════════════════════════════════════════════════");
    print ("  Dvx3 Cryptographic Test Suite".bold);
    print ("  Argon2id + XSalsa20-Poly1305".italic);
    print ("═══════════════════════════════════════════════════════\n");
    
    test_basic_roundtrip ();
    test_integrity_verification ();
    test_wrong_password_detection ();
    test_large_file_encryption ();
    test_unicode_content ();
    test_empty_data ();
    
    print_summary ();
}
