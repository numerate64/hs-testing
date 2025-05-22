#!/bin/bash
#
# HS_FIO_disk_tester.sh
# Script that uses FIO to test the performance of Anvil metadata disks, DSX local volumes, and DSX remote NFS volumes.
#
# Rev 1.0 - 
#   Initial release based on the original work by Mike Bott
#
# Rev 1.1 03/19/24 - 
#   Completed code to do Anvil metadata disk testing
#   Completed code to test hsvol0 on DSX nodes
#
# Rev 1.2 03/20/24 - 
#   Completed code to do external NFS testing
#   Completed code/menu option to clean up after NFS testing
#
# Rev 1.3 03/22/24 - 
#   Simplified the code to use salt rather than a DSX client list, needed to write output files with unique names.
#
# Rev 1.4 03/31/24 - 
#   FIO tests are now run invidually to make it easier to process later using fioplot
#   DSX test data is now compressed and copied back to the Anvil
#
# Yet to do -
#   Need scripts to make it easier to produce the fioplot images
#   Upload results to HS
#   Etc.

# Define some colors
WHITE='\033[1;37m'
YELLOW='\033[1;33m'

clear

# Need to prompt for initials/company name here so we are setup to log the test details.
echo -e "-------------------------------------------------------"
echo
read -p 'Your Initials: ' hssevar
echo
read -p 'Customer Name (shortened is fine, no spaces): ' companyvar
echo
echo -e "-------------------------------------------------------"

# Variables
DATESTAMP=$(date +"%Y%m%d_%H%M")
LOG_FILE=$hssevar-$companyvar-hs-fio-console-$DATESTAMP.log

# Function to log and display output
l_and_d() {
    echo "$1" | tee -a "/home/serviceadmin/$hssevar-$companyvar/$LOG_FILE"
}

# Create a local folder for test data
echo
echo -e "-----------------------------------------"
echo -e "Creating an output folder on the Anvil..."
echo -e "-----------------------------------------"
echo
mkdir -v /home/serviceadmin/$hssevar-$companyvar

echo
l_and_d "|---------------------------------------|"
l_and_d "| Hammerspace Cluster FIO Test Script.  |"
l_and_d "|                v1.3                   |"
l_and_d "|---------------------------------------|"
l_and_d ""
l_and_d "This script can do 3 different things:"
l_and_d "- Run FIO against the Anvil metadata disk (/pd)."
l_and_d "- Run FIO against the first DSX data volume (/hsvol0)"
l_and_d "- Run FIO against NFS volumes mapped to a DSX (external NFS storage)"
l_and_d "- When testing external NFS storage, run NFSIOSTAT on all DSX nodes for data collection."
l_and_d "- Uploads data to Hammerspace for review. - SOON"
l_and_d ""
l_and_d "Script Requirements:"
l_and_d "- If testing external NFS storage, an export that can be mounted with root access by all DSX nodes."
l_and_d "- The FIO test files, each test uses a unique test file with the destination path already supplied."
l_and_d "- The FIO test files are named anvil-metadata.fio, dsx-local.fio, and dsx-nfs.fio."
l_and_d ""
l_and_d "Reviewing the results:"
l_and_d "- If testing external NFS storage, once testing is done you should review the NFSIOSTAT performance logs."
l_and_d "- If testing Anvil metadata disks, we are waiting on Douglas to tell us what is acceptable."
l_and_d "- If testing DSX local disks, we are waiting on Douglas to tell us what is acceptable."
l_and_d ""
l_and_d "Notes:"
l_and_d "- You should repeat the Anvil metadata disk test on the passive Anvil."
l_and_d "- No additional software is needed on the Hammerspace cluster for this script to work."
l_and_d "- The script should remove the test data when done, but please verify it was done."
l_and_d ""
l_and_d "--------------------------------------------------------------------------------------"

# Test selection

PS3='Are you testing (1) DSX remote NFS volumes (2) local DSX volumes (3) Anvil Metadata volumes or (4) cleaning up from testing ? '
echo
choices=("DSX NFS Volumes" "DSX Local Volumes" "Anvil Metadata" "Test cleanup")
echo
select fav in "${choices[@]}"; do
    case $fav in
    
        "DSX NFS Volumes")

        ## NFS volume disk testing

        echo
        echo -e "-------------------------------------------------------------------------------"
        echo
        echo -e "NFS testing requires an export that grants the DSX data interfaces root access."
        echo
        echo -e "When prompted, enter the IP:/export/path in a format similar to this:"
        echo
        echo -e "\t192.168.1.100:/data/share1"
        echo
        echo -e "-------------------------------------------------------------------------------"
        echo
        read -p 'Enter the IP address and path of the NFS export: ' nfs_export
        echo
        read -p 'Enter the path and file name of the FIO test file: ' fio_file
        echo
        echo -e "-------------------------------------------------------------------------------"
        echo

        # Check if the FIO test file exists
        if [ ! -f "$fio_file" ]; then
            echo "FIO test file not found. Please provide a valid file path."
            exit 1
        fi

        # Create NFS mount points
        l_and_d ""
        l_and_d "--------------------------------"
        l_and_d "Creating the NFS mount points..."
        l_and_d "--------------------------------"
        salt -G pd-node-type:DSX cmd.run "mkdir -v /mnt/test"
        echo

        # Create the FIO test results directory on the DSX nodes
        l_and_d ""
        l_and_d "---------------------------------------------------------"
        l_and_d "Creating a FIO test results directory on the DSX nodes..."
        l_and_d "---------------------------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "mkdir -v /home/serviceadmin/$hssevar-$companyvar"
        echo

        # Copy the FIO test profile to the DSX nodes
        l_and_d ""
        l_and_d "------------------------------------------------"
        l_and_d "Copying the FIO test profile to the DSX nodes..."
        l_and_d "------------------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "scp serviceadmin@m0:$fio_file $fio_file"
        echo

        # Mount volumes from the files
        l_and_d ""
        l_and_d "-------------------------------------------"
        l_and_d "Mounting the NFS volume on the DSX nodes..."
        l_and_d "-------------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "mount -v -t nfs -o nolock $nfs_export /mnt/test"
        echo

        # Create FIO test directories
        l_and_d ""
        l_and_d "-------------------------------------------"
        l_and_d "Creating FIO test directories on the DSX..."
        l_and_d "-------------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "mkdir -v /mnt/test/fio"
        echo

        # Set up NFSIOSTAT reporting
        l_and_d ""
        l_and_d "--------------------------------------"
        l_and_d "Starting NFSIOSTAT on the DSX nodes..."
        l_and_d "--------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "nfsiostat 1 /mnt/test > /home/serviceadmin/$hssevar-$companyvar/nfsiostat-dsxnfsvol-\$HOSTNAME-$DATESTAMP.out 2>&1" &
        echo
            
        l_and_d ""
        l_and_d "-------------------------------------------------------"
        echo
        l_and_d "           Initiating DSX NFS volume testing."
        echo
        l_and_d "-------------------------------------------------------"
        l_and_d ""
        l_and_d "Running sequential read test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=seq-read --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxnfs-seqread-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""
        l_and_d "Running sequential write test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=seq-write --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxnfs-seqwrite-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""
        l_and_d "Running sequential read-write test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=seq-rw --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxnfs-seqrw-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""
        l_and_d "Running random read test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=rand-read --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxnfs-randread-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""
        l_and_d "Running random write test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=rand-write --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxnfs-randwrite-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""
        l_and_d "Running random read-write test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=rand-rw --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxnfs-randrw-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""

        # Compress the results and copy to the Anvil
        l_and_d ""
        l_and_d "Compressing the results and copying them to the Anvil"
        l_and_d ""
        salt -G 'pd-node-type:DSX' cmd.run "tar -czvf /home/serviceadmin/$hssevar-$companyvar/\$HOSTNAME-dsxnfs.tgz -C /home/serviceadmin/$hssevar-$companyvar ."
        salt -G 'pd-node-type:DSX' cmd.run "scp /home/serviceadmin/$hssevar-$companyvar/\$HOSTNAME-dsxnfs.tgz serviceadmin@m0:/home/serviceadmin/$hssevar-$companyvar/\$HOSTNAME-dsxnfs.tgz"
        l_and_d ""
        
        # Display the results file location on the DSX nodes
        l_and_d ""
        l_and_d "----------------------------------------------------------------------------------"
        l_and_d ""
        l_and_d "The compressed DSX test output was copied to the Anvil in:"
        l_and_d ""
        l_and_d "  /home/serviceadmin/$hssevar-$companyvar"
        l_and_d ""
        l_and_d "Re-run this script and choose option 4 to clean up after the test run."
        l_and_d "The test directories on the DSXs in /home/serviceadmin should be removed manually."
        l_and_d ""
        l_and_d "----------------------------------------------------------------------------------"
        echo

        break
        ;;

        "DSX Local Volumes")

        ## DSX local volume testing

        echo -e "-------------------------------------------------------------------------------"
        echo
        read -p 'Enter the path and file name of the FIO test file: ' fio_file
        echo
        echo -e "-------------------------------------------------------------------------------"
        echo

        # Check if the FIO test file exists
        if [ ! -f "$fio_file" ]; then
            echo "FIO test file not found. Please provide a valid file path."
            exit 1
        fi

        # Create the FIO test results directory on the DSX nodes
        l_and_d ""
        l_and_d "---------------------------------------------------------"
        l_and_d "Creating a FIO test results directory on the DSX nodes..."
        l_and_d "---------------------------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "mkdir -v /home/serviceadmin/$hssevar-$companyvar"
        echo

        # Copy the FIO test profile to the DSX nodes
        l_and_d ""
        l_and_d "------------------------------------------------"
        l_and_d "Copying the FIO test profile to the DSX nodes..."
        l_and_d "------------------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "scp serviceadmin@m0:$fio_file $fio_file"
        echo
        
        # Create a FIO test directory on the DSX hsvol0 volume
        l_and_d ""
        l_and_d "--------------------------------------------"
        l_and_d "Creating a FIO test directory on the DSXs..."
        l_and_d "--------------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "mkdir -v /hsvol0/fio"
        echo

        l_and_d ""
        l_and_d "-------------------------------------------------------"
        echo
        l_and_d "           Initiating DSX local volume testing."
        echo
        l_and_d "-------------------------------------------------------"
        l_and_d ""
        l_and_d "Running sequential read test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=seq-read --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxloc-seqread-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""
        l_and_d "Running sequential write test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=seq-write --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxloc-seqwrite-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""
        l_and_d "Running sequential read-write test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=seq-rw --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxloc-seqrw-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""
        l_and_d "Running random read test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=rand-read --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxloc-randread-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""
        l_and_d "Running random write test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=rand-write --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxloc-randwrite-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""
        l_and_d "Running random read-write test."
        salt -G 'pd-node-type:DSX' cmd.run "fio --output-format=json --section=rand-rw --output=/home/serviceadmin/$hssevar-$companyvar/fio-dsxloc-randrw-$HOSTNAME-$DATESTAMP.json $fio_file"
        l_and_d ""

        # Compress the results and copy to the Anvil
        l_and_d ""
        l_and_d "Compressing the results and copying them to the Anvil"
        l_and_d ""
        salt -G 'pd-node-type:DSX' cmd.run "tar -czvf /home/serviceadmin/$hssevar-$companyvar/\$HOSTNAME-dsxlocal.tgz -C /home/serviceadmin/$hssevar-$companyvar ."
        salt -G 'pd-node-type:DSX' cmd.run "scp /home/serviceadmin/$hssevar-$companyvar/\$HOSTNAME-dsxlocal.tgz serviceadmin@m0:/home/serviceadmin/$hssevar-$companyvar/\$HOSTNAME-dsxlocal.tgz"
        l_and_d ""
        
        # Display the results file location on the DSX nodes
        l_and_d ""
        l_and_d "----------------------------------------------------------------------------------"
        l_and_d ""
        l_and_d "The compressed DSX test output was copied to the Anvil in:"
        l_and_d ""
        l_and_d "  /home/serviceadmin/$hssevar-$companyvar"
        l_and_d ""
        l_and_d "Re-run this script and choose option 4 to clean up after the test run."
        l_and_d "The test directories on the DSXs in /home/serviceadmin should be removed manually."
        l_and_d ""
        l_and_d "----------------------------------------------------------------------------------"
        echo

        break
        ;;

        "Anvil Metadata")

        ## Anvil metadata disk testing

        echo
        echo -e "-------------------------------------------------------"
        echo
        read -p 'Enter the path and file name of the FIO test file: ' fio_file
        echo
        echo -e "-------------------------------------------------------"
        
        # Create a FIO test directory
        l_and_d ""
        l_and_d "--------------------------------"
        l_and_d "Creating a FIO test directory..."
        l_and_d "--------------------------------"
        mkdir -v /pd/fio
        echo

        l_and_d ""
        l_and_d "-------------------------------------------------------"
        echo
        l_and_d "           Initiating Anvil metadata disk testing."
        echo
        l_and_d "-------------------------------------------------------"
        l_and_d ""
        l_and_d "Running sequential read test."
        fio --output-format=json --section=seq-read --output=/home/serviceadmin/$hssevar-$companyvar/fio-anvilmeta-seqread-$HOSTNAME-$DATESTAMP.json $fio_file
        l_and_d ""
        l_and_d "Running sequential write test."
        fio --output-format=json --section=seq-write --output=/home/serviceadmin/$hssevar-$companyvar/fio-anvilmeta-seqwrite-$HOSTNAME-$DATESTAMP.json $fio_file
        l_and_d ""
        l_and_d "Running sequential read-write test."
        fio --output-format=json --section=seq-rw --output=/home/serviceadmin/$hssevar-$companyvar/fio-anvilmeta-seqrw-$HOSTNAME-$DATESTAMP.json $fio_file
        l_and_d ""
        l_and_d "Running random read test."
        fio --output-format=json --section=rand-read --output=/home/serviceadmin/$hssevar-$companyvar/fio-anvilmeta-randread-$HOSTNAME-$DATESTAMP.json $fio_file
        l_and_d ""
        l_and_d "Running random write test."
        fio --output-format=json --section=rand-write --output=/home/serviceadmin/$hssevar-$companyvar/fio-anvilmeta-randwrite-$HOSTNAME-$DATESTAMP.json $fio_file
        l_and_d ""
        l_and_d "Running random read-write test."
        fio --output-format=json --section=rand-rw --output=/home/serviceadmin/$hssevar-$companyvar/fio-anvilmeta-randrw-$HOSTNAME-$DATESTAMP.json $fio_file
        l_and_d ""

        # Compress the results
        l_and_d ""
        l_and_d "Compressing the results"
        l_and_d ""
        tar -czvf /home/serviceadmin/$hssevar-$companyvar/$HOSTNAME-anvilmeta.tgz -C /home/serviceadmin/$hssevar-$companyvar .
        l_and_d ""

        # Display the results file location on the Anvil
        l_and_d "----------------------------------------------------------------------------------"
        l_and_d ""
        l_and_d "The compressed test output was copied to the Anvil in:"
        l_and_d ""
        l_and_d "  /home/serviceadmin/$hssevar-$companyvar"
        l_and_d ""
        l_and_d "Re-run this script and choose option 4 to clean up after the test run."
        l_and_d "The test directories /home/serviceadmin should be removed manually."
        l_and_d ""
        l_and_d "----------------------------------------------------------------------------------"
        echo
        
        break
        ;;

        "Test cleanup")

        ## Test cleanup

        # Killing all the processes (All)
        l_and_d ""
        l_and_d "------------------------------------------"
        l_and_d "Killing the FIO and nfsiostat processes..."
        l_and_d "------------------------------------------"
        salt '*' cmd.run "killall nfsiostat"
        salt '*' cmd.run "killall fio"
        echo

        # Remove the test directory on the DSX nodes (DSX local volume tests)
        l_and_d ""
        l_and_d "---------------------------------------------------------------"
        l_and_d "Removing the FIO test files from the DSX local hsvol0 volume..."
        l_and_d "---------------------------------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "rm -rf /hsvol0/fio"
        echo

        # Erase the FIO test files (DSX NFS volume tests)
        l_and_d ""
        l_and_d "------------------------------------------------------"
        l_and_d "Removing the FIO test files from the DSX NFS volume..."
        l_and_d "------------------------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "rm -rf /mnt/test/fio"
        echo

        # Erase the FIO test files (Anvil metadata disk tests)
        l_and_d ""
        l_and_d "-----------------------------------------------------------"
        l_and_d "Removing the FIO test files from the Anvil metadata disk..."
        l_and_d "-----------------------------------------------------------"
        rm -rf /pd/fio
        echo

        # Unmount the test export (DSX NFS volume tests)
        l_and_d ""
        l_and_d "--------------------------------"
        l_and_d "Umounting the NFS test export..."
        l_and_d "--------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "umount -v /mnt/test"
        echo

        # Delete the test mount points (DSX NFS volume tests)
        l_and_d ""
        l_and_d "-------------------------------------"
        l_and_d "Deleting the NFS test mount points..."
        l_and_d "-------------------------------------"
        salt -G 'pd-node-type:DSX' cmd.run "rmdir -v /mnt/test"
        echo
        
        break
        ;;

        # Default code if an invalid menu option was selected.
        
        *) echo "Invalid option $REPLY";;
    esac
done
