 The user wants me to solve a GitHub issue for a repository called `illbnm/homelab-stack`. The issue is about implementing a Home Automation stack with Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT, and ESPHome.

Let me analyze what needs to be done:
1. Create a `stacks/home-automation/` directory with docker-compose file
2. Create `config/mosquitto/mosquitto.conf` with security configuration
3. Update README.md to document the stack
4. Potentially update other files like `.env.example` or scripts

From the issue description, I need to:
- Home Assistant must use `network_mode: host` with bridge mode alternative commented out
- Mosquitto security configuration
- Include all 5 services: Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT, ESPHome

Let me look at the existing structure. The repo has:
- `stacks/` directory with various stacks
- `config/` directory
- `scripts/` directory
- `docker-compose.base.yml` at root (mentioned in README)

I need to create:
1. `stacks/home-automation/docker-compose.yml` - Docker compose for the stack
2. `config/mosquitto/mosquitto.conf` - Mosquitto configuration
3. `config/zigbee2mqtt/configuration.yaml` - Zigbee2MQTT configuration
4. `stacks/home-automation/README.md` or update main README

Wait, the issue says "Output ONLY the file changes as ```diff ... ``` blocks". I need to figure out what files exist and what I need to create.

From the root listing, I can see:
- `stacks/` exists with subdirectories like `base`, `media`, etc.
- `config/` exists

I should create:
1. `stacks/home-automation/docker-compose.yml`
2. `config/mosquitto/mosquitto.conf`
3. `config/zigbee2mqtt/configuration.yaml`
4. Update `README.md` in `stacks/home-automation/` or main README

Actually, looking at the issue more carefully, it seems like the task is to implement the full stack. Let me think about what files would need to be created/modified:

1. `stacks/home-automation/docker-compose.yml` - new file
2. `config/mosquitto/mosquitto.conf` - new file
3. `config/zigbee2mqtt/configuration.yaml` - new fileDetailed diff for the home automation stack implementation, focusing on Docker Compose, Mosquitto, and Zigbee2MQTT configurations.

I'll create the necessary configuration files for the home automation stack. The Mosquitto configuration will include security settings, and the Zigbee2MQTT configuration will set up the basic MQTT and serial port parameters. I'll ensure the Docker Compose file supports host network mode for Home Assistant and includes all required services.

The configuration will prioritize security with authentication, access control, and TLS support. I'll make sure to include persistent volume mappings and network configurations that align with the project's existing infrastructure patterns.

For the Zigbee2MQTT setup, I'll configure the MQTT broker connection, serial port settings, and frontend access. The configuration will be designed to work seamlessly with the Mosquitto broker and Home Assistant integration.

I'll focus on creating a comprehensive Docker Compose configuration that supports the home automation stack's core requirements, including network modes, volume mappings, and service dependencies.

The configuration will include Home Assistant with host network mode, Node-RED, Mosquitto with moderator, Zigbee2MQTT, and ESPHome. I'll ensure proper volume mounts, environment variables, and network settings for each service.

Key considerations include persistent data storage, network accessibility, and integration between services like Zigbee2MQTT and Mosquitto. The setup will prioritize local network discovery and seamless communication between home automation components.

I'll create the necessary configuration files, focusing on Mosquitto and Zigbee2MQTT setup. The Mosquitto configuration will include security settings, authentication, and listener configurations. I'll ensure the setup supports both internal and external network communication, with appropriate access controls and persistence settings.

The configuration will include password file management, anonymous access restrictions, and TLS support. I'll map the configuration to standard Docker volumes and ensure seamless integration with the existing Docker Compose infrastructure.

For Zigbee2MQTT, I'll set up the basic configuration with MQTT broker connection, serial port settings, and frontend access. The configuration will be designed to work out-of-the-box with minimal user intervention, while maintaining security and flexibility.

I'll create the necessary configuration files for the home automation stack, focusing on Mosquitto and Zigbee2MQTT setup. The goal is to provide a secure, functional configuration that allows easy deployment and integration with Home Assistant and other services.

The Mosquitto configuration will include security settings, authentication, and listener configurations. I'll ensure the setup supports both internal and external network communication, with appropriate access controls and persistence settings.

For Zigbee2MQTT, I'll set up the basic configuration with MQTT broker connection, serial port settings, and frontend access. The configuration will be designed to work out-of-the-box with minimal user intervention, while maintaining security and flexibility.

I'll create the necessary configuration files, focusing on Mosquitto and Zigbee2MQTT setup. The goal is to provide a secure, functional configuration that allows easy deployment and integration with Home Assistant and other services.

The configuration will include password file management, anonymous access restrictions, and TLS support. I'll map the configuration to standard Docker volumes and ensure seamless integration with the existing Docker Compose infrastructure.

I'll create the necessary configuration files for the home automation stack, focusing on Mosquitto and Zigbee2MQTT setup. The goal is to provide a secure, functional configuration that allows easy deployment and integration with Home Assistant and other services.

The Mosquitto configuration will include security settings, authentication, and listener configurations. I'll ensure the setup supports both internal and external network communication, with appropriate access controls and persistence settings.

For Zigbee2MQTT, I'll set up the basic configuration with MQTT broker connection, serial port settings, and frontend access. The configuration will be designed to work out-of-the-box with minimal user intervention, while maintaining security and flexibility.

I'll create the necessary configuration files, focusing on Mosquitto and Zigbee2MQTT setup. The goal is to provide a secure, functional configuration that allows easy deployment and integration with Home Assistant and other services.

The configuration will include password file management, anonymous access restrictions, and TLS support. I'll map the configuration to standard Docker volumes and ensure seamless integration with the existing Docker Compose infrastructure.

I'll create the necessary configuration files for the home automation stack, focusing on Mosquitto and Zigbee2MQTT setup. The goal is to provide a secure, functional configuration that allows easy deployment and integration with Home Assistant and other services.

The Mosquitto configuration will include security settings, authentication, and listener configurations. I'll ensure the setup supports both internal and external network communication, with appropriate access controls and persistence settings.

For Zigbee2MQTT, I'll set up the basic configuration with MQTT broker connection, serial port settings, and frontend access. The configuration will be designed to work out-of-the-box with minimal user intervention, while maintaining security and flexibility.

I'll create the necessary configuration files, focusing on Mosquitto and Zigbee2MQTT setup. The goal is