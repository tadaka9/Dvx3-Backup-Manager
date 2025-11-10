/**
 * dvx3.hpp - Modern C++ wrapper for libdvx3
 * 
 * RAII wrappers around the C API for encrypted archives.
 */

#pragma once

#include "dvx3.h"
#include <cstdint>
#include <string>
#include <functional>
#include <stdexcept>
#include <memory>

namespace dvx3 {

/**
 * Exception thrown on encryption/decryption errors
 */
class Exception : public std::runtime_error {
public:
    explicit Exception(const std::string& msg) : std::runtime_error(msg) {}
};

/**
 * RAII wrapper for GFile*
 */
class File {
private:
    GFile* file_;

public:
    explicit File(const std::string& path) {
        file_ = g_file_new_for_path(path.c_str());
        if (!file_) {
            throw Exception("Failed to create GFile for: " + path);
        }
    }

    ~File() {
        if (file_) {
            g_object_unref(file_);
        }
    }

    // Disable copy
    File(const File&) = delete;
    File& operator=(const File&) = delete;

    // Enable move
    File(File&& other) noexcept : file_(other.file_) {
        other.file_ = nullptr;
    }

    File& operator=(File&& other) noexcept {
        if (this != &other) {
            if (file_) g_object_unref(file_);
            file_ = other.file_;
            other.file_ = nullptr;
        }
        return *this;
    }

    GFile* get() const { return file_; }
};

/**
 * Progress callback type
 * 
 * @param processed Bytes processed so far
 * @param total Total bytes (estimate for encryption)
 * @param output_bytes Output bytes written
 */
using ProgressCallback = std::function<void(uint64_t processed, uint64_t total, uint64_t output_bytes)>;

namespace detail {
    // C callback wrapper
    struct ProgressData {
        ProgressCallback callback;
    };

    inline void progress_callback_wrapper(
        guint64 processed,
        guint64 total,
        guint64 output_bytes,
        gpointer user_data)
    {
        auto* data = static_cast<ProgressData*>(user_data);
        if (data && data->callback) {
            data->callback(processed, total, output_bytes);
        }
    }
}

/**
 * Encrypt a directory to an encrypted archive
 * 
 * @param src_dir Source directory path
 * @param out_file Output .dvx3 file path
 * @param password Encryption password
 * @param exclude_path Optional path to exclude (for in-place mode)
 * @param progress Optional progress callback
 * @throws Exception on encryption failure
 */
inline void encrypt(
    const std::string& src_dir,
    const std::string& out_file,
    const std::string& password,
    const std::string& exclude_path = "",
    ProgressCallback progress = nullptr)
{
    File src(src_dir);
    File dst(out_file);

    GError* error = nullptr;
    detail::ProgressData progress_data{progress};

    dvx3_encrypt(
        src.get(),
        dst.get(),
        password.c_str(),
        exclude_path.empty() ? nullptr : exclude_path.c_str(),
        progress ? detail::progress_callback_wrapper : nullptr,
        progress ? &progress_data : nullptr,
        &error
    );

    if (error) {
        std::string msg = error->message;
        g_error_free(error);
        throw Exception("Encryption failed: " + msg);
    }
}

/**
 * Decrypt an encrypted archive to a directory
 * 
 * @param enc_file Encrypted .dvx3 file path
 * @param dst_dir Destination directory path
 * @param password Decryption password
 * @param progress Optional progress callback
 * @throws Exception on decryption failure
 */
inline void decrypt(
    const std::string& enc_file,
    const std::string& dst_dir,
    const std::string& password,
    ProgressCallback progress = nullptr)
{
    File src(enc_file);
    File dst(dst_dir);

    GError* error = nullptr;
    detail::ProgressData progress_data{progress};

    dvx3_decrypt(
        src.get(),
        dst.get(),
        password.c_str(),
        progress ? detail::progress_callback_wrapper : nullptr,
        progress ? &progress_data : nullptr,
        &error
    );

    if (error) {
        std::string msg = error->message;
        g_error_free(error);
        throw Exception("Decryption failed: " + msg);
    }
}

/**
 * Format byte size as human-readable string
 */
inline std::string format_size(uint64_t bytes) {
    const char* units[] = {"B", "KiB", "MiB", "GiB", "TiB"};
    double value = bytes;
    int idx = 0;
    
    while (value >= 1024.0 && idx < 4) {
        value /= 1024.0;
        idx++;
    }
    
    char buf[64];
    snprintf(buf, sizeof(buf), "%.2f %s", value, units[idx]);
    return buf;
}

} // namespace dvx3
