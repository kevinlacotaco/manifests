title: Climate & Air
views:
  - title: Climate & Air
    path: climate
    icon: mdi:thermometer
    type: sections
    max_columns: 3
    sections:
      - type: grid
        cards:
          - type: heading
            heading: Climate & Air
            icon: mdi:thermometer
          - type: custom:mushroom-chips-card
            alignment: center
            chips:
              - type: template
                icon: mdi:home-thermometer
                icon_color: blue
                content: "{{ states('sensor.main_floor_current_temperature') }}°F main"
              - type: template
                icon: mdi:home-thermometer-outline
                icon_color: purple
                content: "{{ states('sensor.second_floor_current_temperature') }}°F upstairs"
              - type: template
                icon: mdi:water-percent
                icon_color: cyan
                content: "{{ states('sensor.main_floor_current_humidity') }}% humidity"
              - type: template
                icon: mdi:blur
                icon_color: green
                content: "PM2.5 {{ states('sensor.airnow_pm2_5') }}"
          - type: custom:mushroom-climate-card
            entity: climate.living_room_air_conditioner
            icon: mdi:air-conditioner
            show_temperature_control: true
            layout: horizontal
          - type: custom:mushroom-climate-card
            entity: climate.office_air_conditioner
            icon: mdi:air-conditioner
            show_temperature_control: true
            layout: horizontal
          - type: custom:mushroom-climate-card
            entity: climate.master_air_conditioner
            icon: mdi:air-conditioner
            show_temperature_control: true
            layout: horizontal
          - type: custom:mushroom-climate-card
            entity: climate.attic_ac
            icon: mdi:air-conditioner
            show_temperature_control: true
            layout: horizontal
          - type: custom:mushroom-climate-card
            entity: climate.main_floor
            icon: mdi:thermostat
            show_temperature_control: true
            layout: horizontal
          - type: custom:mushroom-climate-card
            entity: climate.second_floor
            icon: mdi:thermostat
            show_temperature_control: true
            layout: horizontal

      - type: grid
        cards:
          - type: heading
            heading: Humidifiers
            icon: mdi:air-humidifier
          - type: custom:mushroom-entity-card
            entity: humidifier.willy_s_humidifier
            icon: mdi:air-humidifier
            icon_color: cyan
          - type: custom:mushroom-entity-card
            entity: humidifier.master_bedroom_humidifier
            icon: mdi:air-humidifier
            icon_color: cyan
          - type: custom:mushroom-entity-card
            entity: humidifier.girls_humidifier
            icon: mdi:air-humidifier
            icon_color: cyan

      - type: grid
        cards:
          - type: heading
            heading: Kitchen
            icon: mdi:silverware-fork-knife
          - type: custom:mushroom-template-card
            entity: sensor.kitchen_temperature
            primary: "{{ states('sensor.kitchen_temperature') | float(0) | round(1) }}°F"
            secondary: "{{ states('sensor.kitchen_humidity') | float(0) | round(0) }}% humidity"
            icon: mdi:thermometer
            icon_color: amber
            tap_action:
              action: more-info
          - type: custom:mushroom-entity-card
            entity: sensor.kitchen_temperature_humidity_battery
            name: Sensor battery
            icon: mdi:battery
            icon_color: green

      - type: grid
        cards:
          - type: heading
            heading: Temperature
            icon: mdi:thermometer-lines
          - type: custom:mini-graph-card
            name: Upstairs
            icon: mdi:home-thermometer
            hours_to_show: 24
            points_per_hour: 2
            line_width: 2
            entities:
              - entity: sensor.second_floor_current_temperature
                name: Second floor
                color: "#a855f7"
              - entity: sensor.master_bedroom_air_mon_temperature
                name: Master bedroom
                color: "#ec4899"
              - entity: sensor.girls_room_temperature_and_humidity_temperature
                name: Girls room
                color: "#f97316"
              - entity: sensor.guest_bedroom_thermometer_temperature
                name: Guest bedroom
                color: "#14b8a6"
              - entity: sensor.bonus_room_air_quality_temperature
                name: Bonus room
                color: "#84cc16"
          - type: custom:mini-graph-card
            name: Main floor & basement
            icon: mdi:home-thermometer-outline
            hours_to_show: 24
            points_per_hour: 2
            line_width: 2
            entities:
              - entity: sensor.main_floor_current_temperature
                name: Main floor
                color: "#3b82f6"
              - entity: sensor.kitchen_temperature
                name: Kitchen
                color: "#f59e0b"
              - entity: sensor.basement_air_mon_temperature
                name: Basement
                color: "#64748b"
          - type: custom:mini-graph-card
            name: Attic
            icon: mdi:home-thermometer
            hours_to_show: 24
            points_per_hour: 2
            line_width: 2
            entities:
              - entity: sensor.attic_monitor_temperature
                name: Attic
                color: "#ef4444"

      - type: grid
        cards:
          - type: heading
            heading: Humidity
            icon: mdi:water-percent
          - type: custom:mini-graph-card
            name: Indoor humidity
            icon: mdi:water-percent
            hours_to_show: 24
            points_per_hour: 2
            line_width: 2
            entities:
              - entity: sensor.main_floor_current_humidity
                name: Main floor
                color: "#3b82f6"
              - entity: sensor.second_floor_current_humidity
                name: Second floor
                color: "#a855f7"
              - entity: sensor.master_bedroom_air_mon_humidity
                name: Master bedroom
                color: "#ec4899"
              - entity: sensor.bernadettes_room_humidity
                name: Girls room
                color: "#f97316"
              - entity: sensor.guest_bedroom_thermometer_humidity
                name: Guest bedroom
                color: "#14b8a6"
              - entity: sensor.kitchen_humidity
                name: Kitchen
                color: "#f59e0b"
              - entity: sensor.basement_air_mon_humidity
                name: Basement
                color: "#64748b"

      - type: grid
        cards:
          - type: heading
            heading: Air quality
            icon: mdi:blur
          - type: custom:mini-graph-card
            name: PM2.5
            icon: mdi:blur
            hours_to_show: 24
            points_per_hour: 2
            line_width: 2
            entities:
              - entity: sensor.airnow_pm2_5
                name: Outside
                color: "#22c55e"
              - entity: sensor.vital_200s_series_pm2_5
                name: Indoor
                color: "#ec4899"
