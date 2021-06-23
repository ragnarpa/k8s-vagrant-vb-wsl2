require "yaml"

IMAGE_NAME = "ubuntu/focal64"
LB_IMAGE_NAME = "generic/alpine313"
SSH_HOST = ENV["VAGRANT_SSH_HOST"]

# IP address where SSH is listenting on a VM via port forward.
# In Windows + WSL2 environment VirtualBox binds ports on primary IP.
unless SSH_HOST
    raise "VAGRANT_SSH_HOST not set."
end

CONTROL_PLANE_LB = YAML.load_file('config/control-plane-lb.yml')
CONTROL_PLANE = YAML.load_file('config/control-plane.yml')
DATA_PLANE = YAML.load_file('config/data-plane.yml')

CONTROL_PLANE_LB_IP = CONTROL_PLANE_LB["ip"]
CONTROL_PLANE_LB_PORT = CONTROL_PLANE_LB["port"]
CONTROL_PLANE_LB_NAME = CONTROL_PLANE_LB["name"]
CONTROL_PLANE_LB_ENDPOINT = "#{CONTROL_PLANE_LB_IP}:#{CONTROL_PLANE_LB_PORT}"

POD_NETWORK_CIDR = "192.168.0.0/16"

Vagrant.configure("2") do |config|
    config.vm.provider "virtualbox" do |vm|
        vm.customize [ "modifyvm", :id, "--uart1", "off" ]
        vm.customize [ "modifyvm", :id, "--audio", "none" ]
        vm.customize [ "modifyvm", :id, "--hwvirtex", "on" ]
    end

    config.vm.define CONTROL_PLANE_LB_NAME do |lb_config|
        lb_config.vm.provider "virtualbox" do |vm|
            vm.memory = 256
            vm.cpus = 1
            vm.customize [ "modifyvm", :id, "--cpuexecutioncap", "50" ]
        end

        lb_config.vm.network "forwarded_port", guest: 22, host: 2022, id: "ssh"
        lb_config.ssh.host = SSH_HOST
        lb_config.vm.box = LB_IMAGE_NAME
        lb_config.vm.network "private_network", ip: CONTROL_PLANE_LB_IP
        lb_config.vm.hostname = CONTROL_PLANE_LB_NAME

        lb_config.vm.provision "shell", inline: "apk update && apk add python3"
        lb_config.vm.provision "ansible" do |ansible|
            ansible.playbook = "ansible/playbooks/haproxy-init.yml"
            ansible.extra_vars = {
                control_plane_lb_port: CONTROL_PLANE_LB_PORT,
                control_plane: CONTROL_PLANE
            }
        end
    end

    # Start control plane
    CONTROL_PLANE.each_with_index do |node,i|
        config.vm.define node["name"] do |node_config|
            node_config.vm.provider "virtualbox" do |vm|
                vm.memory = 2048
                vm.cpus = 2
            end

            node_config.vm.network "forwarded_port", guest: 22, host: 3022 + i, id: "ssh"
            node_config.ssh.host = SSH_HOST
            node_config.vm.box = IMAGE_NAME
            node_config.vm.network "private_network", ip: node["ip"]
            node_config.vm.network "private_network", ip: node["nlb_ip"]
            node_config.vm.hostname = node["name"]

            node_config.vm.provision "ansible" do |ansible|
                if i == 0
                    ansible.playbook = "ansible/playbooks/control-plane-init.yml"
                    ansible.extra_vars = {
                        node_ip: node["ip"],
                        node_name: node_config.vm.hostname,
                        pod_network_cidr: POD_NETWORK_CIDR,
                        control_plane_endpoint: CONTROL_PLANE_LB_ENDPOINT
                    }
                else
                    ansible.playbook = "ansible/playbooks/control-plane-join.yml"
                    ansible.extra_vars = {
                        node_ip: node["ip"],
                        control_plane_endpoint: CONTROL_PLANE_LB_ENDPOINT
                    }
                end
            end
        end
    end

    # Start workers
    DATA_PLANE.each_with_index do |node,i|
        config.vm.define node["name"] do |node_config|
            node_config.vm.provider "virtualbox" do |vm|
                vm.memory = 2048
                vm.cpus = 2
            end

            node_config.vm.network "forwarded_port", guest: 22, host: 4022 + i, id: "ssh"
            node_config.vm.box = IMAGE_NAME
            node_config.vm.network "private_network", ip: node["ip"]
            node_config.vm.network "private_network", ip: node["nlb_ip"]
            node_config.ssh.host = SSH_HOST
            node_config.vm.hostname = node["name"]

            node_config.vm.provision "ansible" do |ansible|
                ansible.playbook = "ansible/playbooks/worker-join.yml"
                ansible.extra_vars = {
                    node_ip: node["ip"],
                    control_plane_endpoint: CONTROL_PLANE_LB_ENDPOINT
                }
            end
        end
    end
end