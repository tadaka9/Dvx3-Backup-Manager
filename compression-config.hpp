/**
 * CompressionConfig - Unified compression configuration supporting multiple algorithms
 * 
 * Supported algorithms: zstd, lz4, snappy, xz, bzip2, gzip, zip (future)
 * Encryption: AES-GCM-256 (Intel NI) or XChaCha20-Poly1305 (fallback)
 */

#ifndef BACKUP_MANAGER_COMPRESSION_CONFIG_HPP
#define BACKUP_MANAGER_COMPRESSION_CONFIG_HPP

#include <QString>
#include <QSettings>
#include <vector>
#include <string>

namespace backup {

/**
 * @brief Compression algorithm enumeration
 */
enum class CompressionAlgorithm : int {
    NONE = 0,      // No compression (raw tar)
    GZIP = 1,      // gzip (compatible, balanced)
    LZMA = 2,      // xz (best compression, slow)
    BZIP2 = 3,     // bzip2 (good ratio, slower)
    ZSTD = 4,      // zstd (recommended, fast + good ratio)
    LZ4 = 5,       // lz4 (fastest decompression)
    SNAPPY = 6,    // snappy (very fast, good for logs/temp)
    ZIP = 7        // zip format (future)
};

/**
 * @brief Encryption algorithm enumeration
 */
enum class EncryptionAlgorithm : int {
    NONE = 0,           // No encryption (insecure!)
    XCHACHAPOLY1305 = 1, // XChaCha20-Poly1305 (default, portable)
    CHACHAPOLY1305 = 2,  // ChaCha20-Poly1305 (shorter nonce)
    AES_GCM_256 = 3      // AES-GCM-256 (Intel NI only)
};

/**
 * @brief Compression configuration structure
 */
struct CompressionConfig {
    // Algorithm selection
    CompressionAlgorithm algorithm = CompressionAlgorithm::ZSTD;
    
    // Algorithm-specific parameters
    int zstd_level = 3;                    // 1-22, default 3
    int zstd_threads = 0;                  // 0 = auto-detect
    bool zstd_ultra = false;               // Enable levels >19 (-22)
    
    int lz4_level = -1;                    // -1 to -6 (default -1=fastest)
    
    int xz_level = 9;                      // 0-9, default 9
    bool xz_extreme = false;               // Enable extreme compression
    
    int bzip2_level = 9;                   // 1-9, default 9
    
    int gzip_level = 6;                    // 1-9, default 6
    
    bool snappy_compress = true;           // Use snappy (fast, no params)
    
    // Archive options
    bool tar_preserve_permissions = true;
    bool tar_preserve_owner = true;
    bool tar_follow_symlinks = false;
    bool tar_exclude_hidden = false;
    std::vector<std::string> tar_exclude_patterns;
    
    // Encryption configuration
    EncryptionAlgorithm encryption = EncryptionAlgorithm::XCHACHAPOLY1305;
    
    // Salt for key derivation (stored in archive)
    QString salt;
    
    // Auto-detection settings
    bool auto_detect_intel_ni = true;      // Try to detect Intel NI instructions
    bool force_aes_gcm = false;            // Force AES-GCM even if no Intel NI
    
    // Performance hints
    bool prioritize_speed = false;         // Optimize for speed over compression ratio
    bool prioritize_compression = false;   // Optimize for best compression ratio
    
    /**
     * @brief Get recommended algorithm based on use case
     */
    static CompressionAlgorithm get_recommended_algorithm(const QString& use_case) {
        if (use_case == "archive" || use_case == "backup") {
            return CompressionAlgorithm::ZSTD;  // Best balance
        } else if (use_case == "logs" || use_case == "temp") {
            return CompressionAlgorithm::SNAPPY; // Fastest for logs
        } else if (use_case == "long_term_storage") {
            return CompressionAlgorithm::LZMA;  // Best compression ratio
        } else if (use_case == "universal_compatibility") {
            return CompressionAlgorithm::GZIP;  // Most compatible
        } else {
            return CompressionAlgorithm::ZSTD;  // Default
        }
    }
    
    /**
     * @brief Get recommended encryption based on hardware
     */
    static EncryptionAlgorithm get_recommended_encryption(bool has_intel_ni) {
        if (has_intel_ni && !force_aes_gcm) {
            return EncryptionAlgorithm::AES_GCM_256;  // Faster on Intel
        } else {
            return EncryptionAlgorithm::XCHACHAPOLY1305; // Portable, secure fallback
        }
    }
    
    /**
     * @brief Save configuration to settings
     */
    void save(QSettings& settings) const;
    
    /**
     * @brief Load configuration from settings
     */
    void load(QSettings& settings);
};

} // namespace backup

#endif // BACKUP_MANAGER_COMPRESSION_CONFIG_HPP
