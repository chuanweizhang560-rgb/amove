#!/usr/bin/env python3
"""
仿真 ArUco 检测桥接节点
模拟检测到 ArUco 标记，发布 TargetsInFrame 消息到 /uav1/spirecv/target
用于验证 prosim_aruco_tracking 跟踪逻辑

用法:
  rosrun prometheus_demo aruco_sim_detector.py
  或 python3 aruco_sim_detector.py

原理:
  - 订阅 /uav1/prometheus/state 获取 UAV 位置
  - 根据预设的 ArUco 标记位置计算相对距离
  - 当 UAV 在检测范围内时，发布 TargetsInFrame 消息
  - prosim_aruco_tracking 订阅该消息执行跟踪
"""

import rospy
import math
import numpy as np
from prometheus_msgs.msg import TargetsInFrame, Target, UAVState

class ArucoSimDetector:
    def __init__(self):
        rospy.init_node('aruco_sim_detector', anonymous=True)

        self.uav_id = rospy.get_param('~uav_id', 1)
        self.detect_range = rospy.get_param('~detect_range', 8.0)  # 最大检测距离
        self.marker_size = rospy.get_param('~marker_size', 0.5)    # 标记尺寸(m)
        self.fov_h = rospy.get_param('~fov_h', 69.0)               # D435i 水平FOV(度)
        self.fov_v = rospy.get_param('~fov_v', 42.0)               # D435i 垂直FOV(度)
        self.img_w = rospy.get_param('~img_w', 640)                 # 图像宽度
        self.img_h = rospy.get_param('~img_h', 480)                 # 图像高度

        # ArUco 标记位置 (x, y, z) - 对应 aruco_6X6_250.world
        self.markers = {}
        for i in range(1, 21):
            row = (i - 1) // 5 + 1
            col = (i - 1) % 5 + 1
            self.markers[i] = np.array([float(row), float(col), 0.0])

        self.uav_pos = np.zeros(3)
        self.uav_yaw = 0.0
        self.tracking_state = False

        # 订阅
        rospy.Subscriber('/uav{}/prometheus/state'.format(self.uav_id),
                         UAVState, self.uav_state_cb)

        # 发布
        self.target_pub = rospy.Publisher(
            '/uav{}/spirecv/target'.format(self.uav_id),
            TargetsInFrame, queue_size=1)

        self.rate = rospy.Rate(10)
        rospy.loginfo("ArUco sim detector started, markers: %s", list(self.markers.keys()))

    def uav_state_cb(self, msg):
        self.uav_pos = np.array([msg.position[0], msg.position[1], msg.position[2]])
        self.uav_yaw = msg.attitude[2]  # yaw

    def run(self):
        while not rospy.is_shutdown():
            # 默认跟踪 ID=1 的标记
            marker_id = 1
            marker_pos = self.markers.get(marker_id)
            if marker_pos is None:
                self.rate.sleep()
                continue

            # 计算标记相对UAV的位置 (世界系)
            rel_pos_world = marker_pos - self.uav_pos
            distance = np.linalg.norm(rel_pos_world)

            # 构建消息
            msg = TargetsInFrame()
            msg.header.stamp = rospy.Time.now()
            msg.header.frame_id = 'world'
            msg.frame_id = 0
            msg.height = self.img_h
            msg.width = self.img_w
            msg.fps = 10.0
            msg.fov_x = self.fov_h
            msg.fov_y = self.fov_v

            # 转换到相机系 (x:右, y:下, z:前)
            # 简化: UAV朝向x正方向(yaw=0)时，前方为x轴
            cy, sy = math.cos(self.uav_yaw), math.sin(self.uav_yaw)
            # 相机前方 = UAV前方 (yaw方向)
            cam_forward = np.array([cy, sy, 0.0])
            cam_right = np.array([sy, -cy, 0.0])
            cam_down = np.array([0.0, 0.0, -1.0])

            pz = np.dot(rel_pos_world, cam_forward)   # 前方距离
            px = np.dot(rel_pos_world, cam_right)      # 右方距离
            py = np.dot(rel_pos_world, cam_down)        # 下方距离

            # 检查是否在视场角内
            if pz > 0.3:  # 最小距离0.3m
                angle_h = math.degrees(math.atan2(px, pz))
                angle_v = math.degrees(math.atan2(py, pz))
                in_fov = abs(angle_h) < self.fov_h / 2 and abs(angle_v) < self.fov_v / 2
            else:
                in_fov = False

            in_range = distance < self.detect_range and pz > 0.3

            if in_range and in_fov:
                # 检测到目标
                target = Target()
                target.cx = 0.5 + px / (2 * pz * math.tan(math.radians(self.fov_h / 2)))
                target.cy = 0.5 + py / (2 * pz * math.tan(math.radians(self.fov_v / 2)))
                target.w = self.marker_size / (2 * pz * math.tan(math.radians(self.fov_h / 2)))
                target.h = self.marker_size / (2 * pz * math.tan(math.radians(self.fov_v / 2)))
                target.score = 1.0
                target.category = 'aruco'
                target.category_id = marker_id - 1
                target.tracked_id = marker_id
                target.px = px
                target.py = py
                target.pz = pz
                target.los_ax = math.degrees(math.atan2(px, pz))
                target.los_ay = math.degrees(math.atan2(py, pz))
                target.yaw_a = 0.0
                target.mode = True  # tracked

                msg.targets.append(target)
                msg.tracking_state = True
                self.tracking_state = True

                rospy.loginfo_throttle(2.0,
                    "Detected marker %d: px=%.2f py=%.2f pz=%.2f dist=%.2f",
                    marker_id, px, py, pz, distance)
            else:
                msg.tracking_state = self.tracking_state
                if self.tracking_state and (not in_range or not in_fov):
                    self.tracking_state = False
                    rospy.loginfo_throttle(2.0,
                        "Marker %d lost: dist=%.2f in_range=%s in_fov=%s",
                        marker_id, distance, in_range, in_fov)

            msg.no_track_frame_count = 0
            self.target_pub.publish(msg)
            self.rate.sleep()

if __name__ == '__main__':
    try:
        detector = ArucoSimDetector()
        detector.run()
    except rospy.ROSInterruptException:
        pass
