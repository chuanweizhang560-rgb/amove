#!/bin/bash
# Prometheus 通用环境设置
export DISABLE_ROS1_EOL_WARNINGS=1
export PATH=/opt/ros/noetic/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/opt/ros/noetic/lib:/opt/ros/noetic/lib/x86_64-linux-gnu:/root/prometheus_ws/devel/lib:/root/prometheus_ws/build/prometheus_px4/build_gazebo
export PYTHONPATH=/opt/ros/noetic/lib/python3/dist-packages:/root/prometheus_ws/devel/lib/python3/dist-packages
export ROS_ROOT=/opt/ros/noetic/share/ros
export ROS_PACKAGE_PATH=/opt/ros/noetic/share:/root/prometheus_ws/src:/root/prometheus_ws/src/Prometheus_PX4:/root/prometheus_ws/src/Prometheus_PX4/Tools/sitl_gazebo
export CMAKE_PREFIX_PATH=/opt/ros/noetic:/root/prometheus_ws/devel
export ROS_MASTER_URI=http://localhost:11311
export GAZEBO_MODEL_PATH=/root/prometheus_ws/src/Prometheus_PX4/Tools/sitl_gazebo/models:/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_models:/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_models/sensor_models:/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_models/uav_models:/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_models/scene_models
export GAZEBO_PLUGIN_PATH=/root/prometheus_ws/build/prometheus_px4/build_gazebo:/root/prometheus_ws/devel/lib
