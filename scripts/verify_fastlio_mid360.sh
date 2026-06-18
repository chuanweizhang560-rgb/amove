#!/usr/bin/env bash
# ============================================================
# FAST_LIO + P600_mid360 仿真验证脚本（分步启动，解决spawn超时）
# 使用 simple_obstacles.world（简单障碍物世界，加载快）
# ============================================================
set -euo pipefail

WORKSPACE="/home/travis/zcw/资源/prometheus_ws"
IMAGE_NAME="prometheus:noetic-px4-v3"
CONTAINER_NAME="prometheus_fastlio"
LOG_DIR_HOST="${WORKSPACE}/logs/fastlio_test"

mkdir -p "${LOG_DIR_HOST}"
rm -f "${LOG_DIR_HOST}"/*.log

echo "=== FAST_LIO + P600_mid360 仿真验证 ==="
echo "  世界: simple_obstacles.world"
echo "  日志: ${LOG_DIR_HOST}"

# 停止已有容器
sg docker -c "docker stop ${CONTAINER_NAME} 2>/dev/null && docker rm ${CONTAINER_NAME} 2>/dev/null" || true

# 允许X11
xhost +local:docker 2>/dev/null || true

# 启动容器 - 分步方式，给Gazebo充足的启动时间
sg docker -c "docker run -d --name ${CONTAINER_NAME} \
    --gpus all \
    -v ${WORKSPACE}:/root/prometheus_ws \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=${DISPLAY} \
    -e QT_X11_NO_MITSHM=1 \
    --privileged \
    ${IMAGE_NAME} bash -c '
set -euo pipefail

source /opt/ros/noetic/setup.bash
source /root/prometheus_ws/devel/setup.bash

# 关键环境设置
export GAZEBO_PLUGIN_PATH=\"\${GAZEBO_PLUGIN_PATH:-}\"
export GAZEBO_MODEL_PATH=\"\${GAZEBO_MODEL_PATH:-}\"
export LD_LIBRARY_PATH=\"\${LD_LIBRARY_PATH:-}\"
source /root/prometheus_ws/src/Prometheus_PX4/Tools/setup_gazebo.bash \
  /root/prometheus_ws/src/Prometheus_PX4 \
  /root/prometheus_ws/build/prometheus_px4

export GAZEBO_MODEL_PATH=\${GAZEBO_MODEL_PATH}:/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_models:/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_models/sensor_models:/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_models/uav_models:/root/prometheus_ws/src/Prometheus/Simulator/gazebo_simulator/gazebo_models/scene_models

export GAZEBO_PLUGIN_PATH=\${GAZEBO_PLUGIN_PATH}:/root/prometheus_ws/devel/lib
export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:/root/prometheus_ws/devel/lib
export ROS_PACKAGE_PATH=\${ROS_PACKAGE_PATH}:/root/prometheus_ws/src/Prometheus_PX4:/root/prometheus_ws/src/Prometheus_PX4/Tools/sitl_gazebo

# 清理SITL缓存
rm -rf /root/.ros/sitl_amov_* 2>/dev/null || true

LOG_DIR=/root/prometheus_ws/logs/fastlio_test

echo "=========================================="
echo "[Step 1] 启动 Gazebo + P600_mid360 SITL"
echo "=========================================="
roslaunch prometheus_gazebo sitl_outdoor_1uav_P600_mid360.launch \
    gazebo_gui:=true \
    use_sim_time:=true \
    > \${LOG_DIR}/sitl.log 2>&1 &
SITL_PID=\$!

echo "[Step 1] 等待 Gazebo 启动和模型 spawn（最多120秒）..."
for i in \$(seq 1 120); do
    if grep -q \"Successfully spawned entity\" \${LOG_DIR}/sitl.log 2>/dev/null; then
        echo \"[Step 1] ✅ 模型 spawn 成功！\"
        break
    fi
    if ! kill -0 \$SITL_PID 2>/dev/null; then
        echo \"[Step 1] ❌ SITL 进程已退出\"
        cat \${LOG_DIR}/sitl.log
        exit 1
    fi
    sleep 1
done

echo \"[Step 1] 等待 PX4 连接 Gazebo...\"
for i in \$(seq 1 60); do
    if grep -q \"Simulator connected\" \${LOG_DIR}/sitl.log 2>/dev/null; then
        echo \"[Step 1] ✅ PX4 已连接 Gazebo\"
        break
    fi
    sleep 1
done

echo \"[Step 1] 等待 MAVROS 连接...\"
for i in \$(seq 1 60); do
    if grep -q \"Got HEARTBEAT\" \${LOG_DIR}/sitl.log 2>/dev/null; then
        echo \"[Step 1] ✅ MAVROS 已连接\"
        break
    fi
    sleep 1
done

sleep 5

echo \"\"
echo \"==========================================\"
echo \"[Step 2] 检查 Livox LiDAR 话题\"
echo \"==========================================\"
source /opt/ros/noetic/setup.bash
source /root/prometheus_ws/devel/setup.bash

LIVOX_TOPICS=\$(rostopic list 2>/dev/null | grep -i livox || true)
echo \"Livox 话题: \${LIVOX_TOPICS:-无}\"

if echo \"\${LIVOX_TOPICS}\" | grep -q \"lidar\"; then
    echo \"[Step 2] ✅ Livox 话题存在\"
    # 检查数据频率
    timeout 8 rostopic hz /uav1/livox/lidar 2>&1 | tail -3 || true
else
    echo \"[Step 2] ⚠️ 未找到 Livox 话题，检查自定义话题名\"
    rostopic list 2>/dev/null | grep -E \"lidar|points|scan|cloud\" | head -10
fi

echo \"\"
echo \"==========================================\"
echo \"[Step 3] 启动 FAST_LIO\"
echo \"==========================================\"
roslaunch fast_lio mapping_mid360_gazebo.launch rviz:=false \
    > \${LOG_DIR}/fastlio.log 2>&1 &
FASTLIO_PID=\$!

sleep 10

echo \"[Step 3] 检查 FAST_LIO 输出话题...\"
FASTLIO_TOPICS=\$(rostopic list 2>/dev/null | grep -E \"mid360|cloud_registered|camera_init\" || true)
echo \"FAST_LIO 话题: \${FASTLIO_TOPICS:-无}\"

if echo \"\${FASTLIO_TOPICS}\" | grep -q \"cloud_registered\"; then
    echo \"[Step 3] ✅ FAST_LIO 全局点云话题存在\"
    timeout 8 rostopic hz /uav1/mid360_world_point 2>&1 | tail -3 || true
else
    echo \"[Step 3] ⚠️ 未找到全局点云话题\"
fi

if echo \"\${FASTLIO_TOPICS}\" | grep -q \"camera_init\"; then
    echo \"[Step 3] ✅ FAST_LIO 里程计 TF 存在\"
fi

echo \"\"
echo \"==========================================\"
echo \"[Step 4] 启动 uav_control（Gazebo定位源）\"
echo \"==========================================\"
roslaunch prometheus_uav_control uav_control_main_outdoor.launch \
    joy_enable:=false location_source:=2 \
    > \${LOG_DIR}/control.log 2>&1 &
CONTROL_PID=\$!

sleep 10

echo \"[Step 4] 检查控制状态...\"
if grep -q \"COMMAND_CONTROL\" \${LOG_DIR}/control.log 2>/dev/null; then
    echo \"[Step 4] ✅ 控制器进入 COMMAND_CONTROL\"
else
    echo \"[Step 4] 控制器状态:\"
    grep -E \"Switch to|COMMAND|OFFBOARD|error|Error\" \${LOG_DIR}/control.log 2>/dev/null | tail -5 || echo \"无输出\"
fi

echo \"\"
echo \"==========================================\"
echo \"[Step 5] 启动 mid360_to_octomap\"
echo \"==========================================\"
roslaunch prometheus_gazebo mid360_to_octomap.launch \
    > \${LOG_DIR}/octomap.log 2>&1 &
OCTOMAP_PID=\$!

sleep 10

echo \"[Step 5] 检查 Octomap 输出...\"
OCTO_TOPICS=\$(rostopic list 2>/dev/null | grep octomap || true)
echo \"Octomap 话题: \${OCTO_TOPICS:-无}\"

if echo \"\${OCTO_TOPICS}\" | grep -q \"octomap\"; then
    echo \"[Step 5] ✅ Octomap 话题存在\"
    timeout 8 rostopic hz /uav1/octomap_full 2>&1 | tail -3 || true
fi

echo \"\"
echo \"==========================================\"
echo \"=== FAST_LIO 仿真验证汇总 ===\"
echo \"==========================================\"

echo \"--- SITL 关键日志 ---\"
grep -E \"Successfully spawned|Simulator connected|Got HEARTBEAT|ERROR|FATAL\" \${LOG_DIR}/sitl.log 2>/dev/null || echo \"无\"

echo \"--- FAST_LIO 关键日志 ---\"
grep -E \"feature_extract|=====|Mapping|error|Error|warn\" \${LOG_DIR}/fastlio.log 2>/dev/null | head -15 || echo \"无\"

echo \"--- 控制器关键日志 ---\"
grep -E \"COMMAND|OFFBOARD|Switch|error\" \${LOG_DIR}/control.log 2>/dev/null | head -5 || echo \"无\"

echo \"--- Octomap 关键日志 ---\"
grep -E \"octomap|publish|error|Error\" \${LOG_DIR}/octomap.log 2>/dev/null | head -5 || echo \"无\"

echo \"\"
echo \"--- 所有 ROS 话题 ---\"
rostopic list 2>/dev/null | head -40

echo \"\"
echo \"==========================================\"
echo \"验证完成！容器保持运行，可用以下命令继续操作：\"
echo \"  进入容器: sg docker -c 'docker exec -it ${CONTAINER_NAME} bash'\"
echo \"  查看日志: sg docker -c 'docker logs -f ${CONTAINER_NAME}'\"
echo \"  停止容器: sg docker -c 'docker stop ${CONTAINER_NAME}'\"
echo \"==========================================\"

# 保持容器运行
sleep infinity
'"
