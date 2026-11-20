title: Systems & Maintenance
views:
  - title: Systems & Maintenance
    path: systems
    icon: mdi:server
    type: sections
    max_columns: 3
    sections:
      - type: grid
        cards:
          - type: heading
            heading: Systems & Maintenance
            icon: mdi:server
          - type: custom:mushroom-chips-card
            alignment: center
            chips:
              - type: template
                icon: mdi:cpu-64-bit
                icon_color: blue
                content: "{{ states('sensor.ironhide_cpu_usage') }}% CPU"
              - type: template
                icon: mdi:memory
                icon_color: purple
                content: "{{ states('sensor.ironhide_memory_usage') }}% RAM"
              - type: template
                icon: mdi:thermometer
                icon_color: amber
                content: "{{ states('sensor.ironhide_temperature_coretemp_package_id_0') }}°C"
              - type: template
                icon: mdi:backup-restore
                icon_color: green
                content: "Backup {{ states('sensor.backup_manager_state') }}"
          - type: custom:mushroom-entity-card
            entity: sensor.ironhide_cpu_usage
            name: CPU usage
            icon: mdi:cpu-64-bit
            icon_color: blue
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.ironhide_memory_usage
            name: Memory usage
            icon: mdi:memory
            icon_color: purple
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.ironhide_temperature_coretemp_package_id_0
            name: Package temperature
            icon: mdi:thermometer
            icon_color: amber
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.ironhide_gpu_nvidia_0_load
            name: GPU load
            icon: mdi:expansion-card
            icon_color: green
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.ironhide_gpu_nvidia_0_temperature
            name: GPU temperature
            icon: mdi:thermometer
            icon_color: red
            primary_info: state
            secondary_info: name
          - type: custom:mini-graph-card
            name: Ironhide load
            icon: mdi:chart-line
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
              - entity: sensor.ironhide_gpu_nvidia_0_load
                name: GPU
                color: "#22c55e"

      - type: grid
        cards:
          - type: heading
            heading: Backups
            icon: mdi:backup-restore
          - type: custom:mushroom-entity-card
            entity: sensor.backup_manager_state
            name: Backup state
            icon: mdi:backup-restore
            icon_color: green
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.backup_next_scheduled_automatic_backup
            name: Next backup
            icon: mdi:calendar-clock
            icon_color: blue
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.backup_last_successful_automatic_backup
            name: Last successful
            icon: mdi:check-circle
            icon_color: green
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.backup_last_attempted_automatic_backup
            name: Last attempted
            icon: mdi:clock-outline
            icon_color: amber
            primary_info: state
            secondary_info: name
          - type: custom:mushroom-entity-card
            entity: sensor.backup_last_successful_automatic_backup_size
            name: Backup size
            icon: mdi:database
            icon_color: purple
            primary_info: state
            secondary_info: name

      - type: grid
        cards:
          - type: heading
            heading: Updates
            icon: mdi:package-up
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

      - type: grid
        cards:
          - type: heading
            heading: Batteries
            icon: mdi:battery
          - type: custom:auto-entities
            show_empty: false
            card:
              type: entities
              title: Batteries (lowest first)
              state_color: true
            filter:
              include:
                - domain: sensor
                  attributes:
                    device_class: battery
            sort:
              method: state
              numeric: true
              reverse: false

      - type: grid
        cards:
          - type: heading
            heading: Consumables
            icon: mdi:printer
          - type: entities
            title: Ink and filters
            state_color: true
            entities:
              - entity: sensor.mfc_j4335dw_black_ink_remaining
              - entity: sensor.mfc_j4335dw_cyan_ink_remaining
              - entity: sensor.mfc_j4335dw_magenta_ink_remaining
              - entity: sensor.mfc_j4335dw_yellow_ink_remaining
              - entity: sensor.roborock_q5_2_filter_time_left
              - entity: sensor.roborock_q5_filter_time_left
              - entity: sensor.living_room_ac_filter_life
              - entity: sensor.office_air_conditioner_filter_remaining_life
              - entity: sensor.master_air_conditioner_filter_remaining_life
              - entity: sensor.attic_ac_filter_remaining_life

      - type: grid
        cards:
          - type: heading
            heading: Host telemetry
            icon: mdi:server
          - type: custom:mini-graph-card
            name: Host temperatures
            icon: mdi:thermometer-lines
            hours_to_show: 24
            points_per_hour: 2
            line_width: 2
            entities:
              - entity: sensor.ironhide_temperature_coretemp_package_id_0
                name: CPU package
                color: "#ef4444"
              - entity: sensor.ironhide_temperature_nvme_composite
                name: NVMe composite
                color: "#3b82f6"
              - entity: sensor.ironhide_temperature_nvme_sensor_1
                name: NVMe sensor 1
                color: "#06b6d4"
              - entity: sensor.ironhide_temperature_nvme_sensor_2
                name: NVMe sensor 2
                color: "#a855f7"
              - entity: sensor.ironhide_temperature_acpitz
                name: ACPI
                color: "#f59e0b"
          - type: custom:mini-graph-card
            name: Disk usage
            icon: mdi:harddisk
            hours_to_show: 24
            points_per_hour: 2
            line_width: 2
            entities:
              - entity: sensor.ironhide_disk_dev_nvme0n1p2
                name: NVMe root
                color: "#3b82f6"
              - entity: sensor.ironhide_disk_dev_sdb1
                name: sdb1
                color: "#22c55e"
              - entity: sensor.ironhide_disk_dev_sdc1
                name: sdc1
                color: "#f59e0b"
              - entity: sensor.ironhide_disk_dev_sdd1
                name: sdd1
                color: "#ef4444"
              - entity: sensor.ironhide_disk_dev_sde1
                name: sde1
                color: "#a855f7"
          - type: entities
            title: Host status
            state_color: true
            entities:
              - entity: sensor.ironhide_disk_io_nvme0n1
              - entity: sensor.ironhide_disk_io_sdb
              - entity: sensor.ironhide_gpu_nvidia_0_memory
              - entity: binary_sensor.ironhide_system_updates
              - entity: binary_sensor.ironhide_required_restart
