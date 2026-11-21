title: Overview
views:
  - title: Overview
    path: overview
    icon: mdi:view-dashboard
    type: sections
    max_columns: 3
    sections:
      - type: grid
        column_span: 2
        cards:
          - type: heading
            heading: Overview
            icon: mdi:view-dashboard

          - type: custom:mushroom-template-card
            primary: >-
              {% set leaks = (is_state('binary_sensor.utility_sink_leak', 'on') | int)
                + (is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on') | int)
                + (is_state('binary_sensor.kitchen_sink_leak', 'on') | int)
                + (is_state('binary_sensor.second_floor_bathroom_leak', 'on') | int) %}
              {% set doors = (is_state('binary_sensor.left_garage_door_contact', 'on') | int)
                + (is_state('binary_sensor.right_garage_door_contact', 'on') | int) %}
              {{ 'All clear' if leaks == 0 and doors == 0 else 'Attention needed' }}
            secondary: >-
              {% set leaks = (is_state('binary_sensor.utility_sink_leak', 'on') | int)
                + (is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on') | int)
                + (is_state('binary_sensor.kitchen_sink_leak', 'on') | int)
                + (is_state('binary_sensor.second_floor_bathroom_leak', 'on') | int) %}
              {% set doors = (is_state('binary_sensor.left_garage_door_contact', 'on') | int)
                + (is_state('binary_sensor.right_garage_door_contact', 'on') | int) %}
              {{ leaks }} leak{{ '' if leaks == 1 else 's' }} · {{ doors }} door{{ '' if doors == 1 else 's' }} open
            icon: >-
              {% set leaks = (is_state('binary_sensor.utility_sink_leak', 'on') | int)
                + (is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on') | int)
                + (is_state('binary_sensor.kitchen_sink_leak', 'on') | int)
                + (is_state('binary_sensor.second_floor_bathroom_leak', 'on') | int) %}
              {% set doors = (is_state('binary_sensor.left_garage_door_contact', 'on') | int)
                + (is_state('binary_sensor.right_garage_door_contact', 'on') | int) %}
              {{ 'mdi:shield-check' if leaks == 0 and doors == 0 else 'mdi:shield-alert' }}
            icon_color: >-
              {% set leaks = (is_state('binary_sensor.utility_sink_leak', 'on') | int)
                + (is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on') | int)
                + (is_state('binary_sensor.kitchen_sink_leak', 'on') | int)
                + (is_state('binary_sensor.second_floor_bathroom_leak', 'on') | int) %}
              {% set doors = (is_state('binary_sensor.left_garage_door_contact', 'on') | int)
                + (is_state('binary_sensor.right_garage_door_contact', 'on') | int) %}
              {{ 'green' if leaks == 0 and doors == 0 else 'red' }}
            tap_action:
              action: navigate
              navigation_path: /security-cameras

          - type: custom:mushroom-template-card
            primary: >-
              {% set main = states('sensor.main_floor_current_temperature') %}
              {{ ((main | float | round(0)) ~ '°F main') if is_number(main) else 'Main temp unavailable' }}
            secondary: >-
              {% set upstairs = states('sensor.second_floor_current_temperature') %}
              {% set attic = states('sensor.attic_monitor_temperature') %}
              Upstairs {{ ((upstairs | float | round(0)) ~ '°F') if is_number(upstairs) else '—' }} · Attic {{ ((attic | float | round(0)) ~ '°F') if is_number(attic) else '—' }}
            icon: mdi:home-thermometer
            icon_color: blue
            tap_action:
              action: navigate
              navigation_path: /climate-air

          - type: custom:mushroom-template-card
            primary: >-
              {% set today = states('sensor.home_solar_energy_today') %}
              {{ ((today | float | round(2)) ~ ' kWh solar') if is_number(today) else 'Solar total unavailable' }}
            secondary: >-
              {% set coverage = states('sensor.home_solar_coverage') %}
              {% set grid = states('sensor.my_home_grid_power') %}
              {% if coverage not in ['unknown', 'unavailable'] and grid not in ['unknown', 'unavailable'] %}
                {{ coverage | float(0) | round(0) }}% covered · grid {{ grid | float(0) | round(2) }} kW
              {% else %}
                Live solar data unavailable
              {% endif %}
            icon: mdi:solar-power-variant
            icon_color: amber
            tap_action:
              action: navigate
              navigation_path: /energy-view

          - type: custom:mushroom-template-card
            primary: >-
              {% set freezer = states('sensor.garage_freezer_temperature') %}
              {{ ((freezer | float | round(1)) ~ '°F freezer') if is_number(freezer) else 'Freezer unavailable' }}
            secondary: >-
              {% set fridge = states('sensor.garage_fridge_temperature') %}
              {% set detached = states('sensor.detached_garage_temperature') %}
              Fridge {{ ((fridge | float | round(1)) ~ '°F') if is_number(fridge) else '—' }} · Detached {{ ((detached | float | round(1)) ~ '°F') if is_number(detached) else '—' }}
            icon: mdi:fridge-thermometer
            icon_color: >-
              {{ 'red' if (states('sensor.garage_freezer_temperature') | float(0) > 10)
                 or (states('sensor.garage_fridge_temperature') | float(0) > 46.4)
                 else 'cyan' }}
            tap_action:
              action: navigate
              navigation_path: /garage-appliances

          - type: custom:mushroom-template-card
            primary: "CPU {{ states('sensor.ironhide_cpu_usage') | float(0) | round(0) }}% · RAM {{ states('sensor.ironhide_memory_usage') | float(0) | round(0) }}%"
            secondary: >-
              {% set updates = states.update | selectattr('state', 'eq', 'on') | list | count %}
              {{ updates }} update{{ '' if updates == 1 else 's' }} · {{ states('sensor.ironhide_temperature_coretemp_package_id_0') | float(0) | round(0) }}°F
            icon: mdi:server
            icon_color: >-
              {{ 'red' if (states('sensor.ironhide_cpu_usage') | float(0) > 80)
                 or (states('sensor.ironhide_memory_usage') | float(0) > 80)
                 or (states('sensor.ironhide_temperature_coretemp_package_id_0') | float(0) > 167)
                 else 'green' }}
            tap_action:
              action: navigate
              navigation_path: /systems-maintenance


      - type: grid
        column_span: 3
        cards:
          - type: heading
            heading: Deliveries
            icon: mdi:truck-delivery

          - type: custom:mushroom-template-card
            entity: sensor.klakotko_gmail_com_mail_packages_in_transit
            primary: >-
              {% set delivering = states('sensor.klakotko_gmail_com_mail_packages_delivering') | int(0) %}
              {% set transit = states('sensor.klakotko_gmail_com_mail_packages_in_transit') | int(0) %}
              {% if delivering > 0 %}
                {{ delivering }} out for delivery
              {% elif transit > 0 %}
                {{ transit }} package{{ '' if transit == 1 else 's' }} in transit
              {% else %}
                No deliveries pending
              {% endif %}
            secondary: >-
              {% set ns = namespace(carriers=[]) %}
              {% for name, packages, delivering in [
                ('Amazon', 'sensor.klakotko_gmail_com_mail_amazon_packages', 'sensor.klakotko_gmail_com_mail_amazon_packages_delivering'),
                ('DHL', 'sensor.klakotko_gmail_com_mail_dhl_packages', 'sensor.klakotko_gmail_com_mail_dhl_delivering'),
                ('FedEx', 'sensor.klakotko_gmail_com_mail_fedex_packages', 'sensor.klakotko_gmail_com_mail_fedex_delivering'),
                ('Home Depot', 'sensor.klakotko_gmail_com_mail_home_depot_packages', 'sensor.klakotko_gmail_com_mail_home_depot_delivering'),
                ('Shopify', 'sensor.klakotko_gmail_com_mail_shopify_packages', 'sensor.klakotko_gmail_com_mail_shopify_delivering'),
                ('UPS', 'sensor.klakotko_gmail_com_mail_ups_packages', 'sensor.klakotko_gmail_com_mail_ups_delivering'),
                ('USPS', 'sensor.klakotko_gmail_com_mail_usps_packages', 'sensor.klakotko_gmail_com_mail_usps_delivering')
              ] %}
                {% set count = states(packages) | int(0) %}
                {% set out = states(delivering) | int(0) %}
                {% set ns.carriers = ns.carriers + [name ~ ' ' ~ count ~ ((' (' ~ out ~ ' out)') if out > 0 else '')] %}
              {% endfor %}
              {{ ns.carriers | join(' · ') }}
            icon: >-
              {% set delivering = states('sensor.klakotko_gmail_com_mail_packages_delivering') | int(0) %}
              {{ 'mdi:truck-delivery' if delivering > 0 else 'mdi:package-variant-closed' }}
            icon_color: >-
              {% set delivering = states('sensor.klakotko_gmail_com_mail_packages_delivering') | int(0) %}
              {% set transit = states('sensor.klakotko_gmail_com_mail_packages_in_transit') | int(0) %}
              {{ 'green' if delivering > 0 else ('blue' if transit > 0 else 'grey') }}
            tap_action:
              action: more-info
            grid_options:
              columns: 12

      - type: grid
        cards:
          - type: heading
            heading: Climate
            icon: mdi:thermometer

          - type: custom:mushroom-chips-card
            alignment: start
            chips:
              - type: template
                icon: mdi:water-percent
                icon_color: cyan
                content: >-
                  {% set h = states('sensor.main_floor_current_humidity') %}
                  Main {{ ((h | float | round(0)) ~ '%') if is_number(h) else '—' }}
              - type: template
                icon: mdi:water-percent
                icon_color: cyan
                content: >-
                  {% set h = states('sensor.second_floor_current_humidity') %}
                  Upstairs {{ ((h | float | round(0)) ~ '%') if is_number(h) else '—' }}
              - type: template
                icon: mdi:water-percent
                icon_color: cyan
                content: >-
                  {% set h = states('sensor.attic_monitor_humidity') %}
                  Attic {{ ((h | float | round(0)) ~ '%') if is_number(h) else '—' }}

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
                name: Upstairs
                color: "#a855f7"
              - entity: sensor.kitchen_temperature
                name: Kitchen
                color: "#f59e0b"
              - entity: sensor.attic_monitor_temperature
                name: Attic
                color: "#ef4444"
              - entity: sensor.basement_air_mon_temperature
                name: Basement
                color: "#64748b"
            show:
              labels: false
              legend: true

      - type: grid
        cards:
          - type: heading
            heading: Security & Garage
            icon: mdi:shield-home

          - type: custom:mushroom-chips-card
            alignment: start
            chips:
              - type: template
                icon: >-
                  {{ 'mdi:water-alert' if (is_state('binary_sensor.utility_sink_leak', 'on')
                     or is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on')
                     or is_state('binary_sensor.kitchen_sink_leak', 'on')
                     or is_state('binary_sensor.second_floor_bathroom_leak', 'on'))
                     else 'mdi:water-check' }}
                icon_color: >-
                  {{ 'red' if (is_state('binary_sensor.utility_sink_leak', 'on')
                     or is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on')
                     or is_state('binary_sensor.kitchen_sink_leak', 'on')
                     or is_state('binary_sensor.second_floor_bathroom_leak', 'on'))
                     else 'green' }}
                content: >-
                  {{ 'Leak detected' if (is_state('binary_sensor.utility_sink_leak', 'on')
                     or is_state('binary_sensor.first_floor_bathroom_sink_water_leak', 'on')
                     or is_state('binary_sensor.kitchen_sink_leak', 'on')
                     or is_state('binary_sensor.second_floor_bathroom_leak', 'on'))
                     else 'Leaks clear' }}
              - type: template
                icon: >-
                  {{ 'mdi:garage-open' if (is_state('binary_sensor.left_garage_door_contact', 'on')
                     or is_state('binary_sensor.right_garage_door_contact', 'on'))
                     else 'mdi:garage' }}
                icon_color: >-
                  {{ 'orange' if (is_state('binary_sensor.left_garage_door_contact', 'on')
                     or is_state('binary_sensor.right_garage_door_contact', 'on'))
                     else 'green' }}
                content: >-
                  {{ 'Doors open' if (is_state('binary_sensor.left_garage_door_contact', 'on')
                     or is_state('binary_sensor.right_garage_door_contact', 'on'))
                     else 'Doors closed' }}
              - type: template
                icon: mdi:thermometer
                icon_color: amber
                content: >-
                  {% set garage = states('sensor.garage_ambient_temperature') %}
                  Garage {{ ((garage | float | round(0)) ~ '°F') if is_number(garage) else '—' }}

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
                name: Garage
                color: "#f59e0b"
              - entity: sensor.detached_garage_temperature
                name: Detached
                color: "#22c55e"
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
            show_volume_level: false
            media_controls:
              - on_off
              - play_pause

          - type: custom:mushroom-media-player-card
            entity: media_player.attic_tv
            use_media_info: true
            show_volume_level: false
            media_controls:
              - on_off
              - play_pause
      - type: grid
        column_span: 2
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
                  {{ 'red' if states('sensor.ironhide_cpu_usage') | float(0) > 80 else 'green' }}
                content: "CPU {{ states('sensor.ironhide_cpu_usage') | float(0) | round(0) }}%"
              - type: template
                icon: mdi:memory
                icon_color: >-
                  {{ 'red' if states('sensor.ironhide_memory_usage') | float(0) > 80 else 'green' }}
                content: "RAM {{ states('sensor.ironhide_memory_usage') | float(0) | round(0) }}%"
              - type: template
                icon: mdi:thermometer
                icon_color: >-
                  {{ 'red' if states('sensor.ironhide_temperature_coretemp_package_id_0') | float(0) > 167 else 'green' }}
                content: "{{ states('sensor.ironhide_temperature_coretemp_package_id_0') | float(0) | round(0) }}°F"

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

          - type: custom:auto-entities
            show_empty: false
            card:
              type: entities
              title: Low batteries
              state_color: true
            filter:
              include:
                - domain: sensor
                  attributes:
                    device_class: battery
                  state: "<25"
