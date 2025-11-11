#include "dvx3.hpp"
#include <iostream>
#include <fstream>
#include <filesystem>

namespace fs = std::filesystem;

int main() {
    try {
        // Create test directory
        std::string test_dir = "/tmp/simple-backup-test";
        fs::create_directories(test_dir + "/data");
        
        // Create a test file
        std::ofstream f(test_dir + "/data/test.txt");
        f << "Test content\n";
        f.close();
        
        std::cout << "Test directory: " << test_dir << std::endl;
        std::cout << "Running backup without exclusion..." << std::endl;
        
        dvx3::encrypt(
            test_dir + "/data",
            test_dir + "/backup.dvx3",
            "testpass123",
            "",
            [](uint64_t p, uint64_t t, uint64_t o) {
                std::cout << "Progress: " << p << "/" << t << " out=" << o << std::endl;
            }
        );
        
        std::cout << "Backup succeeded!" << std::endl;
        std::cout << "Archive size: " << fs::file_size(test_dir + "/backup.dvx3") << " bytes" << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}
