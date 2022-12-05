#!/usr/bin/env bash
# Set variables:
script_path="$HOME/scripts/kvm"
. ${script_path}/.env # source env vars for:
#  $prod_server_ip $prod_server_port $prod_server_user prod_template_vm_name $prod_prod_template_vm_ip $prod_prod_template_vm_port
log_file="${script_path}"/log_file_prod.log
echo ${prod_server_user} ${prod_server_ip} ${prod_server_port}
kvm_remote=" --connect qemu+ssh://${prod_server_user}@${prod_server_ip}:${prod_server_port}/system"
kvm_prod_server="-o StrictHostKeyChecking=no ${prod_server_user}@${prod_server_ip} -p ${prod_server_port}"

echo -e "\e[31mATTENTION!!! PRODUCTION KVM!\e[0m"

cd ${script_path}

# Set vm_name == argument #1, otherwise, ask user to input it:
[[ -n "$1" ]] && vm_name=$1 || read -p $'\e[96mPlease, enter VM Name: \e[0m' vm_name
[[ -z ${vm_name} ]] && { echo -e "\e[31mPlease, start over and set the VM Name\e[0m" ; exit 1 ; }

# Set project_name == argument #2, otherwise, ask user to input it:
if [[ -n "$2" ]] 
  then 
    project_name=$2 
  else
    echo -e "\e[96mPlease, select existing Project. Choose \"other\" for new Project...\e[0m"
    dirs=($(ssh -o StrictHostKeyChecking=no $prod_server_user@$prod_server_ip -p ${prod_server_port} "sudo ls /var/lib/libvirt/images | grep -Ev .qcow2")) && \
    read -p "$(
             f=0
             for dirname in "${dirs[@]}" ;  do echo "$((++f)): $dirname" ; done
             echo -ne 'Please type a number > '
            )" selection
    project_name="${dirs[$((selection-1))]}" && \
    echo "You selected '$project_name'" 
fi
[[ $project_name == *other* ]] && echo $project_name && \
  read -p $'\e[96mPlease, enter Project Name: \e[0m' project_name
[[ -z ${project_name} ]] && { echo -e "\e[31mPlease, start over and set the Project Name\e[0m" ; exit 1 ; }


# Set CPU (Cores) quantity  == argument #3, otherwise, ask user to input it. Default = 1:
[[ -n "$3" ]] && vm_cpu=$3 || read -p $'\e[96mPlease, enter CPU quantity \e[0m (leave blank for 1 CPU Core):' vm_cpu
#[[ -z ${vm_cpu} ]] && vm_cpu=1

# Set RAM amount  == argument #4, otherwise, ask user to input it. Default = 512 MB:
[[ -n "$4" ]] && vm_ram=$4 || read -p $'\e[96mPlease, enter RAM amount in GB \e[0m (leave blank for 512 MB):' vm_ram
[[ -z ${vm_ram} ]] && vm_ram='512 Mb'

# Set Disk amount  == argument #5, otherwise, ask user to input it. Default = 2 GB:
[[ -n "$5" ]] && vm_disk=$5 || read -p $'\e[96mPlease, enter HDD amount in GB \e[0m (leave blank for 2 GB):' vm_disk
[[ -z ${vm_disk} ]] && vm_disk=2 

# Ask user for IP of a new VM:
[[ -n "$6" ]] && vm_ip=$6 || read -p $'\e[96mPlease, enter IP address of new VM:\e[0m ' vm_ip
[[ -z ${vm_ip} ]] && { echo -e "\e[31mPlease, start over and set the VM IP address...\e[0m" ; exit 1 ; }

# Ask user for hostname of a new VM:
[[ -n "$7" ]] && vm_hostname=$7 || read -p $'\e[96mPlease, enter the Hostname of new VM: \e[0m' vm_hostname
[[ -z ${vm_hostname} ]] && { echo -e "\e[31mPlease, start over and set the VM Hostname...\e[0m" ; exit 1 ; }

# Pre-deploy check for user:
echo -e
textcyan=$(tput setaf 6)
textyellow=$(tput setaf 3)
echo -e "\e[32mPlease, check provided info:\e[0m"
cat << EOF
${textcyan}VM Name: ${textyellow}${vm_name} 
${textcyan}VM Project: ${textyellow}${project_name}
${textcyan}VM CPU Cores: ${textyellow}${vm_cpu}
${textcyan}VM RAM: ${textyellow}${vm_ram}
${textcyan}VM Disk: ${textyellow}${vm_disk}
${textcyan}IP: ${textyellow}${vm_ip}
${textcyan}Hostname: ${textyellow}${vm_hostname}
EOF
read -p $'\e[32mPress \e[36;1;4mEnter\e[0m \e[32mto continue or\e[0m \e[91;1;4mCtrl+c\e[0m \e[32mto exit\e[0m' 

# Check requested parameters of the VM for adequacy:
[[ $vm_cpu -gt 4 ]] && \
	echo -e "\e[31mDo you really need $vm_cpu CPU cores?\e[0m" && \
	read -p $'\e[32mIf sure, press \e[36;1;4mEnter\e[0m \e[32mto continue. Otherwise - \e[0m \e[91;1;4mCtrl+c\e[0m \e[32mto exit\e[0m'

[[ $vm_ram == 512* ]] &&  vm_ram=''
[[ $vm_ram -gt 12 ]] && \
	echo -e "\e[31mDo you really need $vm_ram GB RAM?\e[0m" && \
	read -p $'\e[32mIf sure, press \e[36;1;4mEnter\e[0m \e[32mto continue. Otherwise - \e[0m \e[91;1;4mCtrl+c\e[0m \e[32mto exit\e[0m'

[[ $vm_disk -gt 50 ]] && \
        echo -e "\e[31mDo you really need $vm_disk GB Disk?\e[0m" && \
        read -p $'\e[32mIf sure, press \e[36;1;4mEnter\e[0m \e[32mto continue. Otherwise - \e[0m \e[91;1;4mCtrl+c\e[0m \e[32mto exit\e[0m'

# Check if VM had been already created:
is_vm_exists=$(virsh $kvm_remote list --all | grep -ow $vm_name)
[[ -n $is_vm_exists ]] && \
	{ echo -e "\e[31mThe $vm_name is already exists...\e[0m" ; exit 1 ; }

# Create VM:
ssh $kvm_prod_server "sudo mkdir -p /var/lib/libvirt/images/$project_name"
virt-clone $kvm_remote --original=$prod_template_vm_name --name=$vm_name  --file /var/lib/libvirt/images/$project_name/$vm_name.qcow2
virsh $kvm_remote autostart $vm_name
[[ -n $vm_cpu ]] && \
	virsh $kvm_remote setvcpus $vm_name ${vm_cpu} --config --maximum && \
	virsh $kvm_remote setvcpus $vm_name ${vm_cpu} --config

# If RAM not set (512MB as in template), set kvm_setmaxmem to 5G:
[[ -z $vm_ram  ]] && \
 	virsh $kvm_remote setmaxmem $vm_name 5120M --config 
# If RAM set, set kvm_setmaxmem +4 GB: 
[[ -n $vm_ram ]] && \
	virsh $kvm_remote setmaxmem $vm_name $((${vm_ram}+4))G --config && \
	virsh $kvm_remote setmem $vm_name ${vm_ram}G --config && \
	
# Set CPU Cores:
if [[ $vm_cpu -gt 1 ]]
    then
	virsh $kvm_remote dumpxml $vm_name > $vm_name.xml
	sed -i "/<cpu mode='host-model' check='partial'\/>/a\    <topology sockets=\'1\' dies=\'1\' cores=\"$vm_cpu\" threads=\'1\'\/>\n\  </cpu>" $vm_name.xml  
	sed -i /'cpu mode'/'s/\///' $vm_name.xml
	virsh $kvm_remote define $vm_name.xml
	/usr/bin/rm $vm_name.xml
fi

# Set Disk Size:
if [[ $vm_disk -gt 2 ]] 
    then
	ssh $kvm_prod_server "sudo mv /var/lib/libvirt/images/$project_name/$vm_name.qcow2 /var/lib/libvirt/images/$project_name/$vm_name.qcow2.old && \
		sudo qemu-img create -f qcow2 /var/lib/libvirt/images/$project_name/$vm_name.qcow2 ${vm_disk}G && \
		sudo virt-resize --expand /dev/sda3 /var/lib/libvirt/images/$project_name/$vm_name.qcow2.old /var/lib/libvirt/images/$project_name/$vm_name.qcow2 && \
		sudo /usr/bin/rm /var/lib/libvirt/images/$project_name/$vm_name.qcow2.old"
fi

virsh $kvm_remote start $vm_name

function wait_for_SSH { 
	ssh -q -o StrictHostKeyChecking=no -i ~/.ssh/$prod_template_vm_ssh_key $prod_template_vm_user@194.39.67.100 -p 9198 exit || \
	(echo "Wait until $vm_name's SSH connection is available..." && \
	sleep 3 && \
	wait_for_SSH)
}
wait_for_SSH

# Set IP address and Hostname:
ssh -o StrictHostKeyChecking=no -i ~/.ssh/${prod_template_vm_ssh_key} ${prod_template_vm_user}@${prod_template_vm_ip} -p ${prod_template_vm_port} \
	"sudo sed -i s/192.168.1.98/${vm_ip}/ /etc/network/interfaces && \
	 sudo sed -i 's/192.168.1.1/192.168.2.1/g' /etc/network/interfaces && \
	 sudo setup-hostname ${vm_hostname} && sudo hostname -F /etc/hostname"

# Restart network service:
ssh -o StrictHostKeyChecking=no -i ~/.ssh/${prod_template_vm_ssh_key} ${prod_template_vm_user}@${prod_template_vm_ip} -p ${prod_template_vm_port} \
	"sudo service networking restart>&/dev/null & exit"

# Reboot new VM:
#virsh $kvm_remote reboot $vm_name

# Report to log file:
virsh $kvm_remote list --all | grep $vm_name
echo -e "\e[32mThe VM:\e[0m \e[91;1;4m${vm_name}\e[0m \e[32mcreated successfully!\e[0m"
exec >> $log_file
echo -e "\e[92m$(date +%d-%m-%Y_%H-%M-%S) \e[0m \e[93mVM: ${vm_name}\e[0m \e[36m (Hostname: ${vm_hostname}, IP: ${vm_ip})\e[0m \e[104m with: | ${vm_cpu} Core(s) | ${vm_ram} GB RAM | ${vm_disk} GB HDD | \e[0m \e[93mcreated\e[0m"
exit 0
