#!/bin/bash

# Variables:
tps_deps_repo_url="http://nest.test.redhat.com/mnt/tpsdist/test/RHEL-8/Repos/tps-deps.repo"
tps_deps_repo_url_1="http://brew-task-repos.usersys.redhat.com/repos/scratch/lockhart/tps/2.44.27/0.git.29.19faf18/tps-2.44.27-0.git.29.19faf18-scratch.repo"
oats_rpm_url="http://nest.test.redhat.com/mnt/tpsdist/test/RHEL-8/oats-2.61-1.noarch.rpm"
#tps_rpm_url="http://nest.test.redhat.com/mnt/tpsdist/tps-devel-2.44.26-1.noarch.rpm"
tps_rpm_url="http://brew-task-repos.usersys.redhat.com/repos/scratch/lockhart/tps/2.44.27/0.git.29.19faf18/noarch/tps-devel-2.44.27-0.git.29.19faf18.noarch.rpm"
et_server="et-system-test-qe-01.usersys.redhat.com"
test_profile="tpstest-1-rhel-8"

# Install packages
dnf install wget --nogpgcheck -y
dnf install nfs-utils --nogpgcheck -y
yum install rpm-build --nogpgcheck -y
cd /etc/yum.repos.d && wget ${tps_deps_repo_url} && wget ${tps_deps_repo_url_1=}
mkdir -p /tmp/tps_rpms
cd /tmp/tps_rpms
wget ${oats_rpm_url}
wget ${tps_rpm_url}
dnf install oats*rpm tps-devel*rpm -y

# Move the tps-deps.repo out after tps packages installed, refer to
# http://post-office.corp.redhat.com/archives/tps-dev-list/2018-July/msg00013.html
mv /etc/yum.repos.d/tps-deps.repo /tmp/tps_rpms/

# Configure tps.conf
#sed -i 's/ERRATA_XMLRPC=/#ERRATA_XMLRPC=/' /etc/tpsd.conf
#sed -i "N;4iERRATA_XMLRPC='${et_server}'" /etc/tpsd.conf

# Run command get-packages to verify if tps-devel has been installed successfully
# Could return new files list for this example advs:
# https://et-system-test-qe-01.usersys.redhat.com/advisory/45121
get-packages -e 2019:47856

# Configure oats.conf
sed -i 's/ONBOOT=1/#ONBOOT=1/' /etc/sysconfig/oats.conf
echo 'ONBOOT=0' >> /etc/sysconfig/oats.conf
echo "OATS_TEST_PROFILE='${test_profile}'" >> /etc/sysconfig/oats.conf
echo 'TPSSERV_ENV=devel
export TPSSERV_ENV' >> /etc/sysconfig/oats.conf

# Do subscription
export TPSSERV_ENV=devel
oats-apply-test-profile -b -w -d -t "${test_profile}"

# Now check the log, client is doing subscription via tps-devel host(http://tps-devel.app.eng.bos.redhat.com)
# Check the client on tps-devel server, it is there with correct test_profile and no errors in log.(http://tps-devel.app.eng.bos.redhat.com/systems/2970)

# oats-config-nfs
echo "oats-config-nfs"
oats-config-nfs
oats-config-nfs

# Change to another nfs server for path  /mnt/qa/scratch, which records the test results
# Make sure the nfs server has been done, refer to doc https://docs.engineering.redhat.com/x/FGfVAg
echo "mount -v -t nfs 10.66.137.18:/web/mnt/qa/scratch /mnt/qa/scratch"
mkdir -p /mnt/qa/scratch
mount -v -t nfs 10.66.137.18:/web/mnt/qa/scratch /mnt/qa/scratch

# Identify command tps-cd
source /etc/profile.d/tps-cd.sh

# Refresh this cache file '/var/cache/tps/settings/tps_server.conf'
export TPSSERV_ENV=devel
update-tpsd-settings

# Running test
echo "running tps-cd -f 2019:47856"
tps-cd -f 2019:47856
echo "running tps 2019:47856"
pwd
tps-make-lists
yum localinstall $(tps-filter-filelist -o -u) --nogpgcheck -y
tps
