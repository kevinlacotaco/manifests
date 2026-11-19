title: Climate & Air
views:
- title: Climate & Air
  path: climate
  icon: mdi:thermometer
  type: sections
  sections:
  - type: grid
    cards:
    - type: heading
      heading: Air conditioners
      icon: mdi:air-conditioner
    - type: tile
      entity: climate.living_room_air_conditioner
    - type: tile
      entity: climate.office_air_conditioner
    - type: tile
      entity: climate.master_air_conditioner
    - type: tile
      entity: climate.attic_ac
    - type: tile
      entity: climate.main_floor
    - type: tile
      entity: climate.second_floor
  - type: grid
    cards:
    - type: heading
      heading: Humidifiers
      icon: mdi:water-percent
    - type: tile
      entity: humidifier.willy_s_humidifier
    - type: tile
      entity: humidifier.master_bedroom_humidifier
    - type: tile
      entity: humidifier.girls_humidifier
    - type: tile
      entity: number.willy_s_humidifier_target_level
    - type: tile
      entity: number.master_bedroom_humidifier_target_level
    - type: tile
      entity: number.girls_humidifier_target_level
  - type: grid
    cards:
    - type: history-graph
      title: Temperatures
      hours_to_show: 24
      entities:
      - entity: sensor.master_bedroom_temperature
      - entity: sensor.girls_room_temperature_and_humidity_temperature
      - entity: sensor.willy_s_bedroom_thermometer_temperature
      - entity: sensor.guest_bedroom_thermometer_temperature
      - entity: sensor.main_floor_current_temperature
      - entity: sensor.second_floor_current_temperature
      - entity: sensor.smart_air_quality_monitor_304b95_h5106_tempc
      - entity: sensor.smart_air_quality_monitor_305187_h5106_tempc
      - entity: sensor.smart_air_quality_monitor_363056_h5106_tempc
      - entity: sensor.smart_air_quality_monitor_365b5d_h5106_tempc
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
      - entity: sensor.grapple_temperature_cpu_thermal
      - entity: sensor.living_room_light_button_device_temperature
      - entity: sensor.bedroom_light_button_device_temperature
      - entity: sensor.plant_soil_temperature
      - entity: sensor.0xffffb40e0605dd6a_temperature
  - type: grid
    cards:
    - type: history-graph
      title: Humidity
      hours_to_show: 24
      entities:
      - entity: sensor.willy_s_humidifier_current_humidity
      - entity: sensor.master_bedroom_humidifier_current_humidity
      - entity: sensor.girls_humidifier_current_humidity
      - entity: sensor.master_bedroom_humidity
      - entity: sensor.girls_room_temperature_and_humidity_temperature
      - entity: sensor.bernadettes_room_humidity
      - entity: sensor.willy_s_bedroom_thermometer_humidity
      - entity: sensor.guest_bedroom_thermometer_humidity
      - entity: sensor.main_floor_current_humidity
      - entity: sensor.second_floor_current_humidity
      - entity: sensor.plant_soil_humidity
      - entity: sensor.0xffffb40e0605dd6a_humidity
  - type: grid
    cards:
    - type: history-graph
      title: Air quality (PM2.5)
      hours_to_show: 24
      entities:
      - entity: sensor.airnow_pm2_5
      - entity: sensor.airnow_pm2_5_reporting_station
      - entity: sensor.smart_air_quality_monitor_304b95_h5106_pm25
      - entity: sensor.smart_air_quality_monitor_365b5d_h5106_pm25
      - entity: sensor.smart_air_quality_monitor_363056_h5106_pm25
      - entity: sensor.smart_air_quality_monitor_305187_h5106_pm25
