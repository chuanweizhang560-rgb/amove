#!/bin/bash
source /root/prometheus_ws/scripts/env_setup.sh
rm -rf /root/.ros/sitl_amov_* 2>/dev/null || true

WORLD=/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_worlds/simple_obstacles.world

echo "Starting 4x P450 multi-UAV simulation..."
roslaunch prometheus_gazebo sitl_outdoor_4uav_P450.launch \
    gazebo_gui:=false use_sim_time:=true \
    world:=$WORLD
