#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/home/travis/zcw/资源/prometheus_ws}"
IMAGE_NAME="${IMAGE_NAME:-prometheus:noetic-px4-v2}"
LOG_DIR_HOST="${WORKSPACE}/logs/takeoff_land_no_rc"

mkdir -p "${LOG_DIR_HOST}"
rm -f "${LOG_DIR_HOST}"/*.log

docker run --rm \
  --name prometheus_takeoff_smoke \
  --gpus all \
  -v "${WORKSPACE}:/root/prometheus_ws" \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  --privileged \
  "${IMAGE_NAME}" \
  bash -lc '
set -euo pipefail

source /opt/ros/noetic/setup.bash
source /root/prometheus_ws/devel/setup.bash
export GAZEBO_PLUGIN_PATH="${GAZEBO_PLUGIN_PATH:-}"
export GAZEBO_MODEL_PATH="${GAZEBO_MODEL_PATH:-}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
source /root/prometheus_ws/src/Prometheus_PX4/Tools/setup_gazebo.bash \
  /root/prometheus_ws/src/Prometheus_PX4 \
  /root/prometheus_ws/build/prometheus_px4

export ROS_PACKAGE_PATH=${ROS_PACKAGE_PATH}:/root/prometheus_ws/src/Prometheus_PX4:/root/prometheus_ws/src/Prometheus_PX4/Tools/sitl_gazebo

LOG_DIR=/root/prometheus_ws/logs/takeoff_land_no_rc
mkdir -p "${LOG_DIR}"

cleanup() {
  set +e
  if [[ -n "${demo_pid:-}" ]]; then kill "${demo_pid}" 2>/dev/null; fi
  if [[ -n "${control_pid:-}" ]]; then kill "${control_pid}" 2>/dev/null; fi
  if [[ -n "${sitl_pid:-}" ]]; then kill "${sitl_pid}" 2>/dev/null; fi
  wait "${demo_pid:-}" 2>/dev/null
  wait "${control_pid:-}" 2>/dev/null
  wait "${sitl_pid:-}" 2>/dev/null
}
trap cleanup EXIT

roslaunch prometheus_gazebo sitl_outdoor_1uav_P450.launch gazebo_gui:=false \
  > "${LOG_DIR}/sitl.log" 2>&1 &
sitl_pid=$!

sleep 18

roslaunch prometheus_uav_control uav_control_main_outdoor.launch joy_enable:=false location_source:=2 \
  > "${LOG_DIR}/control.log" 2>&1 &
control_pid=$!

sleep 20

rosrun prometheus_demo takeoff_land_no_rc \
  > "${LOG_DIR}/takeoff.log" 2>&1 &
demo_pid=$!

deadline=$((SECONDS + 190))
while kill -0 "${demo_pid}" 2>/dev/null; do
  if (( SECONDS > deadline )); then
    echo "TAKEOFF_DEMO_TIMEOUT" | tee "${LOG_DIR}/result.log"
    exit 124
  fi
  sleep 2
done

wait "${demo_pid}"
demo_rc=$?
echo "TAKEOFF_RC=${demo_rc}" | tee "${LOG_DIR}/result.log"

echo "====SITL_KEY===="
grep -E "Successfully spawned entity|Simulator connected|Startup script returned successfully|Got HEARTBEAT|ERROR|FATAL|Segmentation" "${LOG_DIR}/sitl.log" || true

echo "====CONTROL_KEY===="
grep -E "Switch to COMMAND_CONTROL|COMMAND_CONTROL|OFFBOARD|ARM|DISARM|failsafe|ERROR|FATAL|Unknown" "${LOG_DIR}/control.log" || true

echo "====TAKEOFF_KEY===="
grep -E "tutorial_demo|Init_Pos_Hover|UAV takeoff|Takeoff_height|UAV height|UAV Land|completed|Wait for|Unknown|error|aborted" "${LOG_DIR}/takeoff.log" || true

exit "${demo_rc}"
'
