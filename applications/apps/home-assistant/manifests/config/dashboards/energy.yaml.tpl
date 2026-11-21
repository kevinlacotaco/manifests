title: Energy
views:
  - title: Energy
    path: energy
    icon: mdi:flash
    type: sections
    max_columns: 3
    sections:
      - type: grid
        cards:
          - type: heading
            heading: Energy
            icon: mdi:flash
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
          - type: custom:mushroom-template-card
            primary: >
              {% set coverage = states('sensor.home_solar_coverage') | float(0) %}
              {{ coverage | round(0) }}% solar
            secondary: >
              {% set coverage = states('sensor.home_solar_coverage') | float(0) %}
              {% set grid = states('sensor.home_grid_import_power') | float(0) %}
              {% if coverage >= 99.5 %}
                All energy is covered by solar
              {% elif coverage <= 0.5 %}
                All energy is coming from the grid
              {% else %}
                Grid is covering {{ grid | round(2) }} kW
              {% endif %}
            icon: >
              {% set coverage = states('sensor.home_solar_coverage') | float(0) %}
              {% if coverage >= 99.5 %}
                mdi:weather-sunny
              {% elif coverage <= 0.5 %}
                mdi:transmission-tower
              {% else %}
                mdi:solar-power-variant
              {% endif %}
            icon_color: >
              {% set coverage = states('sensor.home_solar_coverage') | float(0) %}
              {% if coverage >= 99.5 %}
                green
              {% elif coverage <= 0.5 %}
                blue
              {% else %}
                amber
              {% endif %}
          - type: custom:mushroom-entity-card
            entity: sensor.my_home_solar_power
            name: Solar
            icon: mdi:solar-power
            icon_color: amber
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-template-card
            entity: sensor.home_solar_energy_today
            primary: >
              {{ states('sensor.home_solar_energy_today') | float(0) | round(2) }} kWh
            secondary: Solar generated today
            icon: mdi:solar-power-variant
            icon_color: amber
            tap_action:
              action: more-info
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
          - type: custom:mini-graph-card
            name: Solar, grid, and load
            icon: mdi:chart-line
            hours_to_show: 48
            points_per_hour: 2
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

      - type: grid
        cards:
          - type: heading
            heading: Air conditioners
            icon: mdi:air-conditioner
          - type: custom:mushroom-entity-card
            entity: sensor.living_room_air_conditioner_energy_current
            name: Living room AC
            icon: mdi:air-conditioner
            icon_color: cyan
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.office_air_conditioner_energy_current
            name: Office AC
            icon: mdi:air-conditioner
            icon_color: cyan
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.master_air_conditioner_energy_current
            name: Master AC
            icon: mdi:air-conditioner
            icon_color: cyan
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.attic_ac_energy_current
            name: Attic AC
            icon: mdi:air-conditioner
            icon_color: cyan
            primary_info: state
            secondary_info: name

      - type: grid
        cards:
          - type: heading
            heading: Plugs & lights
            icon: mdi:power-plug
          - type: custom:mushroom-entity-card
            entity: sensor.living_room_floor_light_1_power
            name: Living room floor light 1
            icon: mdi:floor-lamp
            icon_color: amber
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.living_room_floor_light_2_power
            name: Living room floor light 2
            icon: mdi:floor-lamp
            icon_color: amber
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.garage_plug_power
            name: Garage plug
            icon: mdi:power-plug
            icon_color: blue
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.attic_plug_power
            name: Attic plug
            icon: mdi:power-plug
            icon_color: blue
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.bonus_room_plug_power
            name: Bonus room plug
            icon: mdi:power-plug
            icon_color: blue
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.madisons_bedroom_plug_power
            name: Madison's bedroom plug
            icon: mdi:power-plug
            icon_color: blue
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.string_lights_power
            name: String lights
            icon: mdi:string-lights
            icon_color: amber
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.christmas_tree_power
            name: Christmas tree
            icon: mdi:pine-tree
            icon_color: green
            primary_info: state
            secondary_info: name
  - type: grid
    cards:
      - type: heading
        heading: Heating Oil
        icon: mdi:oil
      - type: custom:mushroom-entity-card
        entity: sensor.windsor_heating_oil_300_399_credit
        name: 300–399 gal Credit
        icon: mdi:oil
        icon_color: amber
        secondary_info: state
      - type: statistics-graph
        title: 30-day price history
        entities:
          - sensor.windsor_heating_oil_300_399_credit
        days_to_show: 30
        chart_type: line
        stat_types:
          - mean
          - min
          - max
        grid_options:
          columns: 12
      - type: custom:mushroom-template-card
        entity: sensor.windsor_heating_oil_forecast_7d
        primary: >-
          {% if is_number(states('sensor.windsor_heating_oil_forecast_7d')) %}
          {{ states('sensor.windsor_heating_oil_forecast_7d') | float | round(2) }} $/gal
          {% else %}
          Collecting history
          {% endif %}
        secondary: 7-day linear trend
        icon: mdi:chart-timeline-variant
        icon_color: blue
