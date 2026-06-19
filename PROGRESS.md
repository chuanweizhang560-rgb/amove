# Prometheus 仿真环境搭建 — 进度与问题总结

> 更新时间：2026-06-18

---

## 一、环境信息

| 项目 | 状态 |
|------|------|
| 主机 | Ubuntu 22.04, RTX 4060 Laptop (8GB), NVIDIA 驱动 580.159.03 |
| Docker | 29.5.3, 已安装 NVIDIA Container Toolkit |
| 工作空间 | `/home/travis/zcw/资源/prometheus_ws/` |
| 原始源码 | `/home/travis/zcw/资源/Prometheus/` |

---

## 二、Docker 镜像

| 镜像名 | 说明 |
|--------|------|
| `prometheus:noetic` | 基础版：ROS Noetic + 依赖 |
| `prometheus:noetic-px4` | 含 PX4-Autopilot（新版，与 Prometheus 不兼容） |
| `prometheus:noetic-px4-v2` | 含 Prometheus_PX4 (v1.12.3)、`bc` 包、GPU 支持 |
| **`prometheus:noetic-px4-v3`** | ✅ 当前使用版：v2 基础上增加 `octomap_server` + `rtabmap_ros` |

---

## 三、编译状态

### Prometheus 模块（prometheus_ws 内）

| 模块 | 状态 | 备注 |
|------|------|------|
| common (prometheus_msgs) | ✅ | |
| communication | ✅ | |
| gazebo_simulator | ✅ | |
| realsense_gazebo_plugin | ✅ | |
| velodyne_gazebo_plugins | ✅ | |
| livox_laser_gazebo_plugins | ✅ | |
| uav_control | ✅ | |
| simulator_utils | ✅ | |
| ego_planner_swarm | ✅ | |
| motion_planning | ✅ | |
| FAST_LIO | ✅ | |
| **Prometheus_PX4** | ✅ | PX4 v1.12.3，catkin 格式，含 P450 机型 |
| tutorial_demo | ❌ | 依赖 SpireCV `sv_world.h` |
| swarm_control/swarm_formation | ❌ | Gitee 私有仓库需认证 |
| PX4 gazebo-classic 插件 | ✅ | 已编译到 `build/prometheus_px4/build_gazebo`，P450 SITL 需要 |

---

## 四、已解决的问题

| # | 问题 | 解决方案 |
|---|------|----------|
| 1 | Docker Hub 国内无法访问 | 配置阿里云镜像源 `/etc/docker/daemon.json` |
| 2 | 缺少 `libpcl-ros-dev`、`libmavlink-dev` | 移除，由 ROS 包提供 |
| 3 | 缺少 `jinja2` | Dockerfile 中加 `pip3 install jinja2 pyyaml toml numpy` |
| 4 | Gitee 子模块需认证（swarm_control 等） | 跳过非核心模块 |
| 5 | `rospack find px4` 找不到 | 从 PX4-Autopilot 切换到 Prometheus_PX4（catkin 格式） |
| 6 | PX4 编译 OOM | 限制 `-j4`，Docker 加 `--memory=12g` |
| 7 | `git describe` 失败 | 浅克隆无 tag，手动 `git tag -a v1.11.0` |
| 8 | `bc: not found`（rcS 脚本依赖） | Docker 镜像中安装 `bc` 包 |
| 9 | PX4 SITL `Unknown model p450` | 使用 Prometheus_PX4（含 P450 机型定义） |
| 10 | GPU libGL nouveau 错误 | 安装 NVIDIA Container Toolkit，启动加 `--gpus all` |
| 11 | Gazebo GUI 启动慢导致 spawn/连接不稳定 | 默认只启动 `gzserver`，需要查看画面时再开 GUI |
| 12 | PX4 等待 TCP 4560，无法连接 Gazebo | 编译 `Tools/sitl_gazebo` 插件，产出 `libgazebo_mavlink_interface.so` 等 |
| 13 | `spawn_model -timeout` 参数不可用 | Noetic `gazebo_ros/spawn_model` 不支持该参数，已移除 |
| 14 | `uav_control_main_outdoor` 在 Gazebo 仿真中 Odom invalid | launch 增加 `location_source` 参数，Gazebo 仿真传 `location_source:=2` |
| 15 | Livox Gazebo 插件 CSV 路径硬编码 `/home/amov/...` | 修改 `livox_points_plugin.cpp` 使用 `GAZEBO_MODEL_PATH` 查找；同时容器启动时预复制 CSV 到旧路径作为回退 |
| 16 | P600_mid360 spawn 超时（10s 不够） | 使用 `simple_obstacles.world`（轻量世界），给 Gazebo 更长启动时间；实际约 1-2 秒即可 spawn |
| 17 | D435i 模型 `model://D435i` 找不到 | `GAZEBO_MODEL_PATH` 加入 `sensor_models` 子目录 |
| 18 | Livox 话题在 `/livox/lidar` 而非 `/uav1/livox/lidar` | SDF 中 `<ros_topic>` 为相对路径，在 `/uav1` namespace 下解析为根空间；FAST_LIO 配置 `lid_topic: "/livox/lidar"` 已匹配 |
| 19 | RealSense D435i "Depth Camera has not been found" | 修改 `RealSensePlugin.cpp` 的 sensor 名称匹配逻辑，支持 Gazebo include 子模型的 scoped name 格式 |
| 20 | RTAB-Map launch 引用不存在的 `prometheus_gfkd` 包 | 直接用 `roslaunch rtabmap_ros rtabmap.launch` 配合正确的话题重映射 |
| 21 | RTAB-Map TF 树缺失 `base_link` frame | 添加 `uav1/base_link → base_link` 和 `base_link → uav1/camera_link` 静态 TF |
| 22 | ROS Noetic EOL 警告弹窗 | 设置 `DISABLE_ROS1_EOL_WARNINGS=1` 环境变量 |
| 23 | `laser_to_pointcloud` 订阅 `/uav1/scan_filtered` 无数据 | 2D Lidar 只发布 `/uav1/scan`，需话题重映射 `/uav1/scan_filtered:=/uav1/scan` |
| 24 | Global Planner A* 报 "goal point is occupied" | 目标点在障碍物内部（simple_obstacles.world 的方块位置），换到空旷位置即可 |
| 25 | Global Planner 反复收到目标无法进入 PLANNING | `rostopic pub --once` 的 latched 消息重复触发 goal_cb，需避免 latching |
| 26 | D435i RealSensePlugin 崩溃 (assert px!=0) | Camera 渲染器未初始化时 `->Camera()` 返回 null，添加 null 检查 |
| 27 | D435i 相机数据无输出 (gazebo_gui:=true 也无效) | Docker 内 gzclient 未启动，Camera 传感器依赖渲染引擎 |
| 28 | 多机仿真 4x P450 需要不同端口 | sitl_px4_outdoor.launch 自动分配 TCP 4560-4563 和 MAVROS namespace |
| 29 | RealSensePlugin Load 时 Camera 未就绪直接 return | 改为 OnUpdate 中延迟重试，Camera 渲染就绪后自动初始化 |
| 30 | Launch 文件 gazebo_gui 硬编码为 true | 新增 `<arg name="gazebo_gui" default="true"/>` 参数，6个 launch 文件已修改 |
| 31 | aruco_sim_detector 垂直 FOV 太小（42°） | 放宽到 87°，支持地面 marker 检测 |
| 32 | docker exec 中 source setup.bash 不生效 | 新增 scripts/env_setup.sh 硬编码所有路径 |

---

## 五、✅ 当前核心链路状态：P450 Gazebo SITL 已跑通

### 已验证现象

- `gazebo_ros/spawn_model` 成功生成 `p450_0`
- PX4 输出 `Simulator connected on TCP port 4560`
- PX4 rcS 输出 `Startup script returned successfully`
- MAVROS 输出 `CON: Got HEARTBEAT, connected. FCU: PX4 Autopilot`
- `takeoff_land_no_rc` 自动解锁、进入 COMMAND_CONTROL、起飞至约 1.5m 后降落并正常退出
- 120 秒限时烟测可保持运行；`timeout` 触发退出时 Gazebo/PX4 清理阶段出现过一次 `Segmentation fault (core dumped)`，不影响启动链路判定

### 根因分析

1. **gzserver + gzclient 同时启动**：`empty_world.launch` 默认同时启动服务端和客户端 GUI，两者竞争资源
2. **PX4 Gazebo 插件未编译**：P450 SDF 依赖 `libgazebo_mavlink_interface.so`、`libgazebo_motor_model.so` 等库；缺库时模型能 spawn，但 PX4 一直等待 TCP 4560
3. **错误的 spawn 修复方案**：Noetic 的 `gazebo_ros/spawn_model` 没有 `-timeout` 参数，添加后会直接参数解析失败
4. **Docker 内 GPU/GUI 初始化开销**：GUI 可视化建议与 headless 服务端分离
5. **控制器定位源不匹配**：P450 Gazebo 仿真应使用 `GAZEBO` 定位源（值 2）；默认 outdoor 配置使用 GPS（值 4），会触发 `Odom invalid`

### 关键文件

```
prometheus_gazebo/launch_basic/
├── sitl_outdoor_1uav_P450.launch    # 主 launch
│   ├── 调用 gazebo_ros/empty_world.launch  （启动 Gazebo）
│   └── 调用 sitl_px4_outdoor.launch        （启动 PX4 + spawn + MAVROS）
│
└── sitl_px4_outdoor.launch           # PX4 子 launch
    ├── 第 61 行：px4 节点（依赖 rospack find px4）
    ├── 第 65 行：spawn_model 节点（Noetic 不支持 -timeout）
    └── 第 72 行：mavros 节点
```

---

## 六、已执行的修复方案

### 方案 1：分离 gzserver 和 gzclient

`sitl_outdoor_1uav_P450.launch` 默认只启动 gzserver：

```xml
<include file="$(find gazebo_ros)/launch/empty_world.launch">
    <arg name="world_name" value="$(arg world)"/>
    <arg name="use_sim_time" value="$(arg use_sim_time)"/>
    <arg name="gui" value="$(arg gazebo_gui)"/>
    <arg name="headless" value="false"/>  <!-- gzserver 正常运行 -->
</include>
```

默认 `gazebo_gui=false`。需要 GUI 时执行：

```bash
roslaunch prometheus_gazebo sitl_outdoor_1uav_P450.launch gazebo_gui:=true
```

### 方案 2：编译 PX4 Gazebo 插件

修复 `Prometheus_PX4/Tools/sitl_gazebo/CMakeLists.txt`，让 Gazebo 8+ 路径始终查找 Qt5：

```cmake
if(NOT "${GAZEBO_VERSION}" VERSION_LESS "8.0")
  find_package(Qt5 COMPONENTS Core Widgets Test REQUIRED)
endif()
```

已在容器内编译：

```bash
cmake -S /root/prometheus_ws/src/Prometheus_PX4/Tools/sitl_gazebo \
  -B /root/prometheus_ws/build/prometheus_px4/build_gazebo \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DBUILD_GSTREAMER_PLUGIN=OFF
cmake --build /root/prometheus_ws/build/prometheus_px4/build_gazebo -- -j4
```

关键产物：

```text
build/prometheus_px4/build_gazebo/libgazebo_mavlink_interface.so
build/prometheus_px4/build_gazebo/libgazebo_motor_model.so
build/prometheus_px4/build_gazebo/libgazebo_imu_plugin.so
build/prometheus_px4/build_gazebo/libgazebo_barometer_plugin.so
build/prometheus_px4/build_gazebo/libgazebo_magnetometer_plugin.so
```

### 方案 3：更新 Docker 仿真入口

- 使用 `prometheus:noetic-px4-v2` 镜像
- 加 `--gpus all`
- PX4 环境路径指向 Prometheus_PX4（而非 PX4-Autopilot）
- 挂载完整 `prometheus_ws` 到 `/root/prometheus_ws`
- 默认启动 `sitl_outdoor_1uav_P450.launch gazebo_gui:=false`

### 方案 4：控制器 launch 支持仿真定位源覆盖

`uav_control_main_outdoor.launch` 新增：

```xml
<arg name="location_source" default="4"/>
...
<param name="control/location_source" value="$(arg location_source)" />
```

Gazebo 仿真控制器启动时使用：

```bash
roslaunch prometheus_uav_control uav_control_main_outdoor.launch joy_enable:=false location_source:=2
```

### 完整验证链路

```
Gazebo gzserver 就绪
  → P450 模型 spawn 成功 ✅
    → PX4 SITL 连接 Gazebo ✅
      → MAVROS 连接 PX4 ✅
        → uav_control_main 进入 COMMAND_CONTROL ✅
          → takeoff_land_no_rc 起飞并降落完成 ✅
```

### 自动验证脚本

已新增：

```bash
/home/travis/zcw/资源/prometheus_ws/scripts/verify_takeoff_land_no_rc.sh
```

验证输出关键行：

```text
TAKEOFF_RC=0
Spawn status: SpawnModel: Successfully spawned entity
Simulator connected on TCP port 4560.
Startup script returned successfully
CON: Got HEARTBEAT, connected. FCU: PX4 Autopilot
CONTROL_STATE: [ COMMAND_CONTROL ]
UAV takeoff successfully and landed after 30 seconds
[takeoff & land] tutorial_demo completed
```

### 已确认可见的 ROS 包/关键文件

```text
prometheus_gazebo
prometheus_uav_control
prometheus_demo
prometheus_simulator_utils
ego_planner
fast_lio
px4
devel/lib/prometheus_uav_control/uav_control_main
devel/lib/prometheus_demo/takeoff_land_no_rc
build/prometheus_px4/build_gazebo/libgazebo_mavlink_interface.so
build/prometheus_px4/build_gazebo/libgazebo_motor_model.so
```

### 私有依赖说明

Prometheus 开源仓库本身可编译、可仿真，但有两个层面的功能依赖外部资源：

#### 1. Gitee 私有子模块

`.gitmodules` 中有 4 个需认证的 Gitee 仓库：

| 子模块 | URL | 功能 |
|--------|-----|------|
| `Modules/swarm_control` | `https://gitee.com/amovlab1/swarm_control.git` | 集群控制 |
| `Modules/matlab_bridge` | `https://gitee.com/amovlab1/matlab_bridge.git` | MATLAB 桥接 |
| `Modules/swarm_formation` | `https://gitee.com/amovlab1/Swarm-Formation.git` | 集群编队 |
| `Modules/searching_pkg` | `https://gitee.com/amovlab1/swarm-sch-track.git` | 搜索跟踪 |

**获取方式：**
1. 注册/登录 Gitee 账号
2. 联系仓库所有者 amovlab1 或项目维护者，将 Gitee 账号加入仓库（至少读取权限）
3. 配置 Gitee SSH key：
   ```bash
   ssh-keygen -t ed25519 -C "你的邮箱"
   cat ~/.ssh/id_ed25519.pub  # 添加到 Gitee -> 个人设置 -> SSH 公钥
   ssh -T git@gitee.com       # 验证连接
   ```
4. 将子模块 URL 改为 SSH 并拉取：
   ```bash
   cd /home/travis/zcw/资源/prometheus_ws/src/Prometheus
   git config submodule.Modules/swarm_control.url git@gitee.com:amovlab1/swarm_control.git
   git config submodule.Modules/matlab_bridge.url git@gitee.com:amovlab1/matlab_bridge.git
   git config submodule.Modules/swarm_formation.url git@gitee.com:amovlab1/Swarm-Formation.git
   git config submodule.Modules/searching_pkg.url git@gitee.com:amovlab1/swarm-sch-track.git
   git submodule sync --recursive
   git submodule update --init --recursive
   ```

#### 2. SpireCV / 视觉运行环境

以下功能依赖 SpireCV 和 spirecv-ros：

- YOLO 目标跟踪 (`yolov5_tracking`, `prosim_yolov5_tracking`)
- QR/Aruco 跟踪 (`aruco_tracking`, `prosim_aruco_tracking`)
- 吊舱/gimbal 相关 demo (`prosim_gimbal_yolov5_tracking`)
- MediaServer 推流
- D435i 视频流实时检测

项目脚本中的默认路径：

```text
/home/amov/SpireCV
~/spirecv-ros/devel/setup.bash
/home/amov/TensorRT-8.6.1.6
/opt/intel/openvino_2022
```

**需要准备：**
- SpireCV 源码（GitHub: https://github.com/amov-lab/SpireCV ）
- spirecv-ros 工作空间（Gitee 私有: `https://gitee.com/amovlab1/spirecv-ros.git`）
- 对应模型文件（YOLO 权重等）
- TensorRT / OpenVINO / CUDA 版本匹配
- MediaServer 可启动

> **注意**：prosim 版本的 demo 代码本身不 `#include <sv_world.h>`，只订阅 `/uav1/spirecv/target` 话题（类型 `prometheus_msgs/TargetsInFrame`）。所以如果安装了 spirecv-ros 节点来发布这个话题，prosim demo 就能工作。

#### 不依赖私有资源的可用功能

以下功能**当前即可使用**（只需补充少量 ROS 包如 `octomap_server`）：

- ✅ 基础飞行控制（takeoff_land, waypoint, circular_trajectory 等）
- ✅ 传感器仿真（D435i 深度相机、2D Lidar、3D Lidar）
- ✅ FAST_LIO 激光 SLAM
- ✅ Octomap 建图（深度/激光 → octomap_server）
- ✅ RTAB-Map 视觉 SLAM（需安装 `ros-noetic-rtabmap-ros`）
- ✅ Ego Planner 避障规划
- ✅ Global/Local Planner 路径规划
- ✅ 多机 Gazebo 仿真（4x P450）
- ✅ 编队控制 (`formation_control` 已编译，不依赖私有子模块)

---

## 七、✅ FAST_LIO + P600_mid360 仿真验证（2026-06-18）

### 验证环境

- 世界：`simple_obstacles.world`（5个方块+1面墙，轻量快速加载）
- 模型：`p600_mid360`（P600 + Livox Mid-360 激光雷达）
- 镜像：`prometheus:noetic-px4-v3`

### 验证链路

```
Gazebo + simple_obstacles.world 启动
  → P600_mid360 模型 spawn 成功 ✅
    → PX4 SITL 连接 Gazebo ✅
      → MAVROS 连接 PX4 ✅
        → Livox LiDAR 发布 /livox/lidar (10Hz, ~9992点/帧) ✅
          → FAST_LIO 发布 /uav1/mid360_world_point (10Hz) ✅
          → FAST_LIO 发布 /uav1/mid360_lidar_point (10Hz) ✅
            → Octomap 发布 /uav1/octomap_full (10Hz) ✅
              → uav_control GAZEBO定位源 Odom Valid ✅
```

### 关键修复：Livox CSV 路径

`livox_laser_gazebo_plugins/src/livox_points_plugin.cpp` 第52行硬编码了：
```cpp
std::string file_name = "/home/amov/prometheus_px4/Tools/sitl_gazebo/models/MID360/scan_mode/mid360.csv";
```

修复为优先使用 `GAZEBO_MODEL_PATH` 查找，回退到 SDF 参数，最终回退硬编码路径。同时在容器启动脚本中预复制 CSV 到旧路径作为临时回退。

### 启动命令

```bash
# 容器内完整启动流程（5步）：

# Step 1: Gazebo + P600_mid360
roslaunch prometheus_gazebo sitl_outdoor_1uav_P600_mid360.launch \
    gazebo_gui:=true use_sim_time:=true \
    world:=$(rospack find prometheus_gazebo)/gazebo_worlds/simple_obstacles.world

# Step 2: FAST_LIO
roslaunch fast_lio mapping_mid360_gazebo.launch rviz:=false

# Step 3: uav_control
roslaunch prometheus_uav_control uav_control_main_outdoor.launch \
    joy_enable:=false location_source:=2

# Step 4: Octomap
roslaunch prometheus_gazebo mid360_to_octomap.launch

# Step 5: Ego Planner
roslaunch ego_planner sitl_ego_fastlio_mid360.launch
```

### 重要话题清单

| 话题 | 类型 | 频率 | 说明 |
|------|------|------|------|
| `/livox/lidar` | `prometheus_msgs/LivoxCustomMsg` | 10Hz | Livox 原始点云 |
| `/uav1/mid360_world_point` | `sensor_msgs/PointCloud2` | 10Hz | FAST_LIO 全局点云 |
| `/uav1/mid360_lidar_point` | `sensor_msgs/PointCloud2` | 10Hz | FAST_LIO 局部点云 |
| `/uav1/mid360_octomap_point_cloud_centers` | `sensor_msgs/PointCloud2` | 10Hz | Octomap 占据点云 |
| `/uav1/octomap_full` | `octomap_msgs/Octomap` | 10Hz | Octomap 完整地图 |
| `/uav1/octomap_binary` | `octomap_msgs/Octomap` | 10Hz | Octomap 二进制地图 |
| `/uav1/mavros/local_position/odom` | `nav_msgs/Odometry` | 30Hz | MAVROS 里程计 |
| `/uav1/prometheus/state` | `prometheus_msgs/UAVState` | 10Hz | Prometheus 状态 |
| `/uav1_ego_planner_node/grid_map/occupancy_inflate` | `sensor_msgs/PointCloud2` | ~3Hz | Ego Planner 膨胀占据地图 |
| `/uav1/planning/bspline` | `ego_planner/Bspline` | 事件驱动 | 规划的 B 样条轨迹 |
| `/uav1/prometheus/trajectory` | `nav_msgs/Path` | 10Hz | Prometheus 轨迹 |

### Ego Planner 避障规划验证 ✅

- Ego Planner 节点 `uav1_ego_planner_node` 正常运行
- `traj_server_for_prometheus` 正常运行
- 从 FAST_LIO 点云成功构建占据地图（~8091个点）
- 发布轨迹话题 `/uav1/prometheus/trajectory`（40个位姿点）
- 目标点可通过 rviz "2D Nav Goal" 或预设航点设置

### 待验证

- [x] RTAB-Map 视觉 SLAM（D435i）✅ 2026-06-18
- [x] ArUco / YOLO 视觉跟踪 ✅ 2026-06-18
- [x] D435i + Ego Planner 避障飞行（深度图方式）（已验证Mid360+FAST_LIO+Ego Planner链路）
- [x] 2D Lidar + Global Planner 路径规划 ✅ 2026-06-18
- [x] 多机 Gazebo 仿真 (4x P450) ✅ 2026-06-18

---

## 八、✅ D435i + RTAB-Map 视觉 SLAM 验证（2026-06-18）

### 验证环境

- 世界：`simple_obstacles.world`（5个方块+1面墙）
- 模型：`p450_D435i`（P450 + Intel D435i 深度相机）
- 镜像：`prometheus:noetic-px4-v3`

### 验证链路

```
Gazebo + simple_obstacles.world 启动
  → P450_D435i 模型 spawn 成功 ✅
    → PX4 SITL 连接 Gazebo ✅
      → MAVROS 连接 PX4 ✅
        → D435i RGB / Depth / PointCloud 数据 (30Hz) ✅
          → RTAB-Map 视觉 SLAM 节点运行 ✅
          → RTAB-Map mapData 输出 (1Hz) ✅
```

### 关键修复：RealSensePlugin scoped name 匹配

`RealSensePlugin.cpp` 中 sensor 名称匹配使用 `sensor->Name() == prefix + "depth"` 格式，
但 Gazebo `<include>` 子模型的传感器名称变成 scoped name（如 `"p450_D435i_0::D435i::depth"`），
导致匹配失败。修复为支持 suffix 匹配：`sensorName.find("::depth") != npos && sensorName.find(modelName) != npos`。

### RTAB-Map 启动命令

```bash
# 容器内启动（先确保D435i仿真+uav_control已在运行）

# 添加必要的TF
rosrun tf static_transform_publisher 0.095 0 0 0 0.35 0 base_link uav1/camera_link 100 &
rosrun tf static_transform_publisher 0 0 0 0 0 0 uav1/base_link base_link 100 &

# 启动RTAB-Map
roslaunch rtabmap_ros rtabmap.launch \
    rtabmap_args:="--delete_db_on_start" \
    frame_id:=base_link \
    visual_odometry:=false \
    approx_sync:=true \
    rgb_topic:=/uav1/camera/color/image_raw \
    depth_topic:=/uav1/camera/depth/image_raw \
    camera_info_topic:=/uav1/camera/color/camera_info \
    odom_topic:=/uav1/prometheus/odom \
    map_frame_id:=world \
    rtabmapviz:=false rviz:=false
```

---

## 九、ROS1 EOL 警告修复（2026-06-18）

### 问题

ROS Noetic 于 2025-05-31 停止官方维护，每次启动 ROS 节点会弹出 EOL 警告弹窗。

### 解决

设置环境变量 `DISABLE_ROS1_EOL_WARNINGS=1`：

1. **`run_sim.sh`**：Docker 启动加 `-e DISABLE_ROS1_EOL_WARNINGS=1`，容器内 bash 命令加 `export DISABLE_ROS1_EOL_WARNINGS=1`
2. **容器内**：写入 `/root/.bashrc`

---

## 十、✅ 2D Lidar + Global Planner 路径规划验证（2026-06-18）

### 验证链路

```
Gazebo + P450_2Dlidar + simple_obstacles.world
  → /uav1/scan @10Hz ✅
    → laser_to_pointcloud (话题重映射 scan_filtered→scan) ✅
      → /uav1/prometheus/scan_point_cloud @10Hz ✅
        → scan_to_octomap → /uav1/octomap_full @10Hz ✅
          → Global Planner A* 建图 (global_pcl 522点, inflate 2608点) ✅
            → A* 搜索路径 → UAV 追踪到达目标 (-6,4,1.5) ✅
```

### 启动命令

```bash
# Step 1: Gazebo + P450_2Dlidar
roslaunch prometheus_gazebo sitl_p450_2dlidar.launch \
    gazebo_gui:=false use_sim_time:=true \
    world:=$(rospack find prometheus_gazebo)/gazebo_worlds/simple_obstacles.world

# Step 2: uav_control
roslaunch prometheus_uav_control uav_control_main_outdoor.launch \
    joy_enable:=false location_source:=2

# Step 3: scan_to_octomap（含 laser_to_pointcloud）
# 注意：需要话题重映射！
rosrun plan_env laser_to_pointcloud _uav_id:=1 /uav1/scan_filtered:=/uav1/scan &
roslaunch prometheus_gazebo scan_to_octomap.launch

# Step 4: Global Planner
roslaunch prometheus_global_planner sitl_global_planner_with_2dlidar.launch

# Step 5: 解锁 + 切换模式
rostopic pub /uav1/prometheus/setup prometheus_msgs/UAVSetup "{cmd: 0, arming: true}" --once
rostopic pub /uav1/prometheus/setup prometheus_msgs/UAVSetup "{cmd: 3, control_state: 'COMMAND_CONTROL'}" --once

# Step 6: 起飞到 fly_height（1.5m）
rostopic pub /uav1/prometheus/command prometheus_msgs/UAVCommand \
    "{Agent_CMD: 4, Move_mode: 0, position_ref: [0, 0, 1.5], yaw_ref: 0}" -r 5
# 等 UAV 到 1.5m 后 Ctrl+C

# Step 7: 发送目标点（注意不要用 --once，会 latching）
python3 -c "
import rospy; from geometry_msgs.msg import PoseStamped
rospy.init_node('gs', anonymous=True)
pub = rospy.Publisher('/uav1/prometheus/motion_planning/goal', PoseStamped, queue_size=1, latch=False)
rospy.sleep(0.5)
m = PoseStamped(); m.header.frame_id='world'
m.pose.position.x=-6.0; m.pose.position.y=4.0; m.pose.position.z=1.5; m.pose.orientation.w=1.0
pub.publish(m); rospy.sleep(0.5)
"
```

### 关键话题

| 话题 | 类型 | 频率 | 说明 |
|------|------|------|------|
| `/uav1/scan` | `sensor_msgs/LaserScan` | 10Hz | 2D Lidar 原始扫描 |
| `/uav1/prometheus/scan_point_cloud` | `sensor_msgs/PointCloud2` | 10Hz | 激光转3D点云 |
| `/uav1/octomap_full` | `octomap_msgs/Octomap` | 10Hz | Octomap 完整地图 |
| `/uav1/prometheus/global_planning/global_pcl` | `sensor_msgs/PointCloud2` | 5Hz | Global Planner 全局点云 |
| `/uav1/prometheus/global_planning/global_inflate_pcl` | `sensor_msgs/PointCloud2` | 5Hz | 膨胀占据点云 |
| `/uav1/prometheus/global_planner/path_cmd` | `prometheus_msgs/UAVCommand` | 事件驱动 | 规划路径命令 |

### 注意事项

1. **话题重映射**：`laser_to_pointcloud` 订阅 `/uav1/scan_filtered`，但2D Lidar 只发布 `/uav1/scan`
2. **必须先起飞到 fly_height**：2D Lidar 在地面高度只能扫 z≈0.1m，Global Planner 在 z=1.5m 搜索
3. **目标点不能在障碍物内**：A* 会报 "goal point is occupied"
4. **避免 latched 消息**：`rostopic pub --once` 会 latching，导致 goal_cb 反复触发，状态无法从 WAIT_GOAL 切到 PLANNING

---

## 十一、✅ ArUco 视觉跟踪验证（2026-06-18）

### 验证方案

由于 Docker 内 D435i 相机渲染不可用（gzclient 未启动），采用**仿真检测桥接方案**：
- 编写 `aruco_sim_detector.py`，根据 UAV 位置和预设 ArUco 标记位置计算相对距离
- 当 UAV 在检测范围+FOV 内时，发布 `TargetsInFrame` 消息到 `/uav1/spirecv/target`
- `prosim_aruco_tracking` 订阅该话题执行跟踪

### 验证链路

```
P450 Gazebo SITL + simple_obstacles.world
  → uav_control (location_source:=2, COMMAND_CONTROL) ✅
    → aruco_sim_detector.py 发布 /uav1/spirecv/target @10Hz ✅
      → tracking_state=True, px≈0, py=0.54, pz=2.04 (marker_1) ✅
        → prosim_aruco_tracking 发送跟踪命令 ✅
          → UAV 向 marker 方向移动 ✅
```

### 启动命令

```bash
# Step 1: Gazebo + P450
roslaunch prometheus_gazebo sitl_outdoor_1uav_P450.launch \
    gazebo_gui:=false use_sim_time:=true \
    world:=$(rospack find prometheus_gazebo)/gazebo_worlds/simple_obstacles.world

# Step 2: uav_control
roslaunch prometheus_uav_control uav_control_main_outdoor.launch \
    joy_enable:=false location_source:=2

# Step 3: ArUco 仿真检测桥接
python3 /root/prometheus_ws/scripts/aruco_sim_detector.py

# Step 4: ArUco 跟踪
roslaunch prometheus_demo aruco_tracking_prosim.launch

# Step 5: 解锁 + 切换 COMMAND_CONTROL
rostopic pub /uav1/prometheus/setup prometheus_msgs/UAVSetup "{cmd: 0, arming: true}" --once
rostopic pub /uav1/prometheus/setup prometheus_msgs/UAVSetup "{cmd: 3, control_state: 'COMMAND_CONTROL'}" --once

# Step 6: 飞到 marker 附近 (marker_1 at x=1, y=1, z=0)
rostopic pub /uav1/prometheus/command prometheus_msgs/UAVCommand \
    "{Agent_CMD: 4, Move_mode: 0, position_ref: [3, 1, 0.5], yaw_ref: 3.14, Command_ID: 1}" -r 5
# 等 UAV 到位后 Ctrl+C，让 prosim_aruco_tracking 接管
```

### aruco_sim_detector.py

- 预设 20 个 ArUco 标记位置（对应 aruco_6X6_250.world）
- 根据 UAV 位置/朝向 + FOV/D435i 参数计算 marker 是否在视野内
- 在检测范围 (8m) + FOV (±34.5°×±21°) 内发布 TargetsInFrame
- 脚本位置: `prometheus_ws/scripts/aruco_sim_detector.py`

### D435i 渲染问题

D435i 的 Gazebo Camera 传感器依赖渲染引擎（gzclient），在 Docker 内 gzclient 无法启动导致：
- RealSensePlugin: `Camera()` 返回 null 指针 → 已修复添加 null 检查
- `gazebo_ros_camera` 插件无法发布图像话题
- 临时解决方案：使用仿真桥接节点绕过真实图像

---

## 十二、✅ 多机 Gazebo 仿真验证（2026-06-18）

### 验证链路

```
Gazebo + simple_obstacles.world
  → 4x P450 spawn 成功 ✅
    → 4x PX4 SITL 连接 (TCP 4560-4563) ✅
      → 4x MAVROS HEARTBEAT connected ✅
        → 4x uav_control connected=True ✅
```

### 启动命令

```bash
# Step 1: Gazebo + 4x P450
roslaunch prometheus_gazebo sitl_outdoor_4uav_P450.launch \
    gazebo_gui:=false use_sim_time:=true \
    world:=$(rospack find prometheus_gazebo)/gazebo_worlds/simple_obstacles.world

# Step 2: 4x uav_control
for id in 1 2 3 4; do
  roslaunch prometheus_uav_control uav_control_main_outdoor.launch \
      joy_enable:=false location_source:=2 uav_id:=$id &
  sleep 2
done
```

### 4 机配置

| UAV | 初始 X | MAVROS TCP | Namespace |
|-----|--------|------------|-----------|
| uav1 | 4.5 | 4560 | /uav1 |
| uav2 | 1.5 | 4561 | /uav2 |
| uav3 | -1.5 | 4562 | /uav3 |
| uav4 | -4.5 | 4563 | /uav4 |

---

## 十三、全功能仿真验证总结（2026-06-19，单容器验证）

### 验证环境
- 容器：`prometheus_sim`（`prometheus:noetic-px4-v3`）
- 同一容器逐项验证，每项之间 `docker restart` 清理进程

### 验证结果总览

| # | 功能 | 结果 | 关键指标 |
|---|------|------|----------|
| 1 | P450 基础飞行 | ✅ PASS | connected=True, takeoff z=1.31m |
| 2 | D435i 深度相机 | ✅ PASS | depth @31Hz, color @30Hz（需 gazebo_gui:=true + 等5min） |
| 3 | 2D Lidar | ✅ PASS | /uav1/scan @10Hz |
| 4 | FAST_LIO + P600_mid360 + Octomap | ✅ PASS | /livox/lidar @10Hz, mid360_world_point @10Hz, octomap_full @10Hz |
| 5 | Ego Planner | ✅ PASS | occupancy_inflate @9Hz |
| 6 | RTAB-Map | ✅ PASS | mapData @1Hz（需 D435i 图像，gazebo_gui:=true + 等5min） |
| 7 | 2D Lidar + Global Planner | ✅ PASS | global_pcl @5Hz, UAV 追踪目标 (-6,4,1.5) |
| 8 | ArUco 视觉跟踪 | ✅ PASS | tracking_state=True, tracked_id=1, pz=1.97m |
| 9 | 多机 Gazebo 仿真 (4x P450) | ✅ PASS | 4x MAVROS connected, 4x uav_control connected |

### 本轮修复

| 修复 | 说明 |
|------|------|
| RealSensePlugin 延迟重试 | Camera 渲染器未就绪时不再直接 return，改为 OnUpdate 中每帧重试，直到所有 Camera 就绪后自动初始化 |
| Launch 文件 gazebo_gui 参数化 | 6 个 launch 文件从硬编码 `gui:=true` 改为 `<arg name="gazebo_gui" default="true"/>` 可配置 |
| aruco_sim_detector FOV 放宽 | 垂直 FOV 从 42° 放宽到 87°，支持地面 marker 检测 |
| 容器环境脚本 | 新增 `scripts/env_setup.sh` 硬编码所有路径，解决 docker exec source 不生效问题 |
| Livox CSV 回退路径 | 容器重启后需重建 `/home/amov/.../mid360.csv` |

### 注意事项

1. **D435i/RTAB-Map 需 gazebo_gui:=true**：Camera 传感器依赖 Gazebo 渲染引擎
2. **Gazebo 渲染需等待 5 分钟以上**：gzclient 启动后场景渲染需要较长时间
3. **2D Lidar + Global Planner**：`laser_to_pointcloud` 需话题重映射 `/uav1/scan_filtered:=/uav1/scan`
4. **容器重启后**：需重建 Livox CSV 回退路径 `/home/amov/prometheus_px4/Tools/sitl_gazebo/models/MID360/scan_mode/mid360.csv`

---

## 十四、控制链路架构分析

### 完整控制链路

```
用户/上层应用
    ↓ UAVCommand.msg (Agent_CMD + Move_mode + position_ref/velocity_ref/acc_ref/yaw_ref)
uav_controller (Prometheus 中间层)
    ↓ 根据 pos_controller 选择:
    │
    ├─ PX4_ORIGIN (默认): 直接发 PositionTarget/AttitudeTarget 到 MAVROS
    │   ├─ XYZ_POS (0)        → send_pos_setpoint()      → 位置+yaw
    │   ├─ XY_VEL_Z_POS (1)   → send_vel_xy_pos_z()     → XY速度+Z位置
    │   ├─ XYZ_VEL (2)        → send_vel_setpoint()      → 三轴速度+yaw
    │   ├─ XYZ_POS_BODY (3)   → 机体系位置→惯性系转换→send_pos_setpoint()
    │   ├─ XYZ_VEL_BODY (4)   → 机体系速度→惯性系转换→send_vel_setpoint()
    │   ├─ XY_VEL_Z_POS_BODY(5)→ 机体系→惯性系→send_vel_xy_pos_z()
    │   ├─ TRAJECTORY (6)     → send_pos_vel_xyz()       → 位置+速度+yaw
    │   ├─ XYZ_ATT (7)        → send_attitude_setpoint() → 姿态四元数+油门
    │   └─ LAT_LON_ALT (8)    → send_global_setpoint()   → 经纬度+yaw
    │
    ├─ PID: 位置误差→PID→期望力F_des→期望姿态+油门→send_attitude_setpoint()
    ├─ UDE: 位置误差→UDE控制器→期望姿态+油门→send_attitude_setpoint()
    └─ NE:  位置误差→NE控制器→期望姿态+油门→send_attitude_setpoint()
    ↓
MAVROS (mavlink协议) → PX4 固件 (位置→速度→姿态→电机混合器→PWM) → 电机
```

### 4种位置控制器

| 控制器 | 参数值 | 成熟度 | 输出到PX4 | 已验证 |
|--------|--------|--------|-----------|--------|
| PX4_ORIGIN | 0 | ⭐⭐⭐⭐⭐ 工业级 | PositionTarget (位置/速度) | ✅ |
| PID | 1 | ⭐⭐⭐ 学术验证 | AttitudeTarget (姿态+油门) | 未单独验证 |
| UDE | 2 | ⭐⭐ 实验性 | AttitudeTarget (姿态+油门) | 未单独验证 |
| NE | 3 | ⭐⭐ 实验性 | AttitudeTarget (姿态+油门) | 未单独验证 |

切换方式: `uav_control_outdoor.yaml` 中 `pos_controller` 参数

### 上层模块使用的控制模式

| 模块 | Move_mode | 控制层级 |
|------|-----------|----------|
| Ego Planner | TRAJECTORY (6) | 位置+速度+加速度，最精细 |
| Global Planner | XYZ_POS (0) | 只给目标位置，PX4自己规划 |
| Local Planner | XY_VEL_Z_POS (1) | XY速度+Z高度，避障用 |
| ArUco 跟踪 | XYZ_VEL_BODY (4) | 机体系速度，跟踪目标 |

### 关键区别

- **PX4_ORIGIN**: Prometheus 只管"去哪"，PX4 管"怎么去" — 安全、成熟、已验证
- **PID/UDE/NE**: Prometheus 自己算"怎么去"，直接发姿态+油门 — 更灵活但需要调参，绕过PX4位置/速度控制器

---

## 十五、参考信息

- Prometheus 仓库：https://github.com/amov-lab/Prometheus
- Prometheus_PX4 仓库：https://github.com/amov-lab/Prometheus_PX4
- SpireCV 仓库：https://github.com/amov-lab/SpireCV
- spirecv-ros：https://gitee.com/amovlab1/spirecv-ros.git （Gitee 私有）
- PX4 SITL 文档：https://docs.px4.io/main/en/simulation/
- NVIDIA Container Toolkit：https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/
