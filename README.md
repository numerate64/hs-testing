# hs-testing

This repository contains scripts and configuration files for benchmarking and testing the performance of Hammerspace Anvil metadata disks, DSX local volumes, and DSX remote NFS volumes using the Flexible I/O Tester (FIO).

## Contents

- `HS_FIO_client_tester.sh`: Bash script for running FIO-based performance tests across Anvil metadata disks, DSX local volumes, and DSX NFS volumes. Prompts for user initials and customer name, creates output folders, runs tests, and collects/compresses results. Intended for use on client nodes.
- `HS_FIO_disk_tester.sh`: Bash script similar to the above, with additional updates for unique directory handling and support for new cluster configurations. Provides options for running and cleaning up tests. Intended for use on disk or server nodes.
- `anvilmeta.fio`: FIO job configuration file for benchmarking Hammerspace Anvil metadata disks. Contains a set of sequential and random read/write tests. **Edit the `directory` parameter to match your Anvil setup before use.**
- `dsxloc.fio`: FIO job configuration file for benchmarking local Hammerspace DSX storage. Edit the `directory` parameter if your DSX storage path differs from the default (`/hsvol0/fio`).
- `dsxnfs.fio`: FIO job configuration file for benchmarking Hammerspace DSX mounted NFS storage. The directory is typically passed in by the test script; see script comments for details.
- `LICENSE`: Project license (MIT).

## Getting Started

### Prerequisites
- Bash shell (Linux/Unix environment)
- [fio](https://github.com/axboe/fio) installed on all test nodes
- (Optional) [fioplot](https://github.com/louwrentius/fioplot) for plotting results
- Sufficient permissions to run scripts and access storage volumes

### Usage

1. **Clone the repository:**
   ```bash
   git clone <this-repo-url>
   cd hs-testing
   ```
2. **Edit the FIO configuration files** as needed:
   - Update the `directory` fields in `anvilmeta.fio` and `dsxloc.fio` to match your environment.
3. **Run the desired script:**
   - For client-side testing: `./HS_FIO_client_tester.sh`
   - For disk/server-side testing: `./HS_FIO_disk_tester.sh`
   - Follow the prompts for initials and customer name.
4. **Collect and analyze results:**
   - Output files are saved in uniquely named folders per test run.
   - Use [fioplot](https://github.com/louwrentius/fioplot) or similar tools to visualize JSON output.

### Notes
- Both scripts use `salt` to execute commands on DSX nodes. Ensure SaltStack is installed and configured if running tests across multiple nodes.
- The scripts are designed to run FIO jobs individually for easier post-processing.
- Test cleanup options are provided to remove temporary files after testing.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Acknowledgments
- Based on original work by Mike Bott.
- See script headers for revision history and contributors.