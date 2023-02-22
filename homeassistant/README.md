## 5. Home Assistant

I'm locked out! Now what?
https://www.home-assistant.io/docs/locked_out/

Possible Lovelace yaml starter: https://community.home-assistant.io/t/my-hass-io-and-lovelace-setup-updated/72902

### 5.1. Z-Wave and Zigbee Controller Setup

This setup uses a Nortek GoControl Linear HUSBZB-1 USB stick which is a 2-in-1 USB radio with Z-Wave and ZigBee, which uses a different USB device-id for each radio. After plugging the device into the server, check the device-id with

    ls -l /dev/serial/by-id

This output should look like: 

    pi@raspberrypi:~ $ ls -l /dev/serial/by-id
    total 0
    lrwxrwxrwx 1 root root 13 Feb 18 17:19 usb-Silicon_Labs_HubZ_Smart_Home_Controller_4150060D-if00-port0 -> ../../ttyUSB0
    lrwxrwxrwx 1 root root 13 Feb 18 17:19 usb-Silicon_Labs_HubZ_Smart_Home_Controller_4150060D-if01-port0 -> ../../ttyUSB1

Then confirm which radio is linked to which device-id with

    udevadm info -a -n /dev/ttyUSB0 | grep '{interface}' | head -n1

yields

    ATTRS{interface}=="HubZ Z-Wave Com Port"
and 

    udevadm info -a -n /dev/ttyUSB1 | grep '{interface}' | head -n1

yields

    TTRS{interface}=="HubZ ZigBee Com Port"

This tells us that `/dev/ttyUSB0` is the Z-Wave radio and `/dev/ttyUSB1` is the ZigBee radio. Now it's necessary to pass these devices into the Docker container, so add the following to the docker-compose.yml such that the z-wave and zigbee usb ports are easily identifiable inside the container

    devices:
      - /dev/ttyUSB0:/zwaveusbstick
      - /dev/ttyUSB1:/zigbeeusbstick

Source: https://community.home-assistant.io/t/device-path-for-usb-stick/276546/5

The zigbee radio may be automatically found by Home Assistant. Check this by going into `Configurations > Integrations` and click `Add Integration`. `Add Zigbee device` should show above all the available Home Assistant integrations.

Alternatively, search for and select `Zigbee Home Automation` (often referred to as `ZHA`). Select the radio type EZSP, as this is what the HUSBZB-1 uses. On the next screen, the serial device path will be the name of the device in the container: `/zigbeeusbstick`. Leave the other fields at their defaults. Home Assistant should find the zigbee device and it's ready to find devices! You can rename the device from its `/zigbeeusbstick` to whatever you like (e.g. `Zigbee USB Stick`) in the device settings. 

An alternative solution to ZHA is zigbee2mqtt. This requires a bit more setup but may offer increased functionality. This is not implemented at this time.

#### 5.1.1. Updating Zigbee Firmware

[walthowd](https://github.com/walthowd) has a Docker image that provides an environment to update the Zigbee firmware of the HUSBZB-1. The instructions in the `README.md` may not be sufficient on their own. For reference, walthowd's `README.md` instructions pull a pre-built the container (for amd64, e.g. Intel architecture) from Docker Hub. Instead, if using a different architecture, building the image and container manually will pull the appriopriate (e.g. arm/v7) versions of the packages and dependencies. The instructions for RPi3, which requires arm/v7, are documented here.

1. Build the docker image using [walthowd's Dockerfile](https://github.com/walthowd/husbzb-firmware) on git manually. This tells Docker to go to this repository, find the Dockerfile, and execute the instructions which builds the image with the image name after `-t`. This will take awhile. It's building two images. One is named python:buster and the other is named whatever tag (after `-t`) is given.

        docker build https://github.com/walthowd/husbzb-firmware.git -t zigbee_fw_update

        docker run --rm --device=/dev/ttyUSB1:/dev/ttyUSB1 -it zigbee_fw_update bash

2. From inside the container (the command line look something like this root@992b95871b72:/tmp/silabs#), run ncp.py to detect your USB stick and report current firmware version.

        ./ncp.py scan

    yields

        Connecting to.. /dev/ttyUSB1 57600 True False 
        {"ports": [{"port": "/dev/ttyUSB1", "vid": "10C4", "pid": "8A2A", "deviceType": "zigbee", "stackVersion": "5.4.1-194"}]}

3. Next, run the following command to flash the Zigbee firmware (/dev/ttyUSB1) with the latest firmware (*.ebl). Update this firmware file name as needed.

        ./ncp.py flash -p /dev/ttyUSB1 -f ncp-uart-sw-6.7.8.ebl

    While this happens, the output will be

        Restarting NCP into Bootloader mode...
        CEL stick
        EM3581 Serial Bootloader v5.4.1.0 b962

        Successfully restarted into bootloader mode! Starting upload of NCP image... 
        Finished!
        Rebooting NCP...

4. Then let's confirm the firmware version is updated just as before

        ./ncp.py scan

    which should yield

        Connecting to.. /dev/ttyUSB1 57600 True False 
        {"ports": [{"port": "/dev/ttyUSB1", "vid": "10C4", "pid": "8A2A", "deviceType": "zigbee", "stackVersion": "6.7.8-373"}]}

    Success! 

5. Type `exit` to exit the Docker container. The user should return to `pi@raspberrypi:`. Now it's safe to remove the two images.

        docker image rm 
        docker image rm python:buster

#### 5.1.2. Updating Z-Wave Firmware

Instructions for updating the Z-Wave firmware can be found [here](https://community.hubitat.com/t/guide-nortek-husbzb-1-nvm-backup-restore-and-updating-z-wave-firmware/48012). I did not try this as there did not seem to be any functional benefit, but I'm documenting one user's process in case that changes. This is highly unlikely though, because the HUSBZB-1 is already outdated (a/o 2022).

### 5.2. Migrating from Z-Wave (depricated) intregation to Z-Wave JS integration

Since we're running Home Assistant Container, the automated migration tool from Z-Wave (depricated) to Z-Wave JS integrations will not work. Instead we have to use the [advanced installation instructions](https://www.home-assistant.io/integrations/zwave_js/#advanced-installation-instructions), specifically Option 3: The Zwavejs2Mqtt Docker container. Let's follow the [setup instructions to run ZWavejs2Mqtt as a service](https://zwave-js.github.io/zwavejs2mqtt/#/getting-started/docker?id=run-as-a-service) (i.e. in a Docker container).

1. Copy and paste the service into `docker-compose.yml` with the following edits:

    - Uncomment the time zone environment variable (`TZ=America/New_York`), or set this variable from the .env file.
    - Change the Z-Wave device name from 
        
        `/dev/serial/by-id/insert_stick_reference_here` 
        
        to 

        `/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_4150060D-if00-port0` 
        
        which was previously identified in [Z-Wave and Zigbee Controller Setup](#z-wave-and-zigbee-controller-setup).
    - Change and move the `SESSION_SECRET` variable to the `.env` file. (if needed - TBD)
2. Start the ZWaveJS2Mqtt service
3. Navigate to `http://<IP Address>:80911`, click settings on the left side, expand the `Home Assistant` section and select the toggle to turn on the `WS Server` functionality. The server port should show as `3000`. Click save.
4. In settings, generate keys for each `S2 Unauth`, `S2 Auth`, `S2 Access Control`, and `S0 Legacy`. Copy/paste these keys into the `.env` file and [add as environment variables](https://zwave-js.github.io/zwavejs2mqtt/#/guide/env-vars)  in the `docker-compose.yml` file where the content in the brackets `{ }` is the variable name in the `.env` file. 
        
        KEY_S0_Legacy=${zwavejs2mqtt_s2authkey}
        KEY_S2_Unauthenticated=${zwavejs2mqtt_s2unauthkey}
        KEY_S2_Authenticated=${zwavejs2mqtt_s2authkey}
        KEY_S2_AccessControl=${zwavejs2mqtt_s2accessctrlkey}

5. Restart the ZWaveJS2Mqtt service. Once restarted, verify the keys are in the Z-wave settings section and that `WS Server` is still enabled in the Home Assistant settings section.
6. In Home Assistant, add the Z-Wave JS integration with the default server URL as `ws://localhost:3000`.

### Custom Database Usage

MariaDB


InfluxDB
- https://www.home-assistant.io/integrations/influxdb/#configuration
- https://docs.influxdata.com/influxdb/v2.4/get-started/
- https://community.home-assistant.io/t/home-assistant-docker-not-able-to-connect-to-influxdb-2-0-docker/389958
- https://smarthomescene.com/guides/optimize-your-home-assistant-database/
- https://community.home-assistant.io/t/complete-guide-on-setting-up-grafana-influxdb-with-home-assistant-using-official-docker-images/42860
  
Grafana 
- https://docs.influxdata.com/influxdb/v2.4/tools/grafana/
.- https://grafana.com/docs/grafana/v9.0/setup-grafana/installation/docker/
  
  
### 6. MQTT Broker

An MQTT broker does ...
This will be used for Amcrest, Zigbee, and Z-Wave integrations.

#### 6.1. Setting up Mosquitto
The MQTT broker we'll use is Mosquitto. We'll follow [these instructions](https://www.homeautomationguy.io/docker-tips/configuring-the-mosquitto-mqtt-docker-container-for-use-with-home-assistant/) for setting up Mosquitto MQTT Broker in Docker and integrate it into Home Assistant.

The Docker Compose for Mosquitto is added to the Home Assistant docker-compose.yaml

    mosquitto:
        container_name: mosquitto-mqtt
        image: eclipse-mosquitto
        volumes:
        - ./mosquitto:/mosquitto
        ports:
        - 1883:1883
        - 9001:9001

In the Home Assistant directory, add a new folder called `mosquitto` and create `mosquitto.conf` within `mosquitto`. In `mosquitto.conf`, paste the following then start the Mosquitto docker container.

    persistence true
    persistence_location /mosquitto/data/
    log_dest file /mosquitto/log/mosquitto.log
    listener 1883

    ## Authentication ##
    #allow_anonymous false
    #password_file /mosquitto/config/password.txt

If `allow_anonymous true`, any device on the network can access Mosquitto MQTT. Instead, set up an authentication with user `homeassistant` so devices need to be granted permission to access Mosquitto. Enter a password and re-enter it to confirm.

    docker-compose exec mosquitto mosquitto_passwd -c /mosquitto/config/password.txt homeassistant

Uncomment the authentication lines in `mosquitto.conf` and save. It may be necessary to establish write permissions. Do so with the following:

    sudo chown <username> -R <server_directory>

Now restart the Mosquitto container for the changes to take effect.

    docker restart mosquitto-mqtt

#### 6.2. Connecting Mosquitto MQTT to Home Assistant

This is as simple as adding the MQTT integration in Home Assistant. Use the server IP address, leave port 1883, and enter the username and password previously established.

#### 6.3. Adding Amcrest devices to Home Assistant
Setting up local processing and recording of Amcrest device requires [amcrest2mqtt](https://github.com/dchesterton/amcrest2mqtt). Enter the following configuration into the Home Assistant docker-compose.yaml, ensure the variables are in `.env`, and build the container.

    amcrest2mqtt:
        container_name: amcrest2mqtt
        image: dchesterton/amcrest2mqtt:latest
        restart: unless-stopped
        environment:
            AMCREST_HOST: ${amcrest_ip_backyard}
            AMCREST_PASSWORD: ${amcrest_pwd}
            MQTT_HOST: ${SERVER_IP}
            MQTT_USERNAME: ${mosquitto_user}
            MQTT_PASSWORD: ${mosquitto_pwd}
            HOME_ASSISTANT: "true"

Once built, the Amcrest device declared by the `AMCREST_HOST` environment variable will be automatically detected in Home Assistant. For multiple Amcrest devices, duplicate this image with the different Amcrest IP address. Additionally, name the containers for quick identification, for example:

    amcrest2mqtt-backyard
    amcrest2mqtt-doorbell
    amcrest2mqtt-deck

### 7. Amcrest Local Processing with Frigate

Frigate provides object identification, notifications, and recording functionality for the Amcrest cameras. The [Frigate Documentation](https://docs.frigate.video/installation) is the main reference for installation and configuration of Frigate. The docker-compose service is below with the following adjustments:

- Only the Intel hardware acceleration is passed through. This may change if I add a USB Coral later*
- Update volumes path to point where the Frigate configuration and data should be stored.
- Removed temporary file storage config (`type: tmpfs`) because I'm not worried about read/write wear on the server.
- Added `FRIGATE_RSTP_PASSWORD` (which is the authentication for the Amcrest device) and `FRIGATE_MQTT_PASSWORD` (which is the authentication for the Mosquitto MQTT broker) for use in `config.yml`. These variables must have the `FRIGATE_` prefix.
- `FRIGATE_MQTT_HOST` and `FRIGATE_MQTT_USERNAME` are commented out in hopes I can figure out if/how to import these environment variables into `config.yml`. Seemingly, only the two passwords above are allowed by Frigate to be accessed as environment variables. For now these variables are manually entered into `config.yml`.

~~~
frigate:
    container_name: frigate
    privileged: true # this may not be necessary for all setups
    restart: unless-stopped
    image: blakeblackshear/frigate:stable-amd64
    shm_size: 64mb # update for your cameras based on calculation above
    devices:
    # - /dev/bus/usb:/dev/bus/usb # passes the USB Coral, needs to be modified for other versions
    # - /dev/apex_0:/dev/apex_0 # passes a PCIe Coral, follow driver instructions here https://coral.ai/docs/m2/get-started/#2a-on-linux
    - /dev/dri/renderD128 # for intel hwaccel, needs to be updated for your hardware
    volumes:
    - /etc/localtime:/etc/localtime:ro
    - ./frigate/config.yml:/config/config.yml:ro
    - ./frigate/storage:/media/frigate
    # - type: tmpfs # Optional: 1GB of memory, reduces SSD/SD Card wear
    #   target: /tmp/cache
    #   tmpfs:
    #     size: 1000000000
    ports:
    - 5000:5000
    - 1935:1935 # RTMP feeds
    environment:
    FRIGATE_RTSP_PASSWORD: ${amcrest_pwd}
    # FRIGATE_MQTT_HOST: ${SERVER_IP}
    # FRIGATE_MQTT_USERNAME: ${mosquitto_user}
    FRIGATE_MQTT_PASSWORD: ${mosquitto_pwd}
~~~

Since the container volumes are being mapped to our host drive, first create the host directories before spinning up the container. Create the `frigate` directory with the `config.yml` file and `storage` directories nested inside.

#### 7.1. Configuring Frigate

Follow the [Creating a config file](https://docs.frigate.video/guides/getting_started) and [Configuration File](https://docs.frigate.video/configuration/index) parts of the Frigate documentation to configure `config.yml`. Here, define the MQTT host, username, and password.

    mqtt:
      host: 192.168.1.99
      user: homeassistant
      password: '{FRIGATE_MQTT_PASSWORD}'

Ideally, I'd also have `host` and `user` being pulled from an environment variable, but as stated above, I haven't figured out how to do this. `'{ENV_VAR}'`, `{ENV_VAR}`, and `${ENV_VAR}` all failed. For this service specifically, only the passwords seem to be allowed given they have the `FRIGATE_` prefix.

Set up the additional variables, such as cameras, recording, snapshots, and objects to detect here as well per the [Configuration File](https://docs.frigate.video/configuration/index) example. See [Hardware Accelaration documentation](https://docs.frigate.video/configuration/hardware_acceleration) to set that for the server hardware (e.g. Intel acceleration).

Finding the proper camera rtsp path took some finagling. The Amcrest ASH26-W Floodlight Camera does not have a web interface. It cannot be accessed by entering the device's URL into a browser (in fact, [this applies to all Amcrest devices with a model prefix of ASH](https://ipcamtalk.com/threads/amcrest-ash22-web-interface.56235/#post-553197)). Additionally, the [Creating a config file](https://docs.frigate.video/guides/getting_started) and [Configuration File](https://docs.frigate.video/configuration/index) parts of the Frigate documentation don't match and aren't very clear what each part is. At a minimum, the `rtsp` path may be:

    rtsp://<device_user>:<device_password>@<device_URL>/

which in practice in this `config.yml` file looks like the following, where `{FRIGATE_RSTP_PASSWORD}` is pulled from the Docker container's environment variable in the `.env` file.

    rtsp://admin:{FRIGATE_RTSP_PASSWORD}@192.168.1.21/

I did not need the extra port number or specific path details shown in the documentation. 

The video resolution is set to `1920x1080` to match the floodlight's resolution.

#### 7.2. Setting up Frigate Integration in Home Assistant

Using Frigate with Home Assistant requires a Custom Component. This creates a custom integration for use in addition to the standard integrations that are available with Home Assistant. The Frigate Custom Component must be installed manually since this server uses Home Assistant Docker. Do this by downloading or cloning the [Frigate Home Assistant Integration](https://github.com/blakeblackshear/frigate-hass-integration) and the adding the [`custom_components/frigate`](https://github.com/blakeblackshear/frigate-hass-integration/tree/master/custom_components/frigate) folder to the `config/custom_components` folder within the Home Assistant directory.

To see the integration in Home Assistant, restart Home Assistant. It may also be necessary to [clear the browser cache to get Frigate integration to show](https://www.reddit.com/r/homeassistant/comments/nzth1z/comment/h1rmyqk/?utm_source=share&utm_medium=web2x&context=3). Search for "Frigate" in the Add Integration part of Home Assistant and set the URL to `http://<server_IP>:5000/`.

In Home Assistant's `configuration.yaml`, add a `media_source:` line. This will allow Frigate recordings, snapshots, and clips to be viewable in the `Home Assistant > Media` menu. _Note: this may not be required, but I haven't tested it._

#### 7.3. Playing Back Recorded Media

If the camera is set to H.265 encoding (the default setting for the ASH26-W), videos will save but playback is inoperable in most browsers. Playback is operational in the Home Assistant app, and via Home Assistant and the Frigate UI on Safari only (only browser with H.265 full support).

Switch to H.264 encoding to allow viewing in a wider range of browsers, which is more broadly supported. 
1. Use [Amcrest's IP Config Tool](https://support.amcrest.com/hc/en-us/articles/360004527171-Amcrest-IP-Config-Tool-Download) to change the [Encode Mode from H.265 to H.264](https://www.reddit.com/r/homeassistant/comments/q7qloo/comment/hjaobs5/?utm_source=share&utm_medium=web2x&context=3). 
2. Search for the device in the config tool by IP address and login credentials. 
3. In the device settings, change `Encode Mode` in the Encode tab and press save. 
4. In `config.yml`, set `rtmp` to `enabled: True`, then restart Frigate.

So far this has fixed playback in Home Assistant on Firefox, but playback in the Frigate UI still displays `Playback cannot continue. No available working or supported playlists.`

#### 7.4. Home Assistant Notifications for Frigate Events

Not operational yet. [Start here](https://docs.frigate.video/guides/ha_notifications).