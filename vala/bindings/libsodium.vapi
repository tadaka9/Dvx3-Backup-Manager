/* Minimal libsodium VAPI for dvx3 usage */

[CCode (cheader_filename = "sodium.h")]
namespace Sodium {
    [CCode (cname = "sodium_init")] public static int init ();
    [CCode (cname = "sodium_memzero")]
    public static void memzero ([CCode (array_length = false)] uint8[] data, size_t size);
    [CCode (cname = "crypto_auth_BYTES")] public const size_t AUTH_BYTES;
    [CCode (cname = "crypto_auth")]
    public static int auth ([CCode (array_length = false)] uint8[] tag,
                            [CCode (array_length = false)] uint8[] message, uint64 length,
                            [CCode (array_length = false)] uint8[] key);
    /* Top-level constants and pwhash */
    [CCode (cname = "crypto_pwhash_SALTBYTES")] public const size_t CRYPTO_PWHASH_SALTBYTES;
    [CCode (cname = "crypto_pwhash_ALG_ARGON2ID13")] public const int CRYPTO_PWHASH_ALG_ARGON2ID13;

    [CCode (cname = "crypto_pwhash")]
    public static int crypto_pwhash (
        [CCode (array_length = false)] uint8[] out,
        uint64 outlen,
        string passwd,
        uint64 passwdlen,
        [CCode (array_length = false)] uint8[] salt,
        uint64 opslimit,
        size_t memlimit,
        int alg
    );

    namespace Random {
        [CCode (cname = "randombytes_buf")]
        public static void buffer ([CCode (array_length = false)] uint8[] buf, size_t size);
    }

    namespace Symmetric {
        [CCode (cname = "crypto_secretbox_NONCEBYTES")] public const size_t NONCE_BYTES;
        [CCode (cname = "crypto_secretbox_KEYBYTES")]  public const size_t KEY_BYTES;
        [CCode (cname = "crypto_secretbox_MACBYTES")]  public const size_t MAC_BYTES;

        [CCode (cname = "crypto_secretbox_easy")]
        public static int secretbox (
            [CCode (array_length = false)] uint8[] c,
            [CCode (array_length = false)] uint8[] m,
            uint64 mlen,
            [CCode (array_length = false)] uint8[] n,
            [CCode (array_length = false)] uint8[] k
        );

        [CCode (cname = "crypto_secretbox_open_easy")]
        public static int secretbox_open (
            [CCode (array_length = false)] uint8[] m,
            [CCode (array_length = false)] uint8[] c,
            uint64 clen,
            [CCode (array_length = false)] uint8[] n,
            [CCode (array_length = false)] uint8[] k
        );
    }
}
