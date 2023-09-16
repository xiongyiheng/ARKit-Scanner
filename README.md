# iOS ARKit-Scanner App
The scanner app acquires RGB-D scans using iPhone LiDAR sensor and ARKit API, stores color, depth and IMU data on local memory and then uploads to PC for processing[[Watch the video]](https://www.youtube.com/shorts/ZB822Hd0jjs). The whole project is built based on [Displaying a Point Cloud Using Scene Depth](https://developer.apple.com/documentation/arkit/environmental_analysis/displaying_a_point_cloud_using_scene_depth) and is used for data collection by [ScanNet++](https://cy94.github.io/scannetpp/).

## Prerequisites for compilation
- iPhone 13 pro (can work with other iPads and iPhones with LiDAR sensor but untested)
- Xcode 14.0+
- iOS 14.0+
- iPadOS 14.0+

## Build
- Open pointCloudSample.xcodeproj with Xcode
- Attach your iOS device and authorize the development machine to build to the device
- Build the Scanner target for your device (select "pointCloudSample" and your attached device name at the top left next to the "play" icon, and click the "play" icon)
- Detach the device from the development machine and run the Scanner app

## Data Formats

**metadata (`*.json`)**:
```
{"scene_name":"Xiong","scene_type":"apartment","color_width":"1920","color_height":"1440","depth_width":"256","depth_height":"192","intrinsic":"[1456.2087,0.0,0.0,0.0,1456.2087,0.0,962.67816,717.8443,1.0]","exposure duration":"0.016666666666666666"}
```

**depth (`*.bin`)**:
Compressed stream of depth frames from iPhone's LiDAR.  Please refer to the [postprocessing](https://github.com/liu115/ARKit-Scanner/tree/main/python) code for an example of how to parse the data.

**rgb (`*.mp4`)**:
A sequence of RGB frames in the form of mp4.

**trans (`*.json`)**:
Transform of camera for each frame in the format of: 
```
{<frameID>:"[-0.12042544,-0.94454795,0.3054945,0.0,0.9779544,-0.16575992,-0.12699933,0.0,0.17059568,0.2834657,0.9436865,0.0,0.002562333,0.024424758,0.025746325,1.0]",...}
```

**offset (`*.json`)**:
Exposure offset for each frame in the format of: 
```
{<frameID>:"8.328667",...}
```

**imu (`*.json`)**:
IMU data for each frame in the format of:
```
{<frameID>:"[0.0006190282292664051,-0.009413435123860836,-0.0021445199381560087,-0.006018027663230896,-0.008715152740478516,-0.0023995935916900635,0.0,0.0,0.0,0.5224416595374864,1.2367715496437015,-0.2551249550778954,0.16359558701515198,-0.9447304606437683,-0.2841145992279053]",...}
```
Each entry represents imu data in the order of: x rotation rate, y rotation rate, z rotation rate, x user-caused acceleration vector, y user-caused acceleration vector, z user-caused acceleration vector, x magnetic field, y magnetic field, z magnetic field, roll, pitch, yaw, x gravity vector, y gravity vector, z gravity vector.
