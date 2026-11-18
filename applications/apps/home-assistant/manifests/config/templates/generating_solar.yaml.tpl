- binary_sensor:
    - name: "Generating Solar"
      # Grid power is unavailable while the inverter or Modbus integration is
      # down. Return no state in that case instead of raising a float error.
      state: >
        {% set raw = states('sensor.my_home_grid_power') %}
        {% if raw not in ['unknown', 'unavailable', 'none'] %}
          {{ (raw | float(0)) == 0 }}
        {% endif %}
