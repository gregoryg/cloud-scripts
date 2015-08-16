#!/bin/bash
# 
# Copyright (c) 2014   Syncsort Inc.   Woodcliff Lake   New Jersey 07677
#
# Syncsort Proprietary and Confidential
#
# launchDMX-h.sh
#
# This script launches EMR cluster and DMX-h Windows EC2 instance
#
usage()
{
    cat 1>&2 <<EOT
Usage : launchDMX-h.sh [options]
   
   EMR options:
    -t INSTANCE_TYPE                The type of the instances to launch for the job flow where INSTANCE_TYPE can be m1.large or higher
    -n NUM_INSTANCES                Number of instances in the job flow
    -log_uri LOG_URI                Optional. Location in S3 to store logs from the job flow, e.g. s3n://mybucket/logs

   Windows EC2 options:
    -win_instance_type WIN_INSTANCE_TYPE     Optional. The type of DMX-h Windows AMI (default: m1.small)
    -wg WINDOWS_SECURITY_GROUP               Optional. The security group to use for Windows EC2 instance.
                                             (default: A new security group, "DMX-h Windows EC2" will be created (if not created earlier) with only RDP port open)

   Common options:
    -k KEYPAIR_NAME                 The name of your Amazon EC2 Keypair
    -kf KEYPAIR_FILE_PATH           Path to your local pem file for your EC2 key pair
    -region REGION                  Optional. The region to use (default: same region as this EC2 instance)
    -availability_zone A_Z          Optional. Specify the Availability Zone (in the same region) in which to launch the job flow and the Windows EC2 instance
    -launchType emr|windows|both    Optional. The option can launch either EMR cluster only or Windows AMI only. (default: both)
    -help                           Display this usage

   VPC options:
    -vpc VPC_ID                     Optional. The ID of the VPC
    -subnet SUBNET_IDENTIFIER       Optional. Launches a cluster in an Amazon VPC subnet

Example: 1) bash launchDMX-h.sh -t m1.large -n 2 -k mykey -kf mykey.pem -log_uri s3n://mybucket/logs/
         2) bash launchDMX-h.sh -t m1.large -n 2 -k mykey -kf mykey.pem -log_uri s3n://mybucket/logs/ -vpc vpc-1a2b3c4d -subnet subnet-f3e6ab83

EOT
}

echoMessage()
{
    echo -e "$@" | tee -a $log_file
}

echoSameLine()
{
    echo -en "$@" | tee -a $log_file
}

reportInvalidUsage()
{
    usage
    exit 1
}

reportError()
{
    echo "ERROR: $@" | tee -a $log_file
    exit 1
}

checkAmazonToolsExitCode()
{
    if [ "$1" == 255 ] || [ "$1" == 1 ]
    then
	# Error return code 255 from EMR CLI or 1 from ec2-run-instances
	echo $2 | tee -a $log_file
	exit $1
    fi
}

checkNumInstances()
{
    if [ "$1" != -1 ]
    then
	if [ $num_instances -gt "$1" ]
	then
	    reportError "This offering allows you to deploy Syncsort Ironcluster on up to $1 Hadoop EMR nodes."
	fi
    fi
}

getWindowsAmiId()
{
    if [ "$win_ami_id" != "" ]
    then
	echo "$win_ami_id"
    else
	case "$region" in
            us-east-1)
		echo "ami-954ba3fe"
		;;
            us-west-1)
		echo "ami-7daf5f39"
		;;
            us-west-2)
		echo "ami-d94f4ee9"
		;;
            sa-east-1)
		echo "ami-ef7ff2f2"
		;;
            eu-west-1)
		echo "ami-86dd9df1"
		;;
            ap-northeast-1)
		echo "ami-b860cdb8"
		;;
            ap-southeast-1)
		echo "ami-80f7f6d2"
		;;
            ap-southeast-2)
		echo "ami-f54602cf"
		;;
            eu-central-1)
		echo "ami-72b2896f"
		;;
            *)
		reportError "Invalid region ($region) is detected."
		;; 
	esac
    fi
}

getMasterPublicDnsName()
{
    master_public_dns_name=`aws emr describe-cluster --profile dmxh --cluster-id $job_id --region $region|python -c 'import json,sys; g=json.load(sys.stdin); print g["Cluster"]["MasterPublicDnsName"]'`

    echo "$master_public_dns_name" 
}

launchType="both"
instance_type=""
num_instances="0"
access_id=""
private_key=""
keypair_name=""
keypair_location=""
log_uri=""
region=""
availability_zone=""
win_instance_type="m1.small"
win_ami_id=""
win_security_group=""
log_file="launchDMX-h_$(date +%Y_%m_%d-%H-%M).log"
vpc_id=""
subnet_id=""

while [ $# -ne 0 ]; do
    case $1 in
        -t )
            instance_type="$2"
            shift 2
            ;;
        -n )
            num_instances="$2"
            shift 2
            ;;
        -a )
            access_id="$2"
            shift 2
            ;;
        -p )
            private_key="$2"
            shift 2
            ;;
        -k )
            keypair_name="$2"
            shift 2
            ;;
        -kf )
            keypair_location="$2"
            shift 2
            ;;
        -log_uri )
            log_uri="$2"
            shift 2
            ;;
        -region )
            region="$2"
            shift 2
            ;;
        -availability_zone )
            availability_zone="$2"
            shift 2
            ;;
        -win_instance_type )
            win_instance_type="$2"
            shift 2
            ;;
        -launchType )
            launchType="$2"
            shift 2
            ;;
        -wg )
            win_security_group="$2"
            shift 2
            ;;
        -win_ami_id )
            win_ami_id="$2"
            shift 2
            ;;
        -subnet )
            subnet_id="$2"
            shift 2
            ;;
        -vpc )
            vpc_id="$2"
            shift 2
            ;;
        -help )
            usage
            exit 0
            ;;
        *)
            echo Invalid argument "'$1'"
            reportInvalidUsage
            ;;
    esac
done

access_id=`aws configure get aws_access_key_id --profile dmxh`
private_key=`aws configure get aws_secret_access_key --profile dmxh`

# Common options error checking
if [ -z $access_id ]
then
    access_id=$AWS_ACCESS_KEY
fi

if [ -z $private_key ]
then
    private_key=$AWS_SECRET_KEY
fi

if [ -z $access_id ] || [ -z $private_key ]
then
    echo "Enter your AWS access key and your AWS secret access key; leave region and output format blank."
    command="aws configure --profile dmxh"
    $command
    if [ "$?" -ne 0 ]; then
	echo "the aws configure command did not run correctly.  Please assure the aws command line client is installed correctly and re-run this script."
	exit
    fi
fi

access_id=`aws configure get aws_access_key_id --profile dmxh`
private_key=`aws configure get aws_secret_access_key --profile dmxh`


if [ -z $access_id ] || [ -z $private_key ] || [ -z $keypair_name ] || [ -z $keypair_location ]
then
    reportInvalidUsage
fi

if [ ! -f $keypair_location ]
then
    reportError "Your Amazon EC2 Keypair file does not exist at $keypair_location."
fi

if [ "$launchType" != "emr" ] && [ "$launchType" != "windows" ] && [ "$launchType" != "both" ]
then
    reportError "Invalid launchType. The launchType can be one of: emr, windows, both"
fi

# Extract region through the metadata service
if [ -z $region ]
then
    availability_zone=`ec2-metadata -z |cut -d':' -f2|tr -d ' '`
    exitCode=$?
    if [ $exitCode == 0 ]
    then
        region=`echo $availabilityZone | sed s'/.$//'`
    fi
    # Default region: us-east-1
    if [ -z $region ]
    then
        reportError "Unable to detect the region using the metadata service. Please use the -region option to specify the region to use."
    fi
fi

# Launches EMR cluster
launchEMR()
{
    
    # Create default IAM roles to comply with new AWS EMR requirement
    aws emr create-default-roles --region $region --profile dmxh

    if [ -z $instance_type ]
    then 
	reportError "-t INSTANCE_TYPE option is missing."
    fi
    
    if [ $num_instances -le 0 ]
    then 
	reportError "The number of EC2 instances in the EMR cluster must be greater than zero."
    fi

    if [ $num_instances -gt 10 ]
    then 
	reportError "The number of EC2 instances in the EMR cluster must be less than ten.  To run a larger cluster please see http://community.syncsort.com/group/ironcluster"
    fi

    checkNumInstances 10
    HADOOP_VERSION="2.6.0"
    AMI_VERSION="4.0.0"
    DMX_VERSION="8.2.3"
    CLUSTER_NAME="Ironcluster EMR `date '+%Y%m%d-%T'`"
    echoMessage "\nStarting Hadoop $HADOOP_VERSION Elastic MapReduce Cluster using AMI $AMI_VERSION with $num_instances $instance_type instances (this will create additional resources in your account, for which you may incur additional charges)..."
    echoMessage "-------------------------------------------------------------------------------------"

    DMEXPRESS_BUCKET=sserpxemd
    command="aws emr create-cluster \
      --name \"$CLUSTER_NAME\" \
      --profile dmxh \
      --no-visible-to-all-users \
      --release-label emr-4.0.0 \
      --use-default-roles \
      --instance-type $instance_type \
      --instance-count $num_instances \
      --ec2-attributes KeyName=$keypair_name \
      --region $region \
      --applications Name=Hive \
      --no-auto-terminate \
      --bootstrap-actions Name='DMX-h',Path='s3://$DMEXPRESS_BUCKET/$DMX_VERSION/rpminstall.sh'"


    if [ ! -z $log_uri ]
    then
	command="$command --log-uri $log_uri"
    fi
    
    if [ ! -z $availability_zone ]
    then
	command="$command --ec2-attributes  AvailabilityZone=$availability_zone"
    fi

    if [ ! -z $subnet_id ]
    then
	command="$command --ec2-attributes  SubnetId=$subnet_id"
    fi
    
    echo $command
    job_status=`eval $command`
    exitCode=$?
    # Check for errors
    error=`echo "$job_status" | grep "Error: "`
    checkAmazonToolsExitCode $exitCode "$error"

    

    job_id=`echo "$job_status" | python -c 'import json,sys; g=json.load(sys.stdin); print g["ClusterId"]'`
    echoMessage "Created job flow $job_id"
    echoSameLine "Job flow is in "STARTING" state. Waiting for the job flow to go into the "WAITING" state..."

    # Wait for the job flow to get into "WAITING" state
    waiting_state="WAITING"
    waitingTime=0
    while [ "$job_status" != "$waiting_state" ]; do
	sleep 20s
	(( waitingTime = waitingTime + 20 ))
	
	job_status=`aws emr describe-cluster \
                      --profile dmxh \
                      --cluster-id "$job_id" \
                      --region $region 2>&1 | python -c 'import json,sys; g=json.load(sys.stdin); print g["Cluster"]["Status"]["State"]'`

	if [ "$job_status" == "FAILED" -o "$job_status" == "TERMINATED" ]
	then
            echoMessage ""
            reportError "Could not launch the EMR cluster. For more information, please refer to $job_id details in the EMR Console."
	fi
	
	if [ $waitingTime = 900 ] 
	then
	    echoMessage "\nWARNING: The job flow, $job_id has not yet entered into WAITING state. Press CTRL-C to cancel the wait."
	    echoMessage "         If you cancel the wait, the script will not be able to update the Hadoop client configuraions."
	    echoMessage "         Please terminate the job flow from the AWS Management Console if you do not wish to wait. You can start a new job flow using this script."
	fi
	echoSameLine "."
    done
    echoMessage "Done"
    
    # Retrieve the master public dns name of the job flow
    master_public_dns_name=$(getMasterPublicDnsName)

    if [ -z "$master_public_dns_name" ]
    then
	echoMessage "\nMaster Public DNS Name of the job flow could not be determined. Please check the EMR service of the AWS Management Console for the Master Public DNS Name associated with the job flow ID $job_id."
    else
	echoMessage "\nMaster Public DNS Name of the job flow, $job_id: $master_public_dns_name"
    fi

    # Update the hadoop client configs
    echoSameLine "Updating Hadoop client configuration files on the DMX-h ETL Server..."
    HADOOP_CLIENT_DIR=/etc/hadoop-2.6.0
    sudo rm -f $HADOOP_CLIENT_DIR/etc/hadoop/core-site.xml > /dev/null
    sudo rm -f $HADOOP_CLIENT_DIR/etc/hadoop/yarn-site.xml > /dev/null
    sudo cp $HADOOP_CLIENT_DIR/etc/hadoop/core-site.xml.template $HADOOP_CLIENT_DIR/etc/hadoop/core-site.xml
    sudo cp $HADOOP_CLIENT_DIR/etc/hadoop/yarn-site.xml.template $HADOOP_CLIENT_DIR/etc/hadoop/yarn-site.xml
    sudo perl -pi -e 's/MASTER_PUBLIC_DNS_NAME/'$master_public_dns_name'/g' $HADOOP_CLIENT_DIR/etc/hadoop/*.xml
    echoMessage "Done"
    
    # Create SOCKS proxy tunnel between ETL Server and the EMR job flow
    echoSameLine "Creating a SOCKS proxy tunnel between this ETL Server and the masternode in the EMR cluster..."
    aws emr socks --profile dmxh --cluster-id "$job_id" --key-pair-file "$keypair_location" --region "$region" >> $log_file 2>&1 &
    pid=$!
    sleep 3
    proxy_process=`ps -ef | grep "$pid" | grep -v grep`
    if [ -z "$proxy_process" ]
    then
	echoMessage "\nUnable to create a SOCKS proxy tunnel between this ETL Server and the masternode in the EMR cluster."
	echoMessage "Use 'ps -ef | grep ssh' to make sure that there is no other existing SOCKS proxy tunnel already running."
	echoMessage "You can start the SOCKS proxy tunnel by running: aws emr socks --profile dmxh --key-pair-file <keypair file> --cluster-id <job id> --region <region> \&"
	echoMessage "Please run the following command to setup HDFS directories once you have created the SOCKS proxy tunnel: sudo -u hadoop /home/hadoop/prepCluster.sh"
    else
	echoMessage "Done"
	
	# Create the 'hadoop' user and set its environment
	setupHadoopUser
	return_val=$?
	if [ "$return_val" == 0 ]
	then
            # Create /user and /user/hadoop directories on HDFS
            echoSameLine "Preparing the EMR cluster for 'hadoop' user..."
            sudo -u hadoop /home/hadoop/prepCluster.sh
            echoMessage "Done"
	fi
	
	echoMessage "\nThe EMR cluster with job flow $job_id is ready to be used with DMX-h Hadoop Edition."
    fi
}

# Launches DMX-h Windows EC2 instance
launchWindowsAMI()
{
    # Start Windows AMI
    echoMessage "\nStarting the DMX-h Windows EC2 instance \(this will create additional resources in your account, for which you may incur additional charges\)..."
    echoMessage "------------------------------------------"

    # Check if the group has been provided in argument
    if [ -z "$win_security_group" ]
    then
	# Create security group for Windows EC2 instance if does not exist
	DMX_WINDOWS_SECURITY_GROUP="DMX-h Windows EC2"
	describe_group_command="ec2-describe-group -O $access_id -W $private_key --region $region"
	if [ ! -z $vpc_id ]
	then
            describe_group_command="$describe_group_command --filter \"vpc-id=$vpc_id\" | grep \"GROUP\" | grep \"$DMX_WINDOWS_SECURITY_GROUP\""
	else
            describe_group_command="$describe_group_command | grep -v \"vpc-\" | grep \"GROUP\" | grep \"$DMX_WINDOWS_SECURITY_GROUP\""
	fi

	dmx_group_description=`eval $describe_group_command`
	security_group_id=`echo "$dmx_group_description" | awk -F"\t" '{print $2}'`
	group_name=`echo "$dmx_group_description" | awk -F"\t" '{print $4}'`
	if [ "$group_name" != "$DMX_WINDOWS_SECURITY_GROUP" ] 
	then
            create_security_group_command="ec2-create-group -O $access_id -W $private_key --region $region \"$DMX_WINDOWS_SECURITY_GROUP\" -d \"Security group for DMX-h Windows EC2 instance\""
            if [ ! -z $vpc_id ]
            then
		create_security_group_command="$create_security_group_command --c $vpc_id"
            fi 
            cmd=`eval $create_security_group_command`
            # check for errors
            exitCode=$?
            groupCreationError=`echo "$instance_status"`
            checkAmazonToolsExitCode $exitCode "$groupCreationError"
            security_group_id=`echo "$cmd" | awk -F"\t" '{print $2}'`
            addRemoteDesktopPortCommand="ec2-authorize -O $access_id -W $private_key --region $region $security_group_id -P tcp -p 3389"
            cmd=`eval $addRemoteDesktopPortCommand`
            # check for errors
            exitCode=$?
            groupCreationError=`echo "$instance_status"`
            checkAmazonToolsExitCode $exitCode "$groupCreationError"      
	fi
    fi

    # Retrieve Windows AMI ID based on the specified region 
    WINDOWS_AMI_ID=$(getWindowsAmiId)

    launchWindowsInstanceCommand="ec2-run-instances $WINDOWS_AMI_ID \
               -n 1 \
               -k $keypair_name \
               --instance-type $win_instance_type \
               -O $access_id \
               -W $private_key \
               --region $region \
               -g $security_group_id"

    if [ ! -z $availability_zone ]
    then
	launchWindowsInstanceCommand="$launchWindowsInstanceCommand --availability-zone $availability_zone"
    fi

    if [ ! -z $subnet_id ]
    then
	launchWindowsInstanceCommand="$launchWindowsInstanceCommand -s $subnet_id --associate-public-ip-address true"
    fi

    instance_status=`eval $launchWindowsInstanceCommand`
    exitCode=$?
    # Check for errors
    winAMIError=`echo "$instance_status"`
    checkAmazonToolsExitCode $exitCode "$winAMIError"
    instance_id=`echo "$instance_status" | grep "INSTANCE" | awk -F" " '{print $2}'`
    echoMessage "DMX-h Windows instance id: $instance_id"

    echoSameLine "Waiting for the DMX-h Windows to go into the "running" state..."
    # Use ec2-describe-instances to get the public dns of the Windows EC2 instance
    pending_state="pending"
    describe_instances_command="ec2-describe-instances -O $access_id -W $private_key --region $region $instance_id"
    if [ ! -z $vpc_id ]
    then
	describe_instances_command="$describe_instances_command --filter \"vpc-id=$vpc_id\""
    fi
    describe_instances_command="$describe_instances_command | grep \"INSTANCE\" | awk -F\" \" '{print \$4}'"
    windows_public_dns=`eval $describe_instances_command`
    while [ "$windows_public_dns" = "$pending_state" ]; do
	windows_public_dns=`eval $describe_instances_command`
    done
    echoMessage "Done"

    if [ -z "$windows_public_dns" ]
    then
	echoMessage "Public DNS Name of the DMX-h Windows instance could not be determined. Please use the EC2 dashboard of the AWS Management Console for the Public DNS Name associated with this instance ID $instance_id."
    else
	echoMessage "DMX-h Windows instance Public DNS: $windows_public_dns"
    fi

    echoMessage "\nThe DMX-h Windows instance \($instance_id\) launch has been completed successfully.\n"
}

# Create 'hadoop' user (if it does not exist) and prepare
setupHadoopUser()
{
    return_value=1
    hadoop_user=`id hadoop > /dev/null 2>&1`
    exitCode=$?
    if [ "$exitCode" != 0 ]
    then
	echoSameLine "\nCreating 'hadoop' user \('hadoop' user is required to submit Ironcluster Jobs to EMR cluster and perform HDFS operations\)..."
	add_user=`sudo useradd -m -d /home/hadoop hadoop > /dev/null 2>&1`
	exitCode=$?
	if [ "$exitCode" != 0 ]
	then
	    echoMessage "\nUnable to create 'hadoop' user. Please create 'hadoop' user using the command: sudo useradd -m -d /home/hadoop hadoop"
	    echoMessage "Once you have created 'hadoop' user, run the following commands to run the script to prepare the EMR cluster:"
	    echoMessage " sudo cp -f /home/ec2-user/HadoopUserFiles/prepCluster.sh /home/hadoop/"
	    echoMessage " sudo cp -f /home/ec2-user/HadoopUserFiles/.bashrc /home/hadoop/"
	    echoMessage " sudo chown hadoop:hadoop /home/hadoop/prepCluster.sh /home/hadoop/.bashrc"
	    echoMessage " sudo chown hadoop:hadoop -R /UCA"
	else
            echoMessage "Created 'hadoop' user"
	    echoMessage "A password must be provided for the 'hadoop' user for use with the Ironcluster service"
	    return_value=0
	fi
    else
	return_value=0 # hadoop user already exists
    fi

    if [ $return_value == 0 ]
    then
	# prep cluster by creating directories in HDFS
	if [ "$launchType" == "emr" ] || [ "$launchType" == "both" ]
	then
            echoMessage " sudo -u hadoop /home/hadoop/prepCluster.sh"
	fi

	echoMessage "Provide password for 'hadoop' user"
	change_passwd=`sudo passwd hadoop`
	exitCode=$?
	if [ "$exitCode" == 0 ]
	then
	    echoMessage ""
	    # Copy and change owner of files for 'hadoop' user
	    sudo cp -f /home/ec2-user/HadoopUserFiles/prepCluster.sh /home/hadoop/
	    sudo cp -f /home/ec2-user/HadoopUserFiles/.bashrc /home/hadoop/
	    sudo chown hadoop:hadoop /home/hadoop/prepCluster.sh /home/hadoop/.bashrc
	    sudo chown hadoop:hadoop -R /UCA
	    return_value=0
	else
	    echoMessage "Unable to change password for 'hadoop' user"
	    echoMessage "Please change password manually for use with Ironcluster service"
        fi
    fi

    return $return_value
}

# Launch EMR cluster
if [ "$launchType" == "emr" ] || [ "$launchType" == "both" ]
then
    launchEMR
fi

# Launch DMX-h Windows AMI
if [ "$launchType" == "windows" ] || [ "$launchType" == "both" ]
then
    launchWindowsAMI
fi

exit 0
