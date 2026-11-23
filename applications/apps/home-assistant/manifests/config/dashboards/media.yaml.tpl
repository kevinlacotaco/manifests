title: Media
views:
  - title: Media
    path: media
    icon: mdi:speaker
    type: sections
    max_columns: 3
    sections:
      - type: grid
        cards:
          - type: heading
            heading: Media
            icon: mdi:speaker
          - type: custom:mushroom-chips-card
            alignment: center
            chips:
              - type: template
                icon: mdi:play-circle
                icon_color: green
                content: "{{ states.media_player | selectattr('state', 'eq', 'playing') | list | count }} playing"
              - type: template
                icon: mdi:television
                icon_color: blue
                content: "Living room {{ states('media_player.living_room_tv_2') }}"
              - type: template
                icon: mdi:television
                icon_color: purple
                content: "Attic {{ states('media_player.attic_tv_2') }}"
              - type: template
                icon: mdi:spotify
                icon_color: green
                content: "Spotify {{ states('media_player.spotify_kevin') }}"

      - type: grid
        cards:
          - type: heading
            heading: Attic
            icon: mdi:home-roof
          - type: custom:mushroom-media-player-card
            entity: media_player.attic_tv_2
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
            entity: media_player.attic_tv_2
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
            entity: media_player.denon_avr_s760h
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
            entity: media_player.googlehome3585
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
            heading: Kitchen
            icon: mdi:silverware-fork-knife
          - type: custom:mushroom-media-player-card
            entity: media_player.nesthubmax641f
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
            heading: Living Room
            icon: mdi:sofa
          - type: custom:mushroom-media-player-card
            entity: media_player.living_room_speaker
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
            entity: media_player.living_room_tv_2
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
            entity: media_player.living_room_tv_2
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
            heading: Master Bedroom
            icon: mdi:bed
          - type: custom:mushroom-media-player-card
            entity: media_player.bedroom_speaker
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
            heading: Office
            icon: mdi:desk
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
            heading: Other
            icon: mdi:speaker-multiple
          - type: custom:mushroom-media-player-card
            entity: media_player.all_non_office
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
            entity: media_player.downstairs_speakers
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
            entity: media_player.spotify_kevin
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
            entity: media_player.office_tv
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
