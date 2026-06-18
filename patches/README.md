# Prometheus 仿真补丁文件

本目录包含对 Prometheus 源码的修改，需手动覆盖到对应位置：

| 文件 | 目标路径 |
|------|----------|
| `RealSensePlugin.cpp` | `src/Prometheus/Simulator/realsense_gazebo_plugin/src/RealSensePlugin.cpp` |
| `livox_points_plugin.cpp` | `src/Prometheus/Simulator/livox_laser_gazebo_plugins/src/livox_points_plugin.cpp` |
| `simple_obstacles.world` | `src/Prometheus/Simulator/gazebo_simulator/gazebo_worlds/simple_obstacles.world` |

## 修改说明

1. **RealSensePlugin.cpp**: 修复 Gazebo `<include>` 子模型 sensor scoped name 匹配问题
2. **livox_points_plugin.cpp**: 修复 Livox CSV 路径硬编码，改用 GAZEBO_MODEL_PATH 查找
3. **simple_obstacles.world**: 新增轻量障碍物世界，用于快速仿真验证

## 应用补丁

```bash
cp patches/RealSensePlugin.cpp src/Prometheus/Simulator/realsense_gazebo_plugin/src/
cp patches/livox_points_plugin.cpp src/Prometheus/Simulator/livox_laser_gazebo_plugins/src/
cp patches/simple_obstacles.world src/Prometheus/Simulator/gazebo_simulator/gazebo_worlds/
```
