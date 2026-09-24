/**
 * compression.cpp - Multi-algorithm compression implementation
 * 
 * Supports: zstd, lz4, snappy, xz, bzip2, gzip
 * Encryption: XChaCha20-Poly1305 (default), AES-GCM-256 (Intel NI)
 */

#include "compression.hpp"
#include <QProcess>
#include <QFileInfo>
#include <QStandardPaths>
#include <unistd.h>
#include <sys/stat.h>
#include <cstring>

namespace backup {

CompressionConfig::CompressionConfig() {
    load(QSettings());
}

void CompressionConfig::save(QSettings& settings) const {
    settings.beginGroup("Compression");
    
    // Algorithm selection
    settings.setValue("algorithm", static_cast<int>(algorithm));
    
    // Zstd parameters
    settings.setValue("zstd_level", zstd_level);
    settings.setValue("zstd_threads", zstd_threads);
    settings.setValue("zstd_ultra", zstd_ultra);
    
    // LZ4 parameters
    settings.setValue("lz4_level", lz4_level);
    
    // XZ parameters
    settings.setValue("xz_level", xz_level);
    settings.setValue("xz_extreme", xz_extreme);
    
    // Bzip2 parameters
    settings.setValue("bzip2_level", bzip2_level);
    
    // Gzip parameters
    settings.setValue("gzip_level", gzip_level);
    
    // Snappy setting
    settings.setValue("snappy_compress", snappy_compress);
    
    // Archive options
    settings.setValue("tar_preserve_permissions", tar_preserve_permissions);
    settings.setValue("tar_preserve_owner", tar_preserve_owner);
    settings.setValue("tar_follow_symlinks", tar_follow_symlinks);
    settings.setValue("tar_exclude_hidden", tar_exclude_hidden);
    
    // Save exclude patterns as JSON array
    if (!tar_exclude_patterns.empty()) {
        QString patterns_json = "[";
        for (int i = 0; i < tar_exclude_patterns.size(); ++i) {
            patterns_json += "\"" + QString::fromStdString(tar_exclude_patterns[i]);
            if (i < tar_exclude_patterns.size() - 1) {
                patterns_json += ",";
            }
        }
        patterns_json += "]";
        settings.setValue("tar_exclude_patterns", patterns_json);
    } else {
        settings.setValue("tar_exclude_patterns", QStringList());
    }
    
    // Encryption configuration
    settings.setValue("encryption", static_cast<int>(encryption));
    settings.setValue("salt", salt);
    
    // Auto-detection settings
    settings.setValue("auto_detect_intel_ni", auto_detect_intel_ni);
    settings.setValue("force_aes_gcm", force_aes_gcm);
    
    // Performance hints
    settings.setValue("prioritize_speed", prioritize_speed);
    settings.setValue("prioritize_compression", prioritize_compression);
    
    settings.endGroup();
}

void CompressionConfig::load(QSettings& settings) {
    settings.beginGroup("Compression");
    
    // Algorithm selection (default: ZSTD)
    int algo_int = settings.value("algorithm", 4).toInt();
    algorithm = static_cast<CompressionAlgorithm>(algo_int);
    
    // Zstd parameters
    zstd_level = settings.value("zstd_level", 3).toInt();
    zstd_threads = settings.value("zstd_threads", 0).toInt();
    zstd_ultra = settings.value("zstd_ultra", false).toBool();
    
    // LZ4 parameters
    lz4_level = settings.value("lz4_level", -1).toInt();
    
    // XZ parameters
    xz_level = settings.value("xz_level", 9).toInt();
    xz_extreme = settings.value("xz_extreme", false).toBool();
    
    // Bzip2 parameters
    bzip2_level = settings.value("bzip2_level", 9).toInt();
    
    // Gzip parameters
    gzip_level = settings.value("gzip_level", 6).toInt();
    
    // Snappy setting (default: true for logs/temp)
    snappy_compress = settings.value("snappy_compress", true).toBool();
    
    // Archive options
    tar_preserve_permissions = settings.value("tar_preserve_permissions", true).toBool();
    tar_preserve_owner = settings.value("tar_preserve_owner", true).toBool();
    tar_follow_symlinks = settings.value("tar_follow_symlinks", false).toBool();
    tar_exclude_hidden = settings.value("tar_exclude_hidden", false).toBool();
    
    // Load exclude patterns from JSON array
    QString patterns_json = settings.value("tar_exclude_patterns").toString();
    if (!patterns_json.isEmpty()) {
        QJsonParseError json_error;
        QJsonDocument doc = QJsonDocument::fromJson(patterns_json.toUtf8(), &json_error);
        if (json_error.error == QJsonParseError::NoError && doc.isArray()) {
            for (const QJsonValue& value : doc.array()) {
                tar_exclude_patterns.push_back(value.toString().toStdString());
            }
        }
    }
    
    // Encryption configuration (default: XChaCha20-Poly1305)
    int enc_int = settings.value("encryption", 1).toInt();
    encryption = static_cast<EncryptionAlgorithm>(enc_int);
    salt = settings.value("salt").toString();
    
    // Auto-detection settings
    auto_detect_intel_ni = settings.value("auto_detect_intel_ni", true).toBool();
    force_aes_gcm = settings.value("force_aes_gcm", false).toBool();
    
    // Performance hints
    prioritize_speed = settings.value("prioritize_speed", false).toBool();
    prioritize_compression = settings.value("prioritize_compression", false).toBool();
    
    settings.endGroup();
}

/**
 * @brief Build compression command for given algorithm
 */
QString CompressionConfig::build_compress_command(const QString& input_file, const QString& output_file) const {
    switch (algorithm) {
        case CompressionAlgorithm::ZSTD: {
            QString cmd = "zstd";
            cmd += QString(" -%1").arg(zstd_level);
            if (zstd_threads > 0) {
                cmd += QString(" -T%1").arg(zstd_threads);
            }
            if (zstd_ultra) {
                cmd += " --ultra";
            }
            return cmd + " -o " + output_file + " < " + input_file;
        }
        
        case CompressionAlgorithm::LZ4: {
            QString cmd = "lz4";
            if (lz4_level > 0) {
                cmd += QString(" -%1").arg(lz4_level);
            } else {
                cmd += " -f"; // Fastest mode
            }
            return cmd + " -o " + output_file + " < " + input_file;
        }
        
        case CompressionAlgorithm::SNAPPY: {
            // Use snappy filter command
            QString cmd = "snappy";
            return cmd + " -c -o " + output_file + " < " + input_file;
        }
        
        case CompressionAlgorithm::XZ: {
            QString cmd = "xz";
            if (xz_extreme) {
                cmd += " -e";
            } else {
                cmd += QString(" -%1").arg(xz_level);
            }
            return cmd + " -o " + output_file + " < " + input_file;
        }
        
        case CompressionAlgorithm::BZIP2: {
            QString cmd = "bzip2";
            cmd += QString(" -%1").arg(bzip2_level);
            return cmd + " -o " + output_file + " < " + input_file;
        }
        
        case CompressionAlgorithm::GZIP: {
            QString cmd = "gzip";
            cmd += QString(" -%1").arg(gzip_level);
            return cmd + " -c < " + input_file + " | gzip -" + QString::number(gzip_level) + " > " + output_file;
        }
        
        default:
            return ""; // No compression
    }
}

/**
 * @brief Build encryption command for given algorithm
 */
QString CompressionConfig::build_encrypt_command(const QString& input_file, const QString& output_file, 
                                                  const QString& key_hex) const {
    switch (encryption) {
        case EncryptionAlgorithm::XCHACHAPOLY1305: {
            // Use libsodium's XChaCha20-Poly1305 via sodium-cli or custom wrapper
            // For now, assume we have a wrapper script
            QString cmd = "./encrypt_xchacha.sh";
            cmd += " -i " + input_file;
            cmd += " -o " + output_file;
            if (!key_hex.isEmpty()) {
                cmd += " -k " + key_hex;
            }
            return cmd;
        }
        
        case EncryptionAlgorithm::CHACHAPOLY1305: {
            // Similar to XChaCha but with shorter nonce (12 bytes)
            QString cmd = "./encrypt_chacha.sh";
            cmd += " -i " + input_file;
            cmd += " -o " + output_file;
            if (!key_hex.isEmpty()) {
                cmd += " -k " + key_hex;
            }
            return cmd;
        }
        
        case EncryptionAlgorithm::AES_GCM_256: {
            // Use AES-GCM-256 (requires OpenSSL or similar)
            QString cmd = "openssl";
            cmd += " enc -aes-256-gcm -in " + input_file;
            cmd += " -out " + output_file;
            if (!key_hex.isEmpty()) {
                cmd += " -K " + key_hex;
            }
            return cmd;
        }
        
        default:
            return ""; // No encryption
    }
}

/**
 * @brief Detect Intel NI instructions availability
 */
bool CompressionConfig::has_intel_ni() const {
    if (!auto_detect_intel_ni) {
        return false;
    }
    
    // Check CPU flags using grep or similar
    QProcess process;
    process.start("grep", QStringList() << "-c" << "ni");
    process.waitForFinished();
    int ni_count = process.readAllStandardOutput().toInt();
    
    return ni_count > 0;
}

/**
 * @brief Get compression ratio estimate for algorithm
 */
double CompressionConfig::get_compression_ratio_estimate() const {
    switch (algorithm) {
        case CompressionAlgorithm::ZSTD:
            return prioritize_speed ? 2.5 : 4.0; // Default level 3 ~3.5x, level 19 ~4x
        
        case CompressionAlgorithm::LZ4:
            return 2.0; // Fast, lower ratio
        
        case CompressionAlgorithm::SNAPPY:
            return 2.5; // Very fast, good ratio for logs
        
        case CompressionAlgorithm::XZ:
            return xz_extreme ? 6.0 : 5.0; // Best compression
        
        case CompressionAlgorithm::BZIP2:
            return 9.0; // Good ratio, slower
        
        case CompressionAlgorithm::GZIP:
            return gzip_level == 9 ? 4.0 : 3.0; // Default level 6 ~3x
        
        default:
            return 1.0; // No compression
    }
}

/**
 * @brief Get estimated speed factor for algorithm (relative to ZSTD=1.0)
 */
double CompressionConfig::get_speed_factor() const {
    switch (algorithm) {
        case CompressionAlgorithm::LZ4:
            return 5.0; // 5x faster than ZSTD
        
        case CompressionAlgorithm::SNAPPY:
            return 8.0; // Very fast, good for logs
        
        case CompressionAlgorithm::GZIP:
            return gzip_level == 9 ? 0.3 : 0.5; // Slower than ZSTD
        
        case CompressionAlgorithm::BZIP2:
            return 0.2; // Slowest
        
        case CompressionAlgorithm::XZ:
            return xz_extreme ? 0.1 : 0.3; // Very slow
        
        case CompressionAlgorithm::ZSTD:
        default:
            return 1.0; // Baseline
    }
}

} // namespace backup
