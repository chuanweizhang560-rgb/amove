#!/bin/bash
source /root/prometheus_ws/scripts/env_setup.sh
rm -rf /root/.ros/sitl_amov_* 2>/dev/null || true

WORLD=/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_worlds/simple_obstacles.world

echo "Starting P450_2Dlidar (gazebo_gui:=false, rviz_enable:=false)..."
roslaunch prometheus_gazebo sitl_p450_2dlidar.launch \
    gazebo_gui:=false rviz_enable:=false use_sim_time:=true \
    world:=$WORLD
