Content-Type: multipart/mixed; boundary="===============0086047718136476635=="
MIME-Version: 1.0

--===============0086047718136476635==
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="config"

config system sdn-connector
edit AzureSDN
set type azure
end
end
config system global
set hostname ${fgt_id}
set admintimeout 120
set timezone 12
end

config system interface
edit port1
set alias public
set mode static
set ip ${Port1IP}/${public_subnet_mask}
set allowaccess ping https ssh fgfm
next
edit port2
set alias private
set mode static
set ip ${Port2IP}/${private_subnet_mask}
set allowaccess ping https ssh fgfm
next
end
config firewall address
    edit "K8S_Nodes"
        set type dynamic
        set sdn "AzureSDN"
        set filter "Subnet=k8s-microseg-subnet-k8s_master | Subnet=k8s-microseg-subnet-K8s_nodes"
    next
end
config firewall policy
    edit 0
        set name "ToOutside"
        set srcintf "port2"
        set dstintf "port1"
        set srcaddr "K8S_Nodes"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set logtraffic all
        set nat enable
    next
end

config system vdom-exception
edit 0
set object system.interface
next
edit 0
set object firewall.ippool
next
end
config router static
    edit 0
        set gateway ${fgt_external_gw}
        set device port1
    next
    edit 0
        set dst ${vnet_network}
        set gateway ${fgt_internal_gw}
        set device port2
    next
end

%{ if fgt_ssh_public_key != "" }
config system admin
    edit "${fgt_username}"
        set ssh-public-key1 "${trimspace(file(fgt_ssh_public_key))}"
    next
end
%{ endif }
%{ if fgt_config_ha }
config system ha
    set group-name AzureHA
    set mode a-p
    set hbdev port3 100
    set session-pickup enable
    set session-pickup-connectionless enable
    set ha-mgmt-status enable
    config ha-mgmt-interfaces
        edit 1
            set interface port4
            set gateway ${fgt_mgmt_gw}
        next
    end
    set override disable
    set priority ${fgt_ha_priority}
    set unicast-hb enable
    set unicast-hb-peerip ${fgt_ha_peerip}
end
%{ endif }

%{ if fgt_license_file != "" }
--===============0086047718136476635==
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="${fgt_license_file}"

${file(fgt_license_file)}

%{ endif }
--===============0086047718136476635==--
