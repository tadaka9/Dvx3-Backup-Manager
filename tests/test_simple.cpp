#include "dvx3.hpp"
#include <gtest/gtest.h>
#include <filesystem>
#include <fstream>

namespace fs = std::filesystem;

TEST(Dvx3Basic, EncryptDecryptRoundtrip) {
    // Create a small test directory
    std::string test_dir = "/tmp/dvx3-test-" + std::to_string(getpid());
    fs::create_directories(test_dir + "/data");
    std::ofstream f(test_dir + "/data/test.txt");
    f << "Hello world\n";
    f.close();

    std::string archive = test_dir + "/backup.dvx3";
    ASSERT_NO_THROW(dvx3::encrypt(test_dir + "/data", archive, "testpass"));
    ASSERT_TRUE(fs::exists(archive));
    std::string out_dir = test_dir + "/restore";
    ASSERT_NO_THROW(dvx3::decrypt(archive, out_dir, "testpass"));
    ASSERT_TRUE(fs::exists(out_dir + "/test.txt"));

    // Clean
    fs::remove_all(test_dir);
}
