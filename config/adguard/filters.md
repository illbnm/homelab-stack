# AdGuard Home Filter Lists Configuration
# After initial setup, add these filter lists via the Web UI:
# Filters → DNS Blocklists → Add Blocklist → Add a custom list
#
# Or place this file and configure AdGuard Home to import it.

# Recommended DNS Blocklists:

# Built-in (enabled by default):
# - AdGuard DNS filter

# Additional recommended lists:
- name: "EasyList"
  url: "https://easylist.to/easylist/easylist.txt"
  enabled: true

- name: "EasyPrivacy"
  url: "https://easylist.to/easylist/easyprivacy.txt"
  enabled: true

- name: "Peter Lowe's Ad and tracking server list"
  url: "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus&showintro=0&mimetype=plaintext"
  enabled: true

- name: "Steven Black's Unified Hosts"
  url: "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  enabled: true

- name: "OISD Basic"
  url: "https://small.oisd.nl/basic"
  enabled: true

- name: "HaGeZi's Multi NORMAL"
  url: "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/multi.txt"
  enabled: true

# Privacy & Security:
- name: "MalwareURL Blocklist"
  url: "https://gitlab.com/ZeroDot1/CoinBlockerLists/raw/master/list_browser.txt"
  enabled: true

- name: "Phishing Army Blocklist"
  url: "https://phishing.army/download/phishing_army_blocklist_extended.txt"
  enabled: false

# Whitelist domains (add to AdGuard Home → Filters → Custom filtering rules):
# @@||example.com^
# @@||cdn.example.com^
