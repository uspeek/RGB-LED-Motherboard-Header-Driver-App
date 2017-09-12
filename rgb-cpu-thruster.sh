#!/bin/bash
###############################################################################
#
# RGB CPU THRUSTER
#
#   CPU load monitor with synchronized RGB & fan effect
#   D. Cerisano September 4, 2017
#   Follow msi-rgb build instructions in README
#
# Special Requirements:
#
#   Motherboard supported by github.com/nagisa/msi-rgb
#   fancontrol
#     sudo apt install lm-sensors fancontrol
#     sudo /sbin/modprobe nct6775 force_id=0xd120
#     sudo pwmconfig (choose any CASE fan,  eg. hwmon0/pwm3)
#
# To build RGB driver:
#
#    sudo apt install rustc cargo
#    cargo --cargo build --release
#
# To test from your git repo:
#
#   sudo ./rgb-cpu-thruster.sh &
#
#   CPU stress test: https://jsfiddle.net/0b2yh78j/43/
#
# To run as auto-starting system service:
#
#   sudo cp ./rgb-cpu-thruster.service /etc/systemd/system
#   sudo cp ./target/release/msi-rgb   /usr/local/bin
#   sudo cp ./rgb-cpu-thruster.sh      /usr/local/bin
#   sudo systemctl enable rgb-cpu-thruster
#   sudo systemctl start  rgb-cpu-thruster
#   
# To stop system service:
#   sudo systemctl stop rgb-cpu-thruster
#
# To disable system service:
#   sudo systemctl disable rgb-cpu-thruster
#
###############################################################################

# Graceful exit: turn off RGB effect.
  trap '$rgb_driver 0 0 0 -p; echo 0 > /sys/class/hwmon/$fan; exit 1' SIGINT SIGTERM EXIT

# FAN CONSTANTS
# The CASE fan you selected during pwmconfig - NOT the CPU fan!
  fan=hwmon0/pwm3 
  pwm_step=12
  pwm_min=85
  
# Bounce fancontrol with reliable PWM driver as of 10/2017
  sudo systemctl stop fancontrol
  sudo /sbin/modprobe nct6775 force_id=0xd120
  sudo systemctl start fancontrol

# RGB CONSTANTS
  r=dcffdebc
  g=11221111
  b=00000000
  d=4
  rgb_driver="./target/release/msi-rgb"
    
# Check if running as service
  if [ "`systemctl is-active rgb-cpu-thruster`" = "active" ] 
    then
      echo ALERT: rgb-cpu-thruster system service is active
      rgb_driver="/usr/local/bin/msi-rgb"
  fi

# MAIN LOOP
  while :
  do
    # Sample total CPU load percentage every 100ms (returns a floating point percentage)
    cpu=$(cat <(grep 'cpu ' /proc/stat) <(sleep 0.1 && grep 'cpu ' /proc/stat) | awk -v RS="" '{print (($13-$2+$15-$4)*100/($13-$2+$15-$4+$16-$5))/6.5}' )
 
    # Convert float to  RGB hex brightness levels (0-F)
    int=${cpu%.*}
    c=$(printf '%x\n' $int)
    b=$c$c$c$c$c$c$c$c
    
    # Set msi-rgb animation arrays
    # Default given here is an afterburner spectrum (amber to blue)
    # Note that the bytes are little endian, so:
    # Expected curve of 12345678 must be set as 21436587
    
    $rgb_driver $r $g $b -d $d
  
    # Sync fan to CPU load
    if [ "`systemctl is-active fancontrol`" = "active" ] 
      then
        echo $((0x$c*pwm_step+pwm_min)) > /sys/class/hwmon/$fan
    fi
  done
