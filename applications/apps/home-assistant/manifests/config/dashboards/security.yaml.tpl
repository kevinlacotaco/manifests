title: Security & Cameras
views:
- title: Security & Cameras
  path: security
  icon: mdi:shield-home
  type: sections
  sections:
  - type: grid
    cards:
    - type: picture-entity
      entity: camera.attic_1
      camera_view: live
      show_name: true
      show_state: false
    - type: picture-entity
      entity: camera.attic_2
      camera_view: live
      show_name: true
      show_state: false
    - type: picture-entity
      entity: camera.attic_3
      camera_view: live
      show_name: true
      show_state: false
    - type: picture-entity
      entity: camera.attic_4
      camera_view: live
      show_name: true
      show_state: false
    - type: picture-entity
      entity: camera.driveway
      camera_view: live
      show_name: true
      show_state: false
  - type: grid
    cards:
    - type: heading
      heading: Water and freeze alerts
      icon: mdi:alert-octagon
    - type: tile
      entity: binary_sensor.utility_sink_leak
    - type: tile
      entity: binary_sensor.first_floor_bathroom_sink_water_leak
    - type: tile
      entity: binary_sensor.kitchen_sink_leak
    - type: tile
      entity: binary_sensor.second_floor_bathroom_leak
    - type: tile
      entity: sensor.garage_freezer_temperature
    - type: tile
      entity: sensor.garage_fridge_temperature
    - type: tile
      entity: sensor.garage_ambient_temperature
  - type: grid
    cards:
    - type: heading
      heading: Motion and occupancy
      icon: mdi:motion-sensor
    - type: tile
      entity: binary_sensor.main_floor_motion
    - type: tile
      entity: binary_sensor.main_floor_occupancy
    - type: tile
      entity: binary_sensor.second_floor_motion
    - type: tile
      entity: binary_sensor.second_floor_occupancy
    - type: tile
      entity: binary_sensor.driveway_all_occupancy
    - type: tile
      entity: binary_sensor.driveway_cat_occupancy
    - type: tile
      entity: binary_sensor.driveway_person_occupancy
    - type: tile
      entity: binary_sensor.driveway_motion
  - type: grid
    cards:
    - type: entities
      title: Garage doors
      state_color: true
      entities:
      - entity: binary_sensor.right_garage_door_battery_low
      - entity: binary_sensor.right_garage_door_contact
      - entity: binary_sensor.left_garage_door_contact
