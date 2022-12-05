import os
import sys
import json
from collections import namedtuple
from glob import glob
import zlib
import subprocess
import shutil

import imageio.v3 as iio
import numpy as np
import cv2
from visualizer import Visualization


def run_command(cmd: str, verbose=False):
    out = subprocess.run(cmd, capture_output=not verbose, shell=True, check=False)
    if out.returncode != 0:
        print(out.stderr.decode("utf-8"))
        sys.exit(1)
    if out.stdout is not None:
        return out.stdout.decode("utf-8")
    return out


def decode_video_and_save(video_path, out_dir, sample_rate=1):
    FPS = 60    # This is predefined
    assert FPS % sample_rate == 0
    # cmd = f"ffmpeg -i {video_path} -q:v 2 -vf fps={FPS/sample_rate} {out_dir}/frame_%05d.png"
    print(f"Extracting frames from the video {video_path}")
    cmd = f"ffmpeg -i {video_path} -q:v 2 {out_dir}/frame_%05d.jpg"
    run_command(cmd, verbose=False)


class iPhoneDataIterator:
    def __init__(self, root_dir, sample_rate=1):
        self.root_dir = root_dir
        self.sample_rate = sample_rate
        metadata = self._read_json(os.path.join(self.root_dir, 'metadata.json'))
        self.intrinsic = np.asarray(json.loads(metadata['intrinsic'])).reshape(3, 3).T
        self.rgb_width, self.rgb_height = int(metadata['color_width']), int(metadata['color_height'])
        self.depth_width, self.depth_height = int(metadata['depth_width']), int(metadata['depth_height'])

        # Load poses
        self.poses = self._read_json(os.path.join(self.root_dir, 'trans.json'))
        self.poses = {int(key): np.asarray(json.loads(val)).reshape(4, 4).T for key, val in self.poses.items()}
        print("Num frames", len(self.poses))

        shutil.rmtree(os.path.join(self.root_dir, 'images'))
        os.makedirs(os.path.join(self.root_dir, 'images'), exist_ok=True)
        if len(os.listdir(os.path.join(self.root_dir, 'images'))) == 0:
            decode_video_and_save(
                os.path.join(self.root_dir, 'rgb.mp4'),
                os.path.join(self.root_dir, 'images'),
                sample_rate=sample_rate
            )
        self.image_files = sorted(glob(os.path.join(self.root_dir, 'images/*.jpg')))
        print("Num frames", len(self.image_files))

        self.idx = 0

        self.depth_iter = self._read_depth_all(os.path.join(self.root_dir, 'depth.bin'), self.depth_height, self.depth_width, sample_rate=sample_rate)

    def __iter__(self):
        return self

    def __next__(self):
        if self.idx < len(self.image_files) and self.idx * self.sample_rate < len(self.poses):
            data = {
                "rgb": iio.imread(self.image_files[self.idx * self.sample_rate]),
                "depth": next(self.depth_iter),
                "pose": self.poses[self.idx * self.sample_rate],
                "intrinsic": self.intrinsic,
            }
            self.idx += 1
            return data
        raise StopIteration

    def _read_json(self, file_path):
        with open(file_path, 'r') as infile:
            return json.load(infile)

    def _read_depth_all(self, file_path, height=192, width=256, sample_rate=1):
        frame_id = 0
        with open(file_path, 'rb') as infile:
            while True:
                size = infile.read(4)   # 32-bit integer
                if len(size) == 0:
                    break
                size = int.from_bytes(size, byteorder='little')

                if frame_id % sample_rate != 0:
                    infile.seek(size, 1)
                    frame_id += 1
                    continue

                data = infile.read(size)
                data = zlib.decompress(data, wbits=-zlib.MAX_WBITS)
                depth = np.frombuffer(data, dtype=np.float32).reshape(height, width)
                frame_id += 1
                yield depth

    def _parse_imu(self, data):
        data = np.array(data)
        rot_rate = data[:3]
        user_acc = data[3:6]
        magnet = data[6:9]
        rad = data[9:12]
        gravity = data[12:]
        IMU = namedtuple('IMU', ['rotate_rate', 'acceleration', 'magnet', 'radian', 'gravity'])
        return IMU(
            rotate_rate=rot_rate,
            acceleration=user_acc,
            magnet=magnet,
            radian=rad,
            gravity=gravity
        )


def backproject(image, depth, intrinsic, pose):
    height, width, _ = image.shape
    depth = cv2.resize(depth, (width, height), interpolation=cv2.INTER_NEAREST)
    y, x = np.meshgrid(np.arange(height), np.arange(width), indexing='ij')
    x = np.reshape(x, -1)
    y = np.reshape(y, -1)

    z = depth[height - y - 1, x]
    valid_mask = np.logical_not((z <= 0) | np.isnan(z) | np.isinf(z))
    x = x[valid_mask]
    y = y[valid_mask]
    z = z[valid_mask]

    uv_one1 = np.stack([x, y, np.ones_like(x)], axis=0)
    xyz = np.linalg.inv(intrinsic) @ uv_one1 * z
    xyz[2, :] = -xyz[2, :]
    xyz_one = np.concatenate([xyz, np.ones_like(xyz[:1, :])], axis=0)
    xyz_one = pose @ xyz_one
    xyz = xyz_one[:3, :]

    rgb = image[height - y - 1, x]
    return xyz.T, rgb


def main():
    data_iter = iPhoneDataIterator('./data', sample_rate=30)
    vis = Visualization()
    vis.create_window()

    for i, x in enumerate(data_iter):
        intrinsic = x['intrinsic']
        depth = x['depth']
        image = x['rgb']
        image = np.asarray(image) / 255.0
        pose = x['pose']

        xyz, rgb = backproject(image, depth, intrinsic, pose)
        vis.add_points(xyz, rgb, remove_statistical_outlier=False)
        vis.add_camera(intrinsic, pose[:3, :3], pose[:3, 3], width=image.shape[1], height=image.shape[0], scale=0.1)
    vis.show()


if __name__ == '__main__':
    main()
