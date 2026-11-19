# Frigate configuration managed in Git.
# Rendered to /config/config.yaml at pod start by the sync-config init container.
# {FRIGATE_*} placeholders are substituted by Frigate from the frigate-secrets
# Secret. Never commit real credentials here.
mqtt:
  host: rabbitmq.messaging.svc.cluster.local
  user: frigate
  password: "{FRIGATE_MQTT_PASSWORD}"

record:
  enabled: True
  retain:
    days: 5
    mode: all
  events:
    retain:
      default: 10

detect:
  enabled: True

# Intel UHD 630 (hauler) via OpenVINO/Level Zero. The iGPU device is only
# used if /dev/dri is mounted into the container (see the deployment).
detectors:
  ov:
    type: openvino
    device: GPU
    model:
      path: /openvino-model/ssdlite_mobilenet_v2.xml

# Matches the bundled ssdlite_mobilenet_v2 OpenVINO model.
model:
  width: 300
  height: 300
  input_tensor: nhwc
  input_pixel_format: bgr
  labelmap_path: /openvino-model/coco_91cl_bkgr.txt

live:
  height: 720

go2rtc:
  streams:
    attic-1:
      - rtsp://{FRIGATE_ATTIC1_CREDENTIALS}@192.168.68.74/live0
      #- "ffmpeg:attic-1#audio=opus"
    attic-2:
      - rtsp://{FRIGATE_ATTIC2_CREDENTIALS}@192.168.68.76/live0
      #- "ffmpeg:attic-2#audio=opus"
    attic-3:
      - rtsp://{FRIGATE_ATTIC3_CREDENTIALS}@192.168.68.57/live0
      #- "ffmpeg:attic-3#audio=opus"
    attic-4:
      - rtsp://{FRIGATE_ATTIC4_CREDENTIALS}@192.168.68.58/live0
      #- "ffmpeg:attic-4#audio=opus"
    #backyard:
    #  - rtsp://{FRIGATE_BACKYARD_CREDENTIALS}@192.168.68.82/live0
    #  - "ffmpeg:backyard#audio=opus"
  webrtc:
    candidates:
      - 192.168.68.71:8555
      - stun:8555

objects:
  track:
    - cat
    - person

cameras:
  #backyard:
  #  ffmpeg:
  #    output_args:
  #      record: preset-record-generic-audio-copy
  #    inputs:
  #      - path: rtsp://127.0.0.1:8554/backyard
  #        input_args: preset-rtsp-restream
  #        roles:
  #          - record
  #          - detect
  #  detect:
  #    width: 2560
  #    height: 1440
  attic-1:
    ffmpeg:
      output_args:
        record: preset-record-generic-audio-copy
      inputs:
        - path: rtsp://127.0.0.1:8554/attic-1
          input_args: preset-rtsp-restream
          roles:
            - record
            - detect
    detect:
      width: 2560
      height: 1440
  attic-2:
    ffmpeg:
      output_args:
        record: preset-record-generic-audio-copy
      inputs:
        - path: rtsp://127.0.0.1:8554/attic-2
          input_args: preset-rtsp-restream
          roles:
            - record
            - detect
    detect:
      width: 2560
      height: 1440
  attic-3:
    ffmpeg:
      output_args:
        record: preset-record-generic-audio-copy
      inputs:
        - path: rtsp://127.0.0.1:8554/attic-3
          input_args: preset-rtsp-restream
          roles:
            - record
            - detect
    detect:
      width: 2560
      height: 1440
  attic-4:
    ffmpeg:
      output_args:
        record: preset-record-generic-audio-copy
      inputs:
        - path: rtsp://127.0.0.1:8554/attic-4
          input_args: preset-rtsp-restream
          roles:
            - record
            - detect
    detect:
      width: 2560
      height: 1440
