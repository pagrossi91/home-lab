#!/bin/bash
LOG="backup_$(date +%Y%m%d_%H%M%S).log"

echo "=== BACKUP STARTED: $(date) ===" | tee $LOG

# Create checksums of all files
echo "Creating source checksums..." | tee -a $LOG
find ~/homelab ~/RAIDdir -type f -exec sha256sum {} \; > /tmp/source_checksums.txt 2>&1
echo "Checksums created: $(wc -l < /tmp/source_checksums.txt) files" | tee -a $LOG

# File count before backup
SOURCE_COUNT=$(find ~/homelab ~/RAIDdir -type f | wc -l)
echo "Source file count: $SOURCE_COUNT" | tee -a $LOG

# Backup homelab
echo "Starting homelab backup: $(date)" | tee -a $LOG
rsync -avHAX --progress --stats ~/homelab/ /mnt/backup/homelab/ | tee -a $LOG

# Backup RAIDdir  
echo "Starting RAIDdir backup: $(date)" | tee -a $LOG
rsync -avHAX --progress --stats ~/RAIDdir/ /mnt/backup/RAIDdir/ | tee -a $LOG

# File count after backup
BACKUP_COUNT=$(find /mnt/backup -type f | wc -l)
echo "Backup file count: $BACKUP_COUNT" | tee -a $LOG

# File count verification
echo "=== FILE COUNT VERIFICATION ===" | tee -a $LOG
if [ $SOURCE_COUNT -eq $BACKUP_COUNT ]; then
    echo "File count verification: PASSED ($SOURCE_COUNT files)" | tee -a $LOG
else
    echo "File count verification: FAILED (Source: $SOURCE_COUNT, Backup: $BACKUP_COUNT)" | tee -a $LOG
fi

# Verify checksums
echo "Starting checksum verification: $(date)" | tee -a $LOG
cd /mnt/backup && sha256sum -c /tmp/source_checksums.txt > verification_results.txt 2>&1

# Checksum verification summary
PASSED=$(grep -c ": OK$" verification_results.txt)
FAILED=$(grep -c ": FAILED$" verification_results.txt)
echo "=== CHECKSUM VERIFICATION ===" | tee -a $LOG
echo "Checksum verification: $PASSED passed, $FAILED failed" | tee -a $LOG

# Show any failed files if verification had issues
if [ $FAILED -gt 0 ]; then
    echo "Files that failed verification:" | tee -a $LOG
    grep ": FAILED$" verification_results.txt | tee -a $LOG
fi

echo "=== BACKUP FINISHED: $(date) ===" | tee -a $LOG
