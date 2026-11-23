---
title: Deliveries
views:
- title: Deliveries
  path: deliveries
  icon: mdi:truck-delivery
  type: sections
  max_columns: 2
  sections:
  - type: grid
    column_span: 2
    cards:
    - type: heading
      heading: Deliveries
      icon: mdi:truck-delivery
    - type: custom:mushroom-template-card
      entity: sensor.klakotko_gmail_com_mail_packages_in_transit
      primary: |-
        {% set delivering = states('sensor.klakotko_gmail_com_mail_packages_delivering') | int(0) %} {% set transit = states('sensor.klakotko_gmail_com_mail_packages_in_transit') | int(0) %} {% if delivering > 0 %}
          {{ delivering }} out for delivery
        {% elif transit > 0 %}
          {{ transit }} package{{ '' if transit == 1 else 's' }} in transit
        {% else %}
          No deliveries pending
        {% endif %}
      secondary: |-
        {% set ns = namespace(carriers=[]) %} {% for name, packages, delivering in [
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
        {% endfor %} {{ ns.carriers | join(' · ') }}
      icon: "{% set delivering = states('sensor.klakotko_gmail_com_mail_packages_delivering')
        | int(0) %} {{ 'mdi:truck-delivery' if delivering > 0 else 'mdi:package-variant-closed'
        }}"
      icon_color: "{% set delivering = states('sensor.klakotko_gmail_com_mail_packages_delivering')
        | int(0) %} {% set transit = states('sensor.klakotko_gmail_com_mail_packages_in_transit')
        | int(0) %} {{ 'green' if delivering > 0 else ('blue' if transit > 0 else
        'grey') }}"
      tap_action:
        action: more-info
      grid_options:
        columns: 12
    - type: custom:mushroom-entity-card
      entity: sensor.klakotko_gmail_com_mail_updated
      name: Last mail check
      icon: mdi:clock-outline
      icon_color: blue
    - type: entities
      title: Carrier counts
      state_color: true
      entities:
      - entity: sensor.klakotko_gmail_com_mail_amazon_packages
        name: Amazon
      - entity: sensor.klakotko_gmail_com_mail_dhl_packages
        name: DHL
      - entity: sensor.klakotko_gmail_com_mail_fedex_packages
        name: FedEx
      - entity: sensor.klakotko_gmail_com_mail_home_depot_packages
        name: Home Depot
      - entity: sensor.klakotko_gmail_com_mail_shopify_packages
        name: Shopify
      - entity: sensor.klakotko_gmail_com_mail_ups_packages
        name: UPS
      - entity: sensor.klakotko_gmail_com_mail_usps_packages
        name: USPS
