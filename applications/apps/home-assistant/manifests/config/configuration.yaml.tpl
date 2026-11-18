
# Loads default set of integrations. Do not remove.
default_config:

# Load frontend themes from the themes folder
frontend:
  themes: !include_dir_merge_named themes

automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml

config:

http:
  ip_ban_enabled: true
  login_attempts_threshold: 5
  server_port: 8123 # default
  cors_allowed_origins:
    - https://google.com
    - https://wwww.home-assistant.io
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.68.138
    - 10.42.0.0/16
    - 192.168.68.71
    - 127.0.0.1

homeassistant:
  external_url: "https://ha.lakotko.synology.me"

# Template entities are managed in Git under config/templates/.
template: !include_dir_merge_list templates

mqtt:
  - sensor:
      name: "Freezer Temperature"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/14216/CA/temperature_C"
      unit_of_measurement: "°C"
      unique_id: "freezer_temperature_c"
      device_class: "temperature"
      device:
        identifiers: "14216"
        suggested_area: "garage"
      state_class: "measurement"
      value_template: "{{ value }}"
  - sensor:
      name: "Freezer Humidity"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/14216/CA/humidity"
      unit_of_measurement: "%"
      unique_id: "freezer_temperature_humidity"
      device_class: "humidity"
      device:
        identifiers: "14216"
        suggested_area: "garage"
      state_class: "measurement"
      value_template: "{{ value }}"
  - sensor:
      name: "Garage Fridge Temperature"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/6407/CA/temperature_C"
      unit_of_measurement: "°C"
      unique_id: "garage_fridge_temperature_c"
      device_class: "temperature"
      device:
        identifiers: "6407"
        suggested_area: "garage"
      state_class: "measurement"
      value_template: "{{ value }}"
  - sensor:
      name: "Garage Fridge Humidity"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/6407/CA/humidity"
      unit_of_measurement: "%"
      unique_id: "garage_fridge_temperature_humidity"
      device_class: "humidity"
      device:
        identifiers: "6407"
        suggested_area: "garage"
      state_class: "measurement"
      value_template: "{{ value }}"

prometheus:
  requires_auth: false
