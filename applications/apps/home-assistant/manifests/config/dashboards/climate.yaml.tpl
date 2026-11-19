title: Climate & Air
views:
- title: Climate & Air
  path: climate
  icon: mdi:thermometer
  type: sections
  sections:
  - type: grid
    cards:
    - type: markdown
      content: "### Air conditioners"
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
    - type: markdown
      content: "### Humidifiers"
    - type: tile
      entity: humidifier.willy_s_humidifier
    - type: tile
      entity: humidifier.master_bedroom_humidifier
    - type: tile
      entity: humidifier.girls_humidifier
  - type: grid
    cards:
    - type: history-graph
      title: Temperatures
      hours_to_show: 24
      entities:
      - entity: sensor.master_bedroom_temperature
      - entity: sensor.girls_room_temperature_and_humidity_temperature
      - entity: sensor.guest_bedroom_thermometer_temperature
      - entity: sensor.main_floor_current_temperature
      - entity: sensor.second_floor_current_temperature
      - entity: sensor.bonus_room_air_quality_temperature
      - entity: sensor.attic_monitor_temperature
      - entity: sensor.basement_air_mon_temperature
      - entity: sensor.master_bedroom_air_mon_temperature
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
      - entity: sensor.bonus_room_air_quality_airquality
      - entity: sensor.master_bedroom_air_mon_airquality
      - entity: sensor.basement_air_mon_airquality
      - entity: sensor.attic_monitor_airquality
