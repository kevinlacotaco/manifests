title: Garage & Appliances
views:
  - title: Garage & Appliances
    path: garage
    icon: mdi:garage
    type: sections
    max_columns: 3
    sections:
      - type: grid
        cards:
          - type: heading
            heading: Garage & Appliances
            icon: mdi:garage
          - type: custom:mushroom-chips-card
            alignment: center
            chips:
              - type: template
                icon: mdi:snowflake-thermometer
                icon_color: blue
                content: "{{ states('sensor.garage_freezer_temperature') }}°F freezer"
              - type: template
                icon: mdi:fridge-thermometer
                icon_color: cyan
                content: "{{ states('sensor.garage_fridge_temperature') }}°F fridge"
              - type: template
                icon: mdi:thermometer
                icon_color: amber
                content: "{{ states('sensor.garage_ambient_temperature') }}°F ambient"
              - type: template
                icon: "{{ 'mdi:garage-open' if is_state('binary_sensor.left_garage_door_contact', 'on') or is_state('binary_sensor.right_garage_door_contact', 'on') else 'mdi:garage' }}"
                icon_color: "{{ 'red' if is_state('binary_sensor.left_garage_door_contact', 'on') or is_state('binary_sensor.right_garage_door_contact', 'on') else 'green' }}"
                content: "{{ 'Door open' if is_state('binary_sensor.left_garage_door_contact', 'on') or is_state('binary_sensor.right_garage_door_contact', 'on') else 'Doors closed' }}"
          - type: custom:mushroom-entity-card
            entity: sensor.garage_freezer_temperature
            name: Freezer
            icon: mdi:snowflake-thermometer
            icon_color: blue
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.garage_fridge_temperature
            name: Fridge
            icon: mdi:fridge-thermometer
            icon_color: cyan
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.garage_ambient_temperature
            name: Garage ambient
            icon: mdi:thermometer
            icon_color: amber
            primary_info: state
            secondary_info: name

      - type: grid
        cards:
          - type: heading
            heading: Temperature history
            icon: mdi:chart-line
          - type: custom:mini-graph-card
            name: Freezer, fridge, and ambient
            icon: mdi:thermometer-lines
            hours_to_show: 48
            points_per_hour: 2
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

      - type: grid
        cards:
          - type: heading
            heading: Humidity
            icon: mdi:water-percent
          - type: custom:mini-graph-card
            name: Garage humidity
            icon: mdi:water-percent
            hours_to_show: 48
            points_per_hour: 2
            line_width: 2
            entities:
              - entity: sensor.garage_freezer_humidity
                name: Freezer
                color: "#3b82f6"
              - entity: sensor.garage_fridge_humidity
                name: Fridge
                color: "#06b6d4"
              - entity: sensor.garage_ambient_humidity
                name: Ambient
                color: "#f59e0b"

      - type: grid
        cards:
          - type: heading
            heading: Garage plug
            icon: mdi:power-plug
          - type: custom:mushroom-entity-card
            entity: sensor.garage_plug_power
            name: Current power
            icon: mdi:flash
            icon_color: amber
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.garage_plug_energy
            name: Total energy
            icon: mdi:lightning-bolt
            icon_color: blue
            primary_info: state
            secondary_info: name

      - type: grid
        cards:
          - type: heading
            heading: Doors
            icon: mdi:garage
          - type: custom:mushroom-template-card
            primary: Left garage door
            secondary: >-
              {{ 'Open' if is_state('binary_sensor.left_garage_door_contact', 'on') else 'Closed' }}
            icon: >-
              {{ 'mdi:garage-open' if is_state('binary_sensor.left_garage_door_contact', 'on') else 'mdi:garage' }}
            icon_color: >-
              {{ 'red' if is_state('binary_sensor.left_garage_door_contact', 'on') else 'green' }}
          - type: custom:mushroom-template-card
            primary: Right garage door
            secondary: >-
              {{ 'Open' if is_state('binary_sensor.right_garage_door_contact', 'on') else 'Closed' }}
            icon: >-
              {{ 'mdi:garage-open' if is_state('binary_sensor.right_garage_door_contact', 'on') else 'mdi:garage' }}
            icon_color: >-
              {{ 'red' if is_state('binary_sensor.right_garage_door_contact', 'on') else 'green' }}
          - type: custom:mushroom-template-card
            primary: Left door battery
            secondary: >-
              {{ states('sensor.left_garage_door_battery') }}%
            icon: mdi:battery
            icon_color: >-
              {{ 'red' if states('sensor.left_garage_door_battery') | float(0) < 20 else 'green' }}
          - type: custom:mushroom-template-card
            primary: Right door battery
            secondary: >-
              {{ 'Low' if is_state('binary_sensor.right_garage_door_battery_low', 'on') else 'OK' }}
            icon: mdi:battery
            icon_color: >-
              {{ 'red' if is_state('binary_sensor.right_garage_door_battery_low', 'on') else 'green' }}
