#!/usr/bin/ruby
## Script modified from Amazon's original for Spark 1.0.0 on EMR 3.0.3 or 3.0.4 (Hadoop 2.2.0)
## Updates guava dependency

require 'json'
require 'emr/common'
require 'digest'
require 'socket'

def run(cmd)
  if ! system(cmd) then
    raise "Command failed: #{cmd}"
  end
end

def sudo(cmd)
  run("sudo #{cmd}")
end

def println(*args)
  print *args
  puts
end

def local_ip
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily
  UDPSocket.open do |s|
    s.connect '64.233.187.99', 1
    s.addr.last
  end
  ensure
  Socket.do_not_reverse_lookup = orig
end

job_flow = Emr::JsonInfoFile.new('job-flow')
instance_info = Emr::JsonInfoFile.new('instance')

@hadoop_home="/home/hadoop"
@hadoop_apps="/home/hadoop/.versions"

@s3_spark_base_url="https://s3.amazonaws.com/elasticmapreduce/samples/spark"
@spark_url="http://d3kbcqa49mib13.cloudfront.net/spark-1.0.2-bin-hadoop2.tgz"
@spark_version="1.0.0"
@shark_version="0.9.1"
@scala_version="2.10.3"
@hadoop="hadoop2"
@local_dir= `mount`.split(' ').grep(/mnt/)[0] << "/spark/"
@hadoop_version= job_flow['hadoopVersion']
@is_master = instance_info['isMaster'].to_s == 'true'
@master_dns=job_flow['masterPrivateDnsName']
@master_ip=@is_master ? local_ip : `host #{@master_dns}`.scan(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/)[0]

def download_from_s3
  println "downloading spark from #{@spark_url}"
  sudo "curl -L --silent --show-error --fail --connect-timeout 60 --max-time 720 --retry 5 -O  #{@spark_url}"
  println "downloading shark from #{@s3_spark_base_url}/#{@spark_version}/shark-#{@shark_version}-bin-#{@hadoop}.tgz"
  sudo "curl -L --silent --show-error --fail --connect-timeout 60 --max-time 720 --retry 5 -O   #{@s3_spark_base_url}/#{@spark_version}/shark-#{@shark_version}-bin-#{@hadoop}.tgz"
  println "downloading scala from #{@s3_spark_base_url}/#{@spark_version}/scala-#{@scala_version}.tgz"
  sudo "curl -L --silent --show-error --fail --connect-timeout 60 --max-time 720 --retry 5 -O  #{@s3_spark_base_url}/#{@spark_version}/scala-#{@scala_version}.tgz"
end

def untar_all
  sudo "tar xzf  spark-1.0.2-bin-hadoop2.tgz -C #{@hadoop_apps} && rm -f spark-1.0.2-bin-hadoop2.tgz"
  sudo "tar xzf  shark-#{@shark_version}-bin-#{@hadoop}.tgz -C #{@hadoop_apps} && rm -f shark-#{@shark_version}-bin-#{@hadoop}.tgz"
  sudo "tar xzf  scala-#{@scala_version}.tgz -C #{@hadoop_apps} && rm -f scala-#{@scala_version}.tgz"
end

def create_symlinks
  sudo "ln -sf #{@hadoop_apps}/spark-1.0.2-bin-hadoop2 #{@hadoop_home}/spark"
  sudo "ln -sf #{@hadoop_apps}/shark-#{@shark_version}-bin-#{@hadoop} #{@hadoop_home}/shark"
end

def write_to_bashrc
  File.open('/home/hadoop/.bashrc','a') do |file_w|
  file_w.write("export SCALA_HOME=#{@hadoop_apps}/scala-#{@scala_version}")
  end
end

def mk_local_dir
  sudo "mkdir #{@local_dir}"
end


def update_guava
  sudo "rm -f #{@hadoop_home}/share/hadoop/common/lib/guava-11.0.2.jar"
  sudo "curl -L --silent --show-error --fail --connect-timeout 60 --max-time 720 --retry 5 -O http://search.maven.org/remotecontent?filepath=com/google/guava/guava/14.0.1/guava-14.0.1.jar"
  sudo "mv guava-14.0.1.jar #{@hadoop_home}/share/hadoop/common/lib/"
end

def create_spark_env
  lzo_jar=Dir.glob("#{@hadoop_apps}/#{@hadoop_version}/share/**/hadoop-*lzo.jar")[0]
  if lzo_jar.nil?
    then
      lzo_jar=Dir.glob("#{@hadoop_apps}/#{@hadoop_version}/share/**/hadoop-*lzo*.jar")[0]
  end    
  if lzo_jar.nil?
    println "lzo not found inside #{@hadoop_apps}/#{@hadoop_version}/share/"
  end
  File.open('/tmp/spark-env.sh','w') do |file_w|
    file_w.write("export SPARK_MASTER_IP=#{@master_ip}\n")
    file_w.write("export SCALA_HOME=#{@hadoop_apps}/scala-#{@scala_version}\n")
    file_w.write("export SPARK_LOCAL_DIRS=#{@local_dir}\n")
    file_w.write("export SPARK_CLASSPATH=\"/usr/share/aws/emr/emr-fs/lib/*:/usr/share/aws/emr/lib/*:#{@hadoop_home}/share/hadoop/common/lib/*:#{lzo_jar}\"\n")
    file_w.write("export SPARK_DAEMON_JAVA_OPTS=\"-verbose:gc -XX:+PrintGCDetails -XX:+PrintGCTimeStamps\"\n")
  end
  sudo "mv /tmp/spark-env.sh #{@hadoop_home}/spark/conf/spark-env.sh"
end

def create_spark_defaults
  File.open('/tmp/spark-defaults.conf','w') do |file_w|
    file_w.write("spark.master spark://#{@master_ip}:7077\n")
  end
  sudo "mv /tmp/spark-defaults.conf #{@hadoop_home}/spark/conf/spark-defaults.conf"

end


def create_shark_env
  File.open('/tmp/shark-env.sh','w') do |file_w|
    file_w.write("export SPARK_HOME=/home/hadoop/spark\n")
    file_w.write("export SPARK_MEM=1g\n")
    file_w.write("export SHARK_MASTER_MEM=1g\n")
    file_w.write("export _JAVA_OPTIONS=\"-Xmx2g\"\n")
    file_w.write("source /home/hadoop/spark/conf/spark-env.sh\n")
  end
  sudo "mv /tmp/shark-env.sh #{@hadoop_home}/shark/conf/shark-env.sh"
end

def copy_files_to_spark_shark
  gson_jar=Dir.glob("#{@hadoop_apps}/#{@hadoop_version}/share/hadoop/common/**/gson*jar")[0]
  aws_sdk_jar=Dir.glob("/usr/share/aws/emr/hadoop-state-pusher/**/aws-java-sdk*.jar")[0]
  core_site_xml=Dir.glob("#{@hadoop_home}/conf/**/core-site.xml")[0]
  hadoop_common_jar=Dir.glob("#{@hadoop_apps}/#{@hadoop_version}/share/hadoop/common/hadoop-common-#{@hadoop_version}.jar")[0]
  emr_metrics_jar=Dir.glob("#{@hadoop_apps}/#{@hadoop_version}/share/hadoop/common/**/EmrMetrics-*.jar")[0]
  shark_jars="#{@hadoop_home}/shark/lib_managed/jars/"
  sudo "cp #{gson_jar} #{shark_jars}"
  sudo "cp #{aws_sdk_jar} #{shark_jars}"
  sudo "cp #{emr_metrics_jar} #{shark_jars}"
  sudo "cp #{hadoop_common_jar} #{shark_jars}"

  #copy core site to spark and shark
  sudo "cp #{core_site_xml} #{@hadoop_home}/spark/conf/"
  sudo "cp #{core_site_xml} #{@hadoop_home}/shark/conf/"
end

def test_connection_with_master
  attempt=0
  until (system("nc -z #{@master_ip} 7077"))
    attempt += 1
    if attempt < 20
      then
        sleep(5)
    else
      break
    end
  end
  if attempt == 20
    then
      return false
  else
    return true
  end
end

download_from_s3
untar_all
create_symlinks
mk_local_dir
update_guava
create_spark_env
create_shark_env
create_spark_defaults
copy_files_to_spark_shark

#remove hadoop-core
hadoop_core_jar=Dir.glob("/home/hadoop/shark/lib_managed/jars/**/hadoop-core*jar")[0]
sudo "rm -rf #{hadoop_core_jar}"

if @is_master then
  sudo "#{@hadoop_home}/spark/sbin/start-master.sh"
else 
  if test_connection_with_master
    then
      sudo "#{@hadoop_home}/spark/bin/spark-class org.apache.spark.deploy.worker.Worker spark://#{@master_ip}:7077 >> /tmp/registeringWorkerLog.log 2>&1 &"
    else 
      raise RuntimeError, 'Worker not able to connect to master'
  end
end
