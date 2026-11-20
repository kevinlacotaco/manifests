title: Security & Cameras
views:
  - title: Security & Cameras
    path: security
    icon: mdi:shield-home
    type: sections
    max_columns: 3
    sections:
      - type: grid
        cards:
          - type: heading
            heading: Security & Cameras
            icon: mdi:shield-home
          - type: custom:mushroom-chips-card
            alignment: center
            chips:
              - type: template
                icon: mdi:account-alert
                icon_color: >-
                  {{ 'red' if is_state('binary_sensor.driveway_person_occupancy', 'on') else 'grey' }}
                content: >-
                  {{ 'Person at driveway' if is_state('binary_sensor.driveway_person_occupancy', 'on') else 'No person' }}
              - type: template
                icon: mdi:motion-sensor
                icon_color: >-
                  {{ 'red' if is_state('binary_sensor.main_floor_motion', 'on')
                     or is_state('binary_sensor.second_floor_motion', 'on') else 'grey' }}
                content: >-
                  {{ 'Motion inside' if is_state('binary_sensor.main_floor_motion', 'on')
                     or is_state('binary_sensor.second_floor_motion', 'on') else 'No motion' }}
              - type: template
                icon: mdi:garage
                icon_color: >-
                  {{ 'orange' if is_state('binary_sensor.left_garage_door_contact', 'on')
                     or is_state('binary_sensor.right_garage_door_contact', 'on') else 'green' }}
                content: >-
                  {{ 'Garage open' if is_state('binary_sensor.left_garage_door_contact', 'on')
                     or is_state('binary_sensor.right_garage_door_contact', 'on') else 'Garage closed' }}
              - type: template
                icon: mdi:water-check
                icon_color: >-
                  {{ 'red' if is_state('binary_sensor.utility_sink_leak', 'on')
                     or is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on')
                     or is_state('binary_sensor.kitchen_sink_leak', 'on')
                     or is_state('binary_sensor.second_floor_bathroom_leak', 'on') else 'green' }}
                content: >-
                  {{ 'Leak detected' if is_state('binary_sensor.utility_sink_leak', 'on')
                     or is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on')
                     or is_state('binary_sensor.kitchen_sink_leak', 'on')
                     or is_state('binary_sensor.second_floor_bathroom_leak', 'on') else 'No leaks' }}

      - type: grid
        cards:
          - type: heading
            heading: Live cameras
            icon: mdi:cctv
          - type: custom:frigate-modern-hass-card
            title: Cameras
            subtitle: Driveway, Attic 3, and Attic 4
            default_view: grid
            live_provider: hls
            grid_columns: 2
            stack_on_mobile: true
            stream_height: 720
            window_hours: 24
            cameras:
              - entity: camera.driveway
                name: Driveway
              - entity: camera.attic_3
                name: Attic 3
              - entity: camera.attic_4
                name: Attic 4
          - type: custom:mushroom-template-card
            primary: Attic 1 & Attic 2
            secondary: Offline — no route to host
            icon: mdi:cctv-off
            icon_color: red
            entity: camera.attic_1

      - type: grid
        cards:
          - type: heading
            heading: Active alerts
            icon: mdi:alert
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

      - type: grid
        cards:
          - type: heading
            heading: Water & freeze
            icon: mdi:water-alert
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
            name: Garage ambient
            icon: mdi:thermometer
            icon_color: amber

      - type: grid
        cards:
          - type: heading
            heading: Motion & occupancy
            icon: mdi:motion-sensor
          - type: custom:mushroom-entity-card
            entity: binary_sensor.main_floor_motion
            name: Main floor motion
            icon: mdi:motion-sensor
            icon_color: red
          - type: custom:mushroom-entity-card
            entity: binary_sensor.main_floor_occupancy
            name: Main floor occupancy
            icon: mdi:home-account
            icon_color: blue
          - type: custom:mushroom-entity-card
            entity: binary_sensor.second_floor_motion
            name: Second floor motion
            icon: mdi:motion-sensor
            icon_color: red
          - type: custom:mushroom-entity-card
            entity: binary_sensor.second_floor_occupancy
            name: Second floor occupancy
            icon: mdi:home-account
            icon_color: blue
          - type: custom:mushroom-entity-card
            entity: binary_sensor.driveway_motion
            name: Driveway motion
            icon: mdi:motion-sensor
            icon_color: orange
          - type: custom:mushroom-entity-card
            entity: binary_sensor.driveway_person_occupancy
            name: Driveway person
            icon: mdi:account-alert
            icon_color: red
          - type: custom:mushroom-entity-card
            entity: binary_sensor.driveway_cat_occupancy
            name: Driveway cat
            icon: mdi:cat
            icon_color: purple

      - type: grid
        cards:
          - type: heading
            heading: Garage doors
            icon: mdi:garage
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
          - type: custom:mushroom-entity-card
            entity: binary_sensor.right_garage_door_battery_low
            name: Right garage door battery
            icon: mdi:battery-alert
            icon_color: red
