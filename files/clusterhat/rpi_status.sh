#!/bin/bash         
                                                                           
interval=${1:-30}                        
stop=0            

while [[ $stop == 0 ]]                                             
do          
        if [[ $1 ]]  
        then
                clear 
        fi  
                               
        echo "pi - Power - Network - IP address"
        echo
        clusterhat_status=$(clusterhat status | grep ^p[0-9])
        for pi in p1 p2 p3 p4
        do
                pi_status=$(echo "$clusterhat_status" | grep ^$pi | cut -d : -f 2)
                if [[ $pi_status == "1" ]]
                then
                        power_status="$(tput setaf 2) ON$(tput sgr 0)   -"
                else
                        power_status="$(tput setaf 1)OFF$(tput sgr 0)   -"
                fi

                if [[ $pi_status == "1" ]]
                then
                        out=$(ping -w 1 -c 1 $pi.local 2> /dev/null)
                        if [[ $? -eq 0 ]]
                        then
                                ping_status="$(tput setaf 2)  UP$(tput sgr 0)    -"
                                ip_address=$(echo "$out" | grep ^PING | cut -d \( -f 2- | cut -d \) -f 1)
                        else
                                ping_status="$(tput setaf 1)DOWN$(tput sgr 0)    -"
                                ip_address="None"
                        fi
                else
                        ping_status="$(tput setaf 1)DOWN$(tput sgr 0)    -"
                        ip_address="None"
                fi

                echo "$pi - $power_status $ping_status $ip_address"
        done
        if [[ ! $1 ]]
        then
                stop=1
        else
                sleep $interval
        fi
done
