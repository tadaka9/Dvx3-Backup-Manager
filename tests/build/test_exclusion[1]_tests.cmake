add_test([=[Dvx3Backup.ExcludeBackupDir]=]  /home/dvx3/Scaricati/Dvx3-Backup-Manager/tests/build/test_exclusion [==[--gtest_filter=Dvx3Backup.ExcludeBackupDir]==] --gtest_also_run_disabled_tests)
set_tests_properties([=[Dvx3Backup.ExcludeBackupDir]=]  PROPERTIES DEF_SOURCE_LINE /home/dvx3/Scaricati/Dvx3-Backup-Manager/tests/test_exclusion.cpp:9 WORKING_DIRECTORY /home/dvx3/Scaricati/Dvx3-Backup-Manager/tests/build SKIP_REGULAR_EXPRESSION [==[\[  SKIPPED \]]==])
set(  test_exclusion_TESTS Dvx3Backup.ExcludeBackupDir)
