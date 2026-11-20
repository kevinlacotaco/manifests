- sensor:
    - name: "Home Solar Coverage"
      unique_id: home_solar_coverage
      unit_of_measurement: "%"
      state_class: measurement
      icon: mdi:solar-power
      availability: >
        {{ states('sensor.my_home_load_power') not in ['unknown', 'unavailable', 'none']
           and states('sensor.my_home_grid_power') not in ['unknown', 'unavailable', 'none'] }}
      state: >
        {% set load = states('sensor.my_home_load_power') | float(0) %}
        {% set grid = states('sensor.my_home_grid_power') | float(0) %}
        {% set grid_import = [grid, 0] | max %}
        {% if load <= 0 %}
          100
        {% else %}
          {{ (((load - grid_import) / load) * 100) | round(1) }}
        {% endif %}

    - name: "Home Grid Import Power"
      unique_id: home_grid_import_power
      unit_of_measurement: "kW"
      device_class: power
      state_class: measurement
      icon: mdi:transmission-tower
      availability: >
        {{ states('sensor.my_home_grid_power') not in ['unknown', 'unavailable', 'none'] }}
      state: >
        {{ [states('sensor.my_home_grid_power') | float(0), 0] | max | round(3) }}
