#!/bin/bash
source /root/prometheus_ws/scripts/env_setup.sh
rm -rf /root/.ros/sitl_amov_* 2>/dev/null || true

WORLD=/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_worlds/simple_obstacles.world

echo "Starting P450 for ArUco tracking..."
roslaunch prometheus_gazebo sitl_outdoor_1uav_P450.launch \
    gazebo_gui:=false use_sim_time:=true \
    world:=$WORLD
