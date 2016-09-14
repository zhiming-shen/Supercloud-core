#!/bin/bash

id=$1

if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    exit
fi

echo "savedefault --default=$id --once" | grub --batch
reboot

