
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

# Daily solar production is the integral of the live solar power sensor.
sensor:
  - platform: integration
    source: sensor.my_home_solar_power
    name: Home Solar Energy Total
    unique_id: home_solar_energy_total
    unit_time: h
    method: trapezoidal
    round: 3
  - platform: rest
    name: Windsor Heating Oil 300-399 Credit
    unique_id: windsor_heating_oil_300_399_credit
    resource: https://www.cashheatingoil.com/windsor_ct_oil_prices/06095
    scan_interval: 3600
    value_template: >-
      {{ value | regex_findall('(?s)Credit Card Prices.*?300-399\s*</td>\s*<td>\s*\$([0-9.]+)') | first | default('unknown') }}
    unit_of_measurement: "$/gal"
    state_class: measurement

utility_meter:
  home_solar_energy_today:
    source: sensor.home_solar_energy_total
    cycle: daily

sql:
  - name: Windsor Heating Oil Forecast 7d
    unique_id: windsor_heating_oil_forecast_7d
    db_url: sqlite:////config/home-assistant_v2.db
    query: >
      WITH d AS (
        SELECT last_updated_ts AS t, CAST(state AS REAL) AS y
        FROM states
        WHERE entity_id = 'sensor.windsor_heating_oil_300_399_credit'
          AND state GLOB '[0-9]*'
          AND last_updated_ts >= strftime('%s','now') - 2592000
      ), a AS (
        SELECT COUNT(*) AS n,
               SUM(t) AS sx,
               SUM(y) AS sy,
               SUM(t * t) AS sxx,
               SUM(t * y) AS sxy,
               MAX(t) AS max_t
        FROM d
      )
      SELECT ROUND((sy / n) + ((n * sxy - sx * sy) / (n * sxx - sx * sx))
             * (max_t + 604800 - (sx / n)), 2) AS forecast
      FROM a
      WHERE n >= 2 AND (n * sxx - sx * sx) <> 0
    column: forecast
    unit_of_measurement: "$/gal"
    scan_interval: 3600

mqtt:
  - sensor:
      name: "Freezer Temperature"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/14216/CA/temperature_C"
      unit_of_measurement: "°F"
      unique_id: "freezer_temperature_c"
      device_class: "temperature"
      device:
        identifiers: "14216"
        name: "Garage Freezer"
        suggested_area: "garage"
      state_class: "measurement"
      value_template: "{{ (value | float * 9/5 + 32) | round(2) }}"
  - sensor:
      name: "Freezer Humidity"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/14216/CA/humidity"
      unit_of_measurement: "%"
      unique_id: "freezer_temperature_humidity"
      device_class: "humidity"
      device:
        identifiers: "14216"
        name: "Garage Freezer"
        suggested_area: "garage"
      state_class: "measurement"
      value_template: "{{ value }}"
  - sensor:
      name: "Garage Fridge Temperature"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/6407/CA/temperature_C"
      unit_of_measurement: "°F"
      unique_id: "garage_fridge_temperature_c"
      device_class: "temperature"
      device:
        identifiers: "6407"
        name: "Garage Fridge"
        suggested_area: "garage"
      state_class: "measurement"
      value_template: "{{ (value | float * 9/5 + 32) | round(2) }}"
  - sensor:
      name: "Garage Fridge Humidity"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/6407/CA/humidity"
      unit_of_measurement: "%"
      unique_id: "garage_fridge_temperature_humidity"
      device_class: "humidity"
      device:
        identifiers: "6407"
        name: "Garage Fridge"
        suggested_area: "garage"
      state_class: "measurement"
      value_template: "{{ value }}"
  - sensor:
      name: "Garage Ambient Temperature"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/263/CA/temperature_C"
      unit_of_measurement: "°F"
      unique_id: "garage_ambient_temperature_c"
      device_class: "temperature"
      device:
        identifiers: "263"
        name: "Garage Ambient"
        suggested_area: "garage"
      state_class: "measurement"
      value_template: "{{ (value | float * 9/5 + 32) | round(2) }}"
  - sensor:
      name: "Garage Ambient Humidity"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/263/CA/humidity"
      unit_of_measurement: "%"
      unique_id: "garage_ambient_humidity"
      device_class: "humidity"
      device:
        identifiers: "263"
        name: "Garage Ambient"
        suggested_area: "garage"
      state_class: "measurement"
      value_template: "{{ value }}"
  - sensor:
      name: "Detached Garage Temperature"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/3951/CA/temperature_C"
      unit_of_measurement: "°F"
      unique_id: "detached_garage_temperature_c"
      device_class: "temperature"
      device:
        identifiers: "3951"
        name: "Detached Garage Ambient"
        suggested_area: "Detached Garage"
      state_class: "measurement"
      value_template: "{{ (value | float * 9/5 + 32) | round(2) }}"
  - sensor:
      name: "Detached Garage Humidity"
      state_topic: "rtl_433/grapple/devices/Acurite-Tower/3951/CA/humidity"
      unit_of_measurement: "%"
      unique_id: "detached_garage_humidity"
      device_class: "humidity"
      device:
        identifiers: "3951"
        name: "Detached Garage Ambient"
        suggested_area: "Detached Garage"
      state_class: "measurement"
      value_template: "{{ value }}"

lovelace:
  dashboards:
    lovelace:
      mode: yaml
      filename: dashboards/overview.yaml
      title: Overview
      icon: mdi:view-dashboard
      show_in_sidebar: true
    climate-air:
      mode: yaml
      title: Climate & Air
      icon: mdi:thermometer
      show_in_sidebar: true
      filename: dashboards/climate.yaml
    energy-view:
      mode: yaml
      title: Energy
      icon: mdi:flash
      show_in_sidebar: true
      filename: dashboards/energy.yaml
    security-cameras:
      mode: yaml
      title: Security & Cameras
      icon: mdi:shield-home
      show_in_sidebar: true
      filename: dashboards/security.yaml
    garage-appliances:
      mode: yaml
      title: Garage & Appliances
      icon: mdi:garage
      show_in_sidebar: true
      filename: dashboards/garage.yaml
    media-view:
      mode: yaml
      title: Media
      icon: mdi:speaker-multiple
      show_in_sidebar: true
      filename: dashboards/media.yaml
    systems-maintenance:
      mode: yaml
      title: Systems & Maintenance
      icon: mdi:server
      show_in_sidebar: true
      filename: dashboards/systems.yaml

prometheus:
  requires_auth: false
