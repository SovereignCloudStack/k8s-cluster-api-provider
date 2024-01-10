#!/bin/bash
# Defragment & backup & trim script for SCS k8s-cluster-api-provider etcd cluster.
#
# Script exits without any defragmentation/backup/trim action if:
#  - It is executed on non leader etcd member
#  - It is executed on etcd cluster with some unhealthy member
#  - It is executed on single member etcd cluster
# Conditions above could be skipped and the script execution could be forced by the optional arguments:
#  - `--force-single`
#  - `--force-unhealthy`
#  - `--force-nonleader`
#
# The defragmentation on the etcd cluster is executed as follows:
#  - Defragment the non leader etcd members first
#  - Change the leadership to the randomly selected and defragmentation completed etcd member
#  - Defragment the local (ex-leader) etcd member
# Script then backup & trim local (ex-leader) etcd member
#
# Usage: etcd-defrag.sh [--force-single] [--force-unhealthy] [--force-nonleader]

export LOG_DIR=/var/log
export ETCDCTL_API=3
ETCDCTL="etcdctl --cert /etc/kubernetes/pki/etcd/peer.crt --key /etc/kubernetes/pki/etcd/peer.key --cacert /etc/kubernetes/pki/etcd/ca.crt"

while :
do
    case "$1" in
    --force-single)
      FORCE_SINGLE=1 ;;
    --force-unhealthy)
      FORCE_UNHEALTHY=1 ;;
    --force-nonleader)
      FORCE_NONLEADER=1 ;;
    *) break;;
    esac
    shift
done

if test "$($ETCDCTL endpoint status | cut -d ',' -f 5 | tr -d [:blank:])" = "false"; then
  if test "$FORCE_NONLEADER" = "1"; then
    echo "Warning: forced defragmentation on non leader!"
  else
    echo "Exit on non leader (use --force-nonleader optional argument if you want to force defragmentation on non leader)"
    exit 0
  fi
fi

# Check health of all etcd members
while read MEMBER; do
  if test "$(echo "$MEMBER" | cut -d ' ' -f 3 | tr -d [:])" != "healthy"; then
    if test "$FORCE_UNHEALTHY" = "1"; then
      echo "Warning: forced defragmentation on unhealthy etcd member $(echo "$MEMBER" | cut -d ' ' -f 1 | tr -d [:])!"
    else
      echo "Exit on unhealthy etcd member $(echo "$MEMBER" | cut -d ' ' -f 1 | tr -d [:]) (use --force-unhealthy optional argument if you want to force defragmentation on unhealthy etcd member)"
      exit 0
    fi
  fi
done < <($ETCDCTL endpoint health --cluster)

# Get all etcd members with their endpoints, IDs, and leader status
declare -a MEMBERS
declare -i MEMBERS_LENGTH=0
while read MEMBER; do
  MEMBERS+=( "$MEMBER" )
  ((MEMBERS_LENGTH++))
done < <($ETCDCTL endpoint status --cluster)

if test "$FORCE" != "1" -a "$MEMBERS_LENGTH" = 1; then
  if test "$FORCE_SINGLE" = "1"; then
    echo "Warning: forced defragmentation on single member etcd!"
  else
    echo "Exit on single member etcd (use --force-single optional argument if you want to force defragmentation on single member etcd)"
    exit 0
  fi
fi

# Skip step-by-step defragmentation if the defragmentation on single member etcd is forced
if test -z "$FORCE_SINGLE"; then
  declare -a NON_LEADER_IDS
  declare -i NON_LEADER_IDS_LENGTH=0
  for MEMBER in "${MEMBERS[@]}"; do
    # Get member ID, endpoint, and leader status
    MEMBER_ENDPOINT=$(echo "$MEMBER" | cut -d ',' -f 1 | tr -d [:blank:])
    MEMBER_ID=$(echo "$MEMBER" | cut -d ',' -f 2 | tr -d [:blank:])
    MEMBER_IS_LEADER=$(echo "$MEMBER" | cut -d ',' -f 5 | tr -d [:blank:])
    # Defragment if $MEMBER is not the leader
    if test "$MEMBER_IS_LEADER" == "false"; then
      echo "Etcd member ${MEMBER_ENDPOINT} is not the leader, let's defrag it!"
      $ETCDCTL --endpoints="$MEMBER_ENDPOINT" defrag
      NON_LEADER_IDS+=( "$MEMBER_ID" )
      ((NON_LEADER_IDS_LENGTH++))
    fi
  done

  # Randomly pick an ID from non-leader IDs and make it a leader
  RANDOM_NON_LEADER_ID=${NON_LEADER_IDS[ $(($RANDOM % "$NON_LEADER_IDS_LENGTH")) ]}
  echo "Member ${RANDOM_NON_LEADER_ID} is becoming the leader"
  $ETCDCTL move-leader $RANDOM_NON_LEADER_ID
fi

# Defrag this ex-leader etcd member
sync
sleep 2
$ETCDCTL defrag

# Backup&trim this ex-leader etcd member
sleep 3
$ETCDCTL snapshot save /root/etcd-backup
chmod 0600 /root/etcd-backup
xz -f /root/etcd-backup
fstrim -v /var/lib/etcd