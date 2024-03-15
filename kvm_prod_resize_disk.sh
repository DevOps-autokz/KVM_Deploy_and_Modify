#!/usr/bin/env bash
# Set variables:
script_path="$HOME/scripts/kvm"
log_file="${script_path}"/log_stage_disk_resize.log
. ${script_path}/.env
# prod_server_ip (should be sourced from .env file)
# prod_server_user (should be sourced from .env file)
kvm_remote=" --connect qemu+ssh://$prod_server_user@$prod_server_ip:$prod_server_port/system"

cd ${script_path}
# \e[31m  \e[107
echo -e " \e[1m\e[5m\e[41m ATTENTION!!! PRODUCTION VIRTUAL SERVER will be SHUTTED DOWN!!!\e[0m"
read -p $'\e[32mIf sure, press \e[36;1;4mEnter\e[0m \e[32mto continue. Otherwise - \e[0m \e[91;1;4mCtrl + c\e[0m \e[32mto exit\e[0m'


# Select VM from list of running VMs:
vms=($(virsh $kvm_remote list --name)) 
read -p "$(
        f=0
        for vm in "${vms[@]}" ; do echo "$((++f)): $vm" ; done
        echo -ne 'Please select a VM to resize: > '
)" selection
vm_name="${vms[$((selection-1))]}"
echo "You selected '$vm_name'"

# Set full path to VM file to variable:
vm_path=$(ssh -o StrictHostKeyChecking=no $prod_server_user@$prod_server_ip -p $prod_server_port "sudo find /var/lib/libvirt/images -type f -name ${vm_name}.qcow2")

# Set Disk New Size, ask user to input it:
[[ -n "$2" ]] && disk_new_size=$2 || read -p $'\e[96mPlease, enter new size of Disk in GB \e[0m:' disk_new_size
[[ -z ${disk_new_size} ]] && { echo -e "\e[31mPlease, start over and set the new size of Disk\e[0m" ; exit 1 ; } 

# Pre-Summary:
echo -e
textcyan=$(tput setaf 6)
textyellow=$(tput setaf 3)
echo -e "\e[32mPlease, check provided info:\e[0m"
cat << EOF
${textcyan}VM Name: ${textyellow}${vm_name} 
${textcyan}New Disk Size: ${textyellow}${disk_new_size}
EOF
read -p $'\e[32mPress \e[36;1;4mEnter\e[0m \e[32mto continue or\e[0m \e[91;1;4mCtrl+c\e[0m \e[32mto exit\e[0m' 

# Check Disk size adequacy:
[[ $disk_new_size -gt 50 ]] && \
        echo -e "\e[31mDo you really need $disk_new_size GB Disk?\e[0m" && \
        read -p $'\e[32mIf sure, press \e[36;1;4mEnter\e[0m \e[32mto continue. Otherwise - \e[0m \e[91;1;4mCtrl+c\e[0m \e[32mto exit\e[0m'

# Shutdown the VM:
virsh $kvm_remote shutdown ${vm_name}
function wait_for_vm_stop { 
	virsh $kvm_remote list  --inactive | grep ${vm_name} || \
	(echo "Wait until $vm_name' shut down..." && \
	sleep 3 && \
	wait_for_vm_stop)
}
wait_for_vm_stop

# Resize procedure:
ssh -o StrictHostKeyChecking=no $prod_server_user@$prod_server_ip -p $prod_server_port "sudo mv ${vm_path} ${vm_path}.old &&  \
	sudo qemu-img create -f qcow2  ${vm_path} ${disk_new_size}G && \
	sudo virt-resize --expand /dev/sda3 ${vm_path}.old ${vm_path} && \
	sudo rm ${vm_path}.old"

# Start the VM:
virsh $kvm_remote start $vm_name

# Report completion:
virsh $kvm_remote list --all | grep $vm_name
exec >> $log_file
echo -e "\e[92m$(date +%d-%m-%Y_%H-%M-%S) \e[0m \e[93m The Disk of: \e[0m \e[36m ${vm_name}\e[0m \e[104m Resized to: ${disk_new_size} GB\e[0m"
exit 0
