title: Home
views:
  - title: Home
    path: home
    icon: mdi:home
    type: sections
    max_columns: 3
    sections:
      - type: grid
        cards:
          - type: heading
            heading: Home
            icon: mdi:home
          - type: custom:mushroom-chips-card
            alignment: center
            chips:
              - type: template
                icon: mdi:solar-power
                icon_color: amber
                content: "{{ states('sensor.my_home_solar_power') | int(0) }} W solar"
              - type: template
                icon: mdi:transmission-tower
                icon_color: blue
                content: "{{ states('sensor.my_home_grid_power') | int(0) }} W grid"
              - type: template
                icon: mdi:home-lightning-bolt
                icon_color: purple
                content: "{{ states('sensor.my_home_load_power') | int(0) }} W load"
              - type: template
                icon: mdi:shield-home
                icon_color: >-
                  {{ 'green' if is_state('binary_sensor.utility_sink_leak', 'off')
                     and is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'off')
                     and is_state('binary_sensor.kitchen_sink_leak', 'off')
                     and is_state('binary_sensor.second_floor_bathroom_leak', 'off')
                     and is_state('binary_sensor.left_garage_door_contact', 'off')
                     and is_state('binary_sensor.right_garage_door_contact', 'off')
                     else 'red' }}
                content: >-
                  {{ 'All clear' if is_state('binary_sensor.utility_sink_leak', 'off')
                     and is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'off')
                     and is_state('binary_sensor.kitchen_sink_leak', 'off')
                     and is_state('binary_sensor.second_floor_bathroom_leak', 'off')
                     and is_state('binary_sensor.left_garage_door_contact', 'off')
                     and is_state('binary_sensor.right_garage_door_contact', 'off')
                     else 'Check alerts' }}
          - type: custom:mushroom-entity-card
            entity: sensor.my_home_solar_power
            name: Solar
            icon: mdi:solar-power
            icon_color: amber
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.my_home_grid_power
            name: Grid
            icon: mdi:transmission-tower
            icon_color: blue
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.my_home_load_power
            name: Home load
            icon: mdi:home-lightning-bolt
            icon_color: purple
            primary_info: state
            secondary_info: name

      - type: grid
        cards:
          - type: heading
            heading: Climate
            icon: mdi:thermometer
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
          - type: custom:mini-graph-card
            name: Indoor temperature
            icon: mdi:home-thermometer
            hours_to_show: 24
            points_per_hour: 2
            line_width: 2
            entities:
              - entity: sensor.main_floor_current_temperature
                name: Main floor
                color: "#3b82f6"
              - entity: sensor.second_floor_current_temperature
                name: Second floor
                color: "#a855f7"
              - entity: sensor.master_bedroom_temperature
                name: Master
                color: "#f59e0b"
              - entity: sensor.girls_room_temperature_and_humidity_temperature
                name: Girls room
                color: "#ec4899"
            show:
              labels: false
              legend: true

      - type: grid
        cards:
          - type: heading
            heading: Energy
            icon: mdi:flash
          - type: custom:mini-graph-card
            name: Energy flow
            icon: mdi:flash
            hours_to_show: 48
            points_per_hour: 1
            line_width: 2
            entities:
              - entity: sensor.my_home_solar_power
                name: Solar
                color: "#f59e0b"
              - entity: sensor.my_home_grid_power
                name: Grid
                color: "#3b82f6"
              - entity: sensor.my_home_load_power
                name: Load
                color: "#a855f7"
            show:
              labels: false
              legend: true
          - type: custom:mushroom-entity-card
            entity: sensor.my_home_solar_power
            name: Solar production
            icon: mdi:solar-power
            icon_color: amber
          - type: custom:mushroom-entity-card
            entity: sensor.my_home_grid_power
            name: Grid import
            icon: mdi:transmission-tower
            icon_color: blue
          - type: custom:mushroom-entity-card
            entity: sensor.my_home_load_power
            name: Current load
            icon: mdi:home-lightning-bolt
            icon_color: purple

      - type: grid
        cards:
          - type: heading
            heading: Security
            icon: mdi:shield-home
          - type: custom:auto-entities
            show_empty: false
            card:
              type: entities
              title: Active alerts
              state_color: true
            filter:
              include:
                - domain: binary_sensor
                  attributes:
                    device_class: moisture
                  state: "on"
                - domain: binary_sensor
                  attributes:
                    device_class: door
                  state: "on"
                - domain: binary_sensor
                  attributes:
                    device_class: window
                  state: "on"
                - entity_id: binary_sensor.*leak*
                  state: "on"
          - type: custom:mushroom-template-card
            primary: Utility sink
            secondary: >-
              {{ 'Leak detected' if is_state('binary_sensor.utility_sink_leak', 'on') else 'Dry' }}
            icon: >-
              {{ 'mdi:water-alert' if is_state('binary_sensor.utility_sink_leak', 'on') else 'mdi:water-check' }}
            icon_color: >-
              {{ 'red' if is_state('binary_sensor.utility_sink_leak', 'on') else 'green' }}
            entity: binary_sensor.utility_sink_leak
          - type: custom:mushroom-template-card
            primary: First floor bath sink
            secondary: >-
              {{ 'Leak detected' if is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on') else 'Dry' }}
            icon: >-
              {{ 'mdi:water-alert' if is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on') else 'mdi:water-check' }}
            icon_color: >-
              {{ 'red' if is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on') else 'green' }}
            entity: binary_sensor.first_floor_bathroom_sink_water_leak
          - type: custom:mushroom-template-card
            primary: Kitchen sink
            secondary: >-
              {{ 'Leak detected' if is_state('binary_sensor.kitchen_sink_leak', 'on') else 'Dry' }}
            icon: >-
              {{ 'mdi:water-alert' if is_state('binary_sensor.kitchen_sink_leak', 'on') else 'mdi:water-check' }}
            icon_color: >-
              {{ 'red' if is_state('binary_sensor.kitchen_sink_leak', 'on') else 'green' }}
            entity: binary_sensor.kitchen_sink_leak
          - type: custom:mushroom-template-card
            primary: Second floor bath
            secondary: >-
              {{ 'Leak detected' if is_state('binary_sensor.second_floor_bathroom_leak', 'on') else 'Dry' }}
            icon: >-
              {{ 'mdi:water-alert' if is_state('binary_sensor.second_floor_bathroom_leak', 'on') else 'mdi:water-check' }}
            icon_color: >-
              {{ 'red' if is_state('binary_sensor.second_floor_bathroom_leak', 'on') else 'green' }}
            entity: binary_sensor.second_floor_bathroom_leak
          - type: custom:mushroom-template-card
            primary: Left garage door
            secondary: >-
              {{ 'Open' if is_state('binary_sensor.left_garage_door_contact', 'on') else 'Closed' }}
            icon: >-
              {{ 'mdi:garage-open' if is_state('binary_sensor.left_garage_door_contact', 'on') else 'mdi:garage' }}
            icon_color: >-
              {{ 'orange' if is_state('binary_sensor.left_garage_door_contact', 'on') else 'green' }}
            entity: binary_sensor.left_garage_door_contact
          - type: custom:mushroom-template-card
            primary: Right garage door
            secondary: >-
              {{ 'Open' if is_state('binary_sensor.right_garage_door_contact', 'on') else 'Closed' }}
            icon: >-
              {{ 'mdi:garage-open' if is_state('binary_sensor.right_garage_door_contact', 'on') else 'mdi:garage' }}
            icon_color: >-
              {{ 'orange' if is_state('binary_sensor.right_garage_door_contact', 'on') else 'green' }}
            entity: binary_sensor.right_garage_door_contact

      - type: grid
        cards:
          - type: heading
            heading: Garage
            icon: mdi:garage
          - type: custom:mushroom-entity-card
            entity: sensor.garage_freezer_temperature
            name: Freezer
            icon: mdi:snowflake-thermometer
            icon_color: blue
          - type: custom:mushroom-entity-card
            entity: sensor.garage_fridge_temperature
            name: Fridge
            icon: mdi:fridge-thermometer
            icon_color: cyan
          - type: custom:mushroom-entity-card
            entity: sensor.garage_ambient_temperature
            name: Ambient
            icon: mdi:thermometer
            icon_color: amber
          - type: custom:mini-graph-card
            name: Garage temperatures
            icon: mdi:thermometer
            hours_to_show: 48
            points_per_hour: 1
            line_width: 2
            entities:
              - entity: sensor.garage_freezer_temperature
                name: Freezer
                color: "#3b82f6"
              - entity: sensor.garage_fridge_temperature
                name: Fridge
                color: "#06b6d4"
              - entity: sensor.garage_ambient_temperature
                name: Ambient
                color: "#f59e0b"
            show:
              labels: false
              legend: true

      - type: grid
        cards:
          - type: heading
            heading: Media
            icon: mdi:speaker
          - type: custom:mushroom-media-player-card
            entity: media_player.living_room_tv
            use_media_info: true
            show_volume_level: true
            media_controls:
              - on_off
              - play_pause
              - next
              - previous
            volume_controls:
              - volume_mute
              - volume_set
          - type: custom:mushroom-media-player-card
            entity: media_player.attic_tv
            use_media_info: true
            show_volume_level: true
            media_controls:
              - on_off
              - play_pause
              - next
              - previous
            volume_controls:
              - volume_mute
              - volume_set
          - type: custom:mushroom-media-player-card
            entity: media_player.office_speaker
            use_media_info: true
            show_volume_level: true
            media_controls:
              - on_off
              - play_pause
              - next
              - previous
            volume_controls:
              - volume_mute
              - volume_set

      - type: grid
        cards:
          - type: heading
            heading: Systems
            icon: mdi:server
          - type: custom:mushroom-chips-card
            alignment: start
            chips:
              - type: template
                icon: mdi:cpu-64-bit
                icon_color: >-
                  {{ 'red' if states('sensor.ironhide_cpu_usage') | int(0) > 80
                     else 'green' }}
                content: "{{ states('sensor.ironhide_cpu_usage') }}% CPU"
              - type: template
                icon: mdi:memory
                icon_color: >-
                  {{ 'red' if states('sensor.ironhide_memory_usage') | int(0) > 80
                     else 'green' }}
                content: "{{ states('sensor.ironhide_memory_usage') }}% RAM"
              - type: template
                icon: mdi:thermometer
                icon_color: >-
                  {{ 'red' if states('sensor.ironhide_temperature_coretemp_package_id_0') | int(0) > 75
                     else 'green' }}
                content: "{{ states('sensor.ironhide_temperature_coretemp_package_id_0') }}°C"
          - type: custom:mini-graph-card
            name: Ironhide load
            icon: mdi:server
            hours_to_show: 24
            points_per_hour: 2
            line_width: 2
            entities:
              - entity: sensor.ironhide_cpu_usage
                name: CPU
                color: "#3b82f6"
              - entity: sensor.ironhide_memory_usage
                name: Memory
                color: "#a855f7"
            show:
              labels: false
              legend: true
          - type: custom:auto-entities
            show_empty: false
            card:
              type: entities
              title: Updates available
              state_color: true
            filter:
              include:
                - domain: update
                  state: "on"
