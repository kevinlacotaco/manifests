title: Systems & Maintenance
views:
- title: Systems & Maintenance
  path: systems
  icon: mdi:server
  type: sections
  sections:
  - type: grid
    cards:
    - type: markdown
      content: "### Hosts"
    - type: tile
      entity: sensor.ironhide_cpu_usage
    - type: tile
      entity: sensor.ironhide_memory_usage
    - type: tile
      entity: sensor.ironhide_temperature_coretemp_package_id_0
    - type: tile
      entity: sensor.ironhide_gpu_nvidia_0_load
    - type: tile
      entity: sensor.ironhide_gpu_nvidia_0_temperature
  - type: grid
    cards:
    - type: entities
      title: Updates
      state_color: true
      entities:
      - entity: update.frigate_server
      - entity: update.0x282c02bfffea6f5d
      - entity: update.dryer_vibration_sensor
      - entity: update.right_garage_door
      - entity: update.0x282c02bfffec941f
      - entity: update.hoist_dsm_update
      - entity: update.first_floor_bathroom_sink
      - entity: update.0x282c02bfffeae7b7
      - entity: update.0x282c02bfffeae47e
      - entity: update.ironhide_update
      - entity: update.master_bedroom_smart_button
      - entity: update.0x282c02bfffec3463
      - entity: update.0x282c02bfffec763f
      - entity: update.plant_soil
      - entity: update.0xffffb40e0605dd6a
      - entity: update.0xffffb40e0603a716
      - entity: update.string_lights
      - entity: update.christmas_tree
      - entity: update.0x282c02bfffec61e0
      - entity: update.garmin_connect
      - entity: update.frigate
      - entity: update.local_tuya
      - entity: update.tp_link_deco
      - entity: update.tesla
      - entity: update.mail_and_packages
      - entity: update.smartthinq_lge_sensors
      - entity: update.0x001788010fefe488
      - entity: update.0x001788010fefe30d
      - entity: update.0x001788010fee7aca
      - entity: update.0x001788010ff05dc7
  - type: grid
    cards:
    - type: entities
      title: Batteries
      state_color: true
      entities:
      - entity: sensor.master_bedroom_temperature_and_humidity_battery
      - entity: sensor.girls_room_temperature_and_humidity_battery
      - entity: sensor.guest_bedroom_thermometer_battery
      - entity: sensor.arcee_battery_level
      - entity: sensor.utility_sink_leak_battery
      - entity: sensor.dryer_vibration_battery
      - entity: sensor.right_garage_door_battery
      - entity: sensor.left_garage_door_battery
      - entity: sensor.first_floor_bathroom_sink_battery
      - entity: sensor.kitchen_sink_leak_battery
      - entity: sensor.second_floor_bathroom_leak_battery
      - entity: sensor.office_ir_blaster_battery
      - entity: sensor.living_room_light_button_battery
      - entity: sensor.bedroom_light_button_battery
      - entity: sensor.master_bedroom_smart_button_battery
      - entity: sensor.pixel_8_battery_level
      - entity: sensor.plant_soil_battery
      - entity: sensor.0xffffb40e0605dd6a_battery
  - type: grid
    cards:
    - type: entities
      title: Consumables and maintenance
      state_color: true
      entities:
      - entity: sensor.mfc_j4335dw_black_ink_remaining
      - entity: sensor.mfc_j4335dw_cyan_ink_remaining
      - entity: sensor.mfc_j4335dw_magenta_ink_remaining
      - entity: sensor.mfc_j4335dw_yellow_ink_remaining
      - entity: sensor.roborock_q5_2_filter_time_left
      - entity: sensor.roborock_q5_filter_time_left
      - entity: sensor.living_room_ac_filter_life
      - entity: sensor.office_air_conditioner_filter_remaining_life
      - entity: button.roborock_q5_2_reset_sensor_consumable
      - entity: button.roborock_q5_2_reset_filter_consumable
      - entity: button.roborock_q5_2_reset_side_brush_consumable
      - entity: button.roborock_q5_2_reset_main_brush_consumable
      - entity: button.roborock_q5_reset_sensor_consumable
      - entity: button.roborock_q5_reset_filter_consumable
      - entity: button.roborock_q5_reset_side_brush_consumable
      - entity: button.roborock_q5_reset_main_brush_consumable
      - entity: sensor.roborock_q5_2_filter_left
      - entity: sensor.roborock_q5_filter_left
      - entity: sensor.master_air_conditioner_filter_remaining_life
      - entity: sensor.attic_ac_filter_remaining_life
      - entity: binary_sensor.utility_sink_leak_battery_low
      - entity: binary_sensor.dryer_vibration_battery_low
      - entity: binary_sensor.right_garage_door_battery_low
      - entity: binary_sensor.0x282c02bfffec941f_battery_low
      - entity: binary_sensor.first_floor_bathroom_sink_battery_low
      - entity: binary_sensor.kitchen_sink_leak_battery_low
      - entity: binary_sensor.second_floor_bathroom_leak_battery_low
      - entity: binary_sensor.master_bedroom_smart_button_battery_low
      - entity: binary_sensor.guest_bedroom_mfc_j4335dw_door_open
      - entity: binary_sensor.guest_bedroom_mfc_j4335dw_paper_jam
      - entity: binary_sensor.guest_bedroom_mfc_j4335dw_no_paper
      - entity: binary_sensor.guest_bedroom_mfc_j4335dw_low_ink
      - entity: binary_sensor.guest_bedroom_mfc_j4335dw_no_ink
  - type: grid
    cards:
    - type: entities
      title: Host telemetry
      state_color: true
      entities:
      - entity: sensor.ironhide_disk_io_nvme0n1
      - entity: sensor.ironhide_disk_io_sdb
      - entity: sensor.ironhide_disk_io_sda
      - entity: sensor.ironhide_cpu_usage
      - entity: binary_sensor.ironhide_system_updates
      - entity: sensor.ironhide_memory_usage
      - entity: binary_sensor.ironhide_required_restart
      - entity: sensor.ironhide_temperature_acpitz
      - entity: sensor.ironhide_temperature_nvme_composite
      - entity: sensor.ironhide_temperature_nvme_sensor_1
      - entity: sensor.ironhide_temperature_nvme_sensor_2
      - entity: sensor.ironhide_temperature_coretemp_package_id_0
      - entity: sensor.ironhide_temperature_coretemp_core_0
      - entity: sensor.ironhide_temperature_coretemp_core_1
      - entity: sensor.ironhide_temperature_coretemp_core_2
      - entity: sensor.ironhide_temperature_coretemp_core_3
      - entity: sensor.ironhide_temperature_coretemp_core_4
      - entity: sensor.ironhide_temperature_coretemp_core_5
      - entity: sensor.ironhide_temperature_coretemp_core_6
      - entity: sensor.ironhide_temperature_coretemp_core_7
      - entity: sensor.ironhide_temperature_iwlwifi_1
      - entity: sensor.ironhide_disk_dev_nvme0n1p2
      - entity: sensor.ironhide_disk_dev_nvme0n1p1
      - entity: sensor.ironhide_disk_dev_sdb1
      - entity: sensor.ironhide_gpu_nvidia_0_load
      - entity: sensor.ironhide_gpu_nvidia_0_memory
      - entity: sensor.ironhide_gpu_nvidia_0_temperature
      - entity: sensor.ironhide_disk_io_sdc
      - entity: sensor.ironhide_disk_dev_sdc
      - entity: sensor.ironhide_disk_dev_sdc1
      - entity: sensor.ironhide_disk_dev_sdc4
      - entity: sensor.ironhide_disk_dev_sda2
      - entity: sensor.ironhide_disk_io_sdd
      - entity: sensor.ironhide_disk_dev_sdd1
      - entity: sensor.ironhide_disk_io_sde
      - entity: sensor.ironhide_disk_dev_sdd
      - entity: sensor.ironhide_disk_dev_sde1
      - entity: sensor.backup_manager_state
      - entity: sensor.backup_next_scheduled_automatic_backup
      - entity: sensor.backup_last_successful_automatic_backup
      - entity: sensor.backup_last_attempted_automatic_backup
      - entity: sensor.backup_last_successful_automatic_backup_size
