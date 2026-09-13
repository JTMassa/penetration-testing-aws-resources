#!/bin/bash
set -euo pipefail

dnf install -y amazon-cloudwatch-agent

mkdir -p /opt/pentest-tools
if ! mountpoint -q /opt/pentest-tools; then
  device="/dev/nvme1n1"
  if [[ -b "$device" ]]; then
    if ! blkid "$device" >/dev/null 2>&1; then
      mkfs -t xfs "$device"
    fi
    mount "$device" /opt/pentest-tools || true
    echo "$device /opt/pentest-tools xfs defaults,nofail 0 2" >> /etc/fstab
  fi
fi
chmod 0750 /opt/pentest-tools

%{ for tester in testers ~}
useradd --create-home --shell /bin/bash ${tester.username} 2>/dev/null || true
usermod --append --groups wheel ${tester.username}
%{ if tester.ssh_public_key != "" ~}
install -d -m 0700 -o ${tester.username} -g ${tester.username} /home/${tester.username}/.ssh
printf '%s\n' '${tester.ssh_public_key}' > /home/${tester.username}/.ssh/authorized_keys
chown ${tester.username}:${tester.username} /home/${tester.username}/.ssh/authorized_keys
chmod 0600 /home/${tester.username}/.ssh/authorized_keys
%{ endif ~}
%{ endfor ~}

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {"file_path": "/var/log/secure", "log_group_name": "${log_group_name}", "log_stream_name": "{instance_id}/secure"},
          {"file_path": "/var/log/messages", "log_group_name": "${log_group_name}", "log_stream_name": "{instance_id}/messages"},
          {"file_path": "/var/log/cloud-init-output.log", "log_group_name": "${log_group_name}", "log_stream_name": "{instance_id}/cloud-init"}
        ]
      }
    }
  }
}
CONFIG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json