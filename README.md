# STIG_validation
Secure Technical Implementation Guide (STIG) Validation script for Linux 

The purpose of this script is to automate as many of the STIG checks as possible.

This script is based on a specific directory structure that is used:
- Base Directory: /Sysadmin/UNIX/scripts/checks
- Eval Directory: /Sysadmin/UNIX/scripts/checks/EVAL_Files
- Log Directory: /Sysadmin/UNIX/logs/STIG/

The script reads in the evaluation files and performs checks based on how the file is interpreted.

# Purpose

This script is intended to make it easier for individuals to check and validate STIG compliance on Linux systems.  Currently it is based exclusively on the Red Hat 6 STIG, and has an interpretation of the checks for Red Hat 7.

This is specifically built in bash to ensure the maximum number of people are capable of understanding and interpeting or updating it.  In my working environment it is hard enough to find people who meet all of the basic requirements, let alone adding expectations of perl, python, or ruby scripting knowledge.  Because of this, deciding to write this in bash made the most sense.

# Updates

- 20160803: I've uploaded some of the base files to be used in the new script design, expect more to come.
- I will continue to update this script actively
- Updates will be made upon new STIG releases
- Plans for a mostly complete re-write is in progress

# Closing

Please forward any questions, comments, or suggestions to athias@protonmail.com

Protect your privacy, use <a href="http://www.protonmail.com/">protonmail</a>

Thank you!
