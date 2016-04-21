#!/bin/bash
################################################################################
#
# /var/RHEL_6_manual_STIG_check.bash
#	
#	This script is designed to perform the manual STIG compliance checks
#	based upon the 'Red Hat Enterprise Linux 6 Security Technical 
#	Implementation Guide' Version 1, Release 6, dated 23 JAN 2015.
#
#	NOTE:	This script must be run as root.
#
################################################################################
#
# Created by:		Matthew R. Sawyer
# Last modified by:	Matthew R. Sawyer
#
# Modification History:
#
# 20150929 sawyerm	Complete re-write of STIG validation script.  The new
#			method involves greater versatility and more
#			documentation for future modifications.  This script is
#			based on the STIG updated 23 JAN 2015.
# 20150929 sawyerm	Updated modification history to follow existing standard
#			Modified file parsing to allow anything starting with ##
#			to be ignored as a comment
#			Modified file parsing to allow blank lines to be ignored
#			as comments
# 20151009 sawyerm	Updated script to match current /local/scriptsX/STIG
#			directory to make it easier to move up enclaves
#			Removed line numbers on sections as the script is not
#			being updated as frequently
# 20151019 sawyerm	Updated script logic to include 'script' as a viable
#			option for the Eval Value - This allows a listed output
#			of failures to assist in correcting the issue
#			Updated the Eval Value notes to reflect this change
# 20152017 sawyerm	Updated script to include a pass/fail only log file for
#			ease of import into STIG Validation / POA&M Spreadsheet
# 20160104 sawyerm	Updated to meet new directory structure and include a
#			check for the appropriate OS
#			This script will can now have multiple STIG check files
#			based on the OS, and will choose the most appropriate
# 20160113 sawyerm	Removed numbering of STIG items as the evaluation file
#			comes closer to completion
# 20160204 sawyerm	Updated script to ensure it isn't currently running
#			This will prevent errors in log outputs
# 20160226 sawyerm	Updated script to include a check for the STIG version
#			and output it to the log created
#			Performed some output cleanup
#			Updated logging to output color to both Main and Host
#			logs to include special outputs
#			Updated script to end whenever errors occur in the
#			parsing of the evaluation file
# 20160303 sawyerm	Updated Script to include evaluation against RHEL 7 test
#			file - interpreted version of RHEL 6 STIG
# 20160323 sawyerm	Updated script to allow a selection between Certified or
#			Testing evaluation files
#			Added Sha512 hashing of STIG script and evaluation files
#			for verification purposes
# 20160420 sawyerm	Added redhat-release for CentOS systems
#
################################################################################
#
# Advanced Usage note
#
#	This script pulls the file defined in the variable EVAL_FILE and repeats
# checks based upon the columns.
#
#	Column 1	Rule Version (STIG ID)
#	Column 2	Group ID (VULID)
#	Column 3	Evaluation Value
#	Column 4	If True, Pass or Fail
#	Column 5	If False, Pass or Fail
#	Column 6	Command to be run as Evaluation Test
#
#	Rule Version	The STIG ID number
#	Group ID	The Vulnerability ID (VULID)
#	Eval Value	This value has several options depending upon what the
#			intended check is, while the pass or fail status is
#			determined by the True and False results identified in
#			columns 4 and 5:
#			no_value	means a pure value or no value test
#			script		is a special no_value check where an
#					output is produced if the check fails
#			(value)		Means an exact value must be matched
#	True Test	Pass or Fail, on a true result - must be opposite False
#	False Test	Pass or Fail, on a false result - must be opposite True
#	Eval Test	The series of commands used to break the test down to a
#			True or False test - All remaining characters (to
#			include spaces) are counted as part of this Eval Test
#
################################################################################
# Establish variables, logging, and prep for start of script
################################################################################

CUR_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")			# YYYYMMDD_HHmmss
CUR_HOST=`uname -n`					# Current hostname
ROOT_UID=0						# Root is always 0
ORIG_DIR=`pwd`						# Runs #pwd and saves it
MAIN_LOG_FILE=/Sysadmin/UNIX/logs/STIG/${CUR_HOST}.log	# Log file creation
HOST_LOG_FILE=/Sysadmin/UNIX/logs/systems/${CUR_HOST}/STIG_${CUR_TIMESTAMP}.log	# Log file creation
PF_LOG_FILE=/Sysadmin/UNIX/logs/STIG/PF_${CUR_HOST}.log	# Pass or Fail Log
PASS_FAIL_STATUS=""					# Pass or Fail status
CUR_COMMENT=""						# Current Comment
EVAL_FILES_DIR="/Sysadmin/UNIX/scripts/checks/EVAL_Files"	# Location of Eval File
IS_TITLE_AVAIL=0
OS_VER=0

STIG_VER=""		# Ensuring these values are null
STIG_REL=""		# Ensuring these values are null
STIG_DAY=""		# Ensuring these values are null
STIG_MON=""		# Ensuring these values are null
STIG_YEAR=""		# Ensuring these values are null
STIG_NAME=""		# Ensuring these values are null

cd /

################################################################################
# Function - End of Script cleanup
################################################################################

end_script ()
{
	sleep 1
	cd $ORIG_DIR
	exit
}

################################################################################
# Verify the script is being run by root
################################################################################

if [[ "$UID" != "$ROOT_UID" ]]
then
	printf "\n\e[0;31mERROR\e[0m\tThis script must be run as root\n"
	end_script
fi

################################################################################
# Verify OS and run appropriate Evaluation File
################################################################################

if [[ `uname -s` != "Linux" ]];then
	printf "\n\e[0;31mERROR\e[0m\tThis script does not have a valid check for non Linux systems yet!\n"
	end_script
elif [[ -n `uname -r | egrep '.el6.'` ]];then
	if [[ -n `cat /etc/redhat-release | grep 'Red Hat Enterprise Linux Server release 6'` ]];then
		OS_VER="RH6"
	else
		printf "\n\e[0;31mERROR\e[0m\tThere is a mismatch between the kernel and release versions, please investigate!\n"
		end_script
	fi
elif [[ -n `uname -r | egrep '.el7.'` ]];then
	if [[ -n `cat /etc/redhat-release | grep 'Red Hat Enterprise Linux Server release 7'` ]];then
		OS_VER="RH7"
	elif [[ -n `cat /etc/redhat-release | grep 'CentOS Linux release 7'` ]];then
		OS_VER="RH7"
	else
		printf "\n\e[0;31mERROR\e[0m\tThere is a mismatch between the kernel and release versions, please investigate!\n"
		end_script
	fi
fi

################################################################################
# Verify the script is not currently running
################################################################################

if [[ -f /tmp/STIG_test.running ]];then
	printf "\e[0;31mERROR\e[0m\tThis script is either currently running or has been prematurely stopped\n"
	printf "\e[0;31mERROR\e[0m\tDo a \"\# ps -ef | grep STIG_test.bash\" to verify it isn't running\n"
	printf "\e[0;31mERROR\e[0m\tIf it isn't running, remove the \"/tmp/STIG_test.running\" file\n"
	end_script
else
	touch /tmp/STIG_test.running
fi

################################################################################
# Evaluation or Certified
################################################################################

clear

printf "You have the choice of running the following:\n"
printf "\tC - Certified Evaluation Checks\n"
printf "\tE - Testing Evaluation Checks\n\n"
printf "Which do you choose? [C/E] "; read CE_TEST
	if [[ ${CE_TEST} =~ ([Cc])$ ]];then
		if [[ ${OS_VER} == "RH6" ]];then
			EVAL_FILE="${EVAL_FILES_DIR}/RHEL_6_TEST.certified"
		elif [[ ${OS_VER} == "RH7" ]];then
			EVAL_FILE="${EVAL_FILES_DIR}/RHEL_7_TEST.certified"
		fi
	elif [[ ${CE_TEST} =~ ([Ee])$ ]];then
		if [[ ${OS_VER} == "RH6" ]];then
			EVAL_FILE="${EVAL_FILES_DIR}/RHEL_6_TEST.testing"
		elif [[ ${OS_VER} == "RH7" ]];then
			EVAL_FILE="${EVAL_FILES_DIR}/RHEL_7_TEST.testing"
		fi
	else
	    	clear
		printf "That choice is invalid, please re-run the script and choose again.\n"
		rm /tmp/STIG_test.running
		end_script
	fi

################################################################################
# Verify Log Directories
################################################################################

if [[ ! -d /Sysadmin/UNIX/logs/systems/$CUR_HOST ]];then
	mkdir -p /Sysadmin/UNIX/logs/systems/$CUR_HOST
fi

if [[ ! -d /Sysadmin/UNIX/logs/STIG ]];then
	mkdir -p /Sysadmin/UNIX/logs/STIG
fi

################################################################################
# Pass or Fail Function
################################################################################

pass_or_fail ()
{
if [[ $IS_TITLE_AVAIL == 1 ]];then
	:
elif [[ $IS_TITLE_AVAIL == 0 ]];then
	RULE_TITLE="No title provided"
fi

if [[ $PASS_FAIL_STATUS == "START" ]];then
	if [[ -f $MAIN_LOG_FILE ]];then
		rm -f ${MAIN_LOG_FILE}
	fi
	if [[ -f $PF_LOG_FILE ]];then
		rm -f ${PF_LOG_FILE}
	fi
	# Log Main Header
	printf "\e[0;35m*********************************\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	printf "* STIG COMPLIANCE SCRIPT REPORT *\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	printf "*********************************\n\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	printf "Date:\e[0m\t$(date +"%d-%b-%y")\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	printf "\e[0;35mTime:\e[0m\t$(date +"%H:%M:%S")\n\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	# STIG Version information
	if [[ -n ${STIG_VER} ]];then
		printf "\e[0;36mReport based on ${STIG_NAME}\e[0m\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
		printf "\t\e[0;36mVersion ${STIG_VER}, Release ${STIG_REL}, Dated ${STIG_DAY} ${STIG_MON} ${STIG_YEAR}\e[0m\n\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	else
		printf "\e[0;36mNo STIG Version Reported!\e[0m\n\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	fi
	# Sha512sum of script and eval file
	printf "\e[0;36mSTIG Script location:\t/Sysadmin/UNIX/scripts/checks/STIG_test.bash\e[0m\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
		STIG_SCRIPT_HASH=`sha512sum /Sysadmin/UNIX/scripts/checks/STIG_test.bash | awk '{printf $1}'`
	printf "\e[0;36mSTIG Script Sha512\t${STIG_SCRIPT_HASH}\e[0m\n\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	printf "\e[0;36mEval File location:\t${EVAL_FILE}\e[0m\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
		EVAL_FILE_HASH=`sha512sum ${EVAL_FILE} | awk '{printf $1}'`
	printf "\e[0;36mEval File Sha512:\t${EVAL_FILE_HASH}\e[0m\n\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	# Starting Header
	printf "\e[0;35mSTIG_ID\t\tVULN_ID\t\tVUL_CAT\tPorF\tRule Title\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	printf "#######\t\t#######\t\t#######\t####\t##########\e[0m\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	# Output to Pass or Fail Log
	printf "${CUR_HOST}\n" >> $PF_LOG_FILE
elif [[ $PASS_FAIL_STATUS == "END" ]];then
	# Output to Screen
	printf "\e[0;35m#######\t\t#######\t\t#######\t####\t##########\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	printf "\nSTIG VALIDATION Completed!\nThe Main Log file is located at:\t\t${MAIN_LOG_FILE}\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	printf "The Host Log file is located at:\t\t${HOST_LOG_FILE}\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	printf "The Pass or Fail Log file is located at:\t${PF_LOG_FILE}\n\e[0m\n\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	/bin/rm -f /tmp/STIG_test.running
	end_script
elif [[ $PASS_FAIL_STATUS == "PASS" ]];then
	# Output to Screen
	printf "${STIG_ID}\t${VULN_ID}\t\tCAT ${VUL_CAT}\t\e[0;32m${PASS_FAIL_STATUS}\e[0m\t${RULE_TITLE}\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	# Output to Pass or Fail Log
	printf "${PASS_FAIL_STATUS}\n" >> $PF_LOG_FILE
elif [[ $PASS_FAIL_STATUS == "FAIL" ]];then
	# Output to Screen
	printf "${STIG_ID}\t${VULN_ID}\t\tCAT ${VUL_CAT}\t\e[0;31m${PASS_FAIL_STATUS}\e[0m\t${RULE_TITLE}\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	# Output to Pass or Fail Log
	printf "${PASS_FAIL_STATUS}\n" >> $PF_LOG_FILE
else
	# Output to Screen
	printf "\n\n\e[0;31mERROR ERROR ERROR\e[0m - PASS/FAIL test result is broke - Quitting Script\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
	end_script
fi

PASS_FAIL_STATUS=""
IS_TITLE_AVAIL=0

}

################################################################################
# STIG Evaluation function
################################################################################

stig_eval ()
{

#	Column 1	STIG_ID		Rule Version (STIG ID)
#	Column 2	VULN_ID		Group ID (VULID)
#	Column 3	VUL_CAT		Vulnerability Category (I,II,III)
#	Column 4	EVAL_VALUE	Evaluation Value
#	Column 5	EVAL_T_PF	If True, Pass or Fail
#	Column 6	EVAL_F_PF	If False, Pass or Fail
#	Column 7	EVAL_TEST	Command to be run as Evaluation Test

	STIG_ID=$1

	if [[ ${STIG_ID} == "#STIG_VER" ]];then
		STIG_VER=$2
		STIG_REL=$3
		STIG_DAY=$4
		STIG_MON=$5
		STIG_YEAR=$6
		shift 6
		STIG_NAME=$*
	elif [[ ${STIG_ID} == "#STIG_ID" ]];then
		PASS_FAIL_STATUS="START"
		pass_or_fail
	elif [[ ${STIG_ID} == "#END_OF_TESTS" ]];then
		PASS_FAIL_STATUS="END"
		pass_or_fail
	elif [[ ${STIG_ID} == "#RULE_TITLE" ]];then
		shift 1
		RULE_TITLE=$*
		IS_TITLE_AVAIL=1
	elif [[ ${STIG_ID} == "" ]];then
		:
	elif [[ ${STIG_ID} == "#" ]];then
		:
	elif [[ ${STIG_ID} = "##"* ]];then
		:
	else
		VULN_ID=$2
		VUL_CAT=$3
		EVAL_VALUE=$4
		EVAL_T_PF=$5
		EVAL_F_PF=$6
		shift 6
		EVAL_TEST=$*
		
		if [[ ${EVAL_T_PF} == "PASS" ]];then
			if [[ $EVAL_F_PF == "FAIL" ]];then
				:
			else
				printf "\n\n\e[0;31mERROR\e[0m - PASS and FAIL columns do not match in ${EVAL_FILE}\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
				end_script
			fi
		elif [[ ${EVAL_T_PF} == "FAIL" ]];then
			if [[ ${EVAL_F_PF} == "PASS" ]];then
				:
			else
				printf "\n\n\e[0;31mERROR\e[0m - PASS and FAIL columns do not match in ${EVAL_FILE}\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
				end_script
			fi
		else
			printf "\n\n\e[0;31mERROR\e[0m - PASS and FAIL columns do not match in ${EVAL_FILE}\n" | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
			end_script
		fi

		if [[ ${EVAL_VALUE} == "no_value" ]];then
			if [[ -z `eval ${EVAL_TEST}` ]];then
				PASS_FAIL_STATUS=${EVAL_T_PF}
				pass_or_fail
			else
				PASS_FAIL_STATUS=${EVAL_F_PF}
				pass_or_fail
			fi
		elif [[ ${EVAL_VALUE} == "script" ]];then
			if [[ -z `eval ${EVAL_TEST}` ]];then
				PASS_FAIL_STATUS=${EVAL_T_PF}
                                pass_or_fail
                        else
                                PASS_FAIL_STATUS=${EVAL_F_PF}
                                pass_or_fail
				eval ${EVAL_TEST} | tee -a ${MAIN_LOG_FILE} ${HOST_LOG_FILE}
                        fi
		else
			if [[ `eval ${EVAL_TEST}` == ${EVAL_VALUE} ]];then
				PASS_FAIL_STATUS=${EVAL_T_PF}
				pass_or_fail
			else
				PASS_FAIL_STATUS=${EVAL_F_PF}
				pass_or_fail
			fi
		fi
	fi
}

################################################################################
# Actually Run the script
################################################################################

clear

while read EVALUATION;do
	stig_eval ${EVALUATION}
done < ${EVAL_FILE}

################################################################################
# END OF SCRIPT
################################################################################
