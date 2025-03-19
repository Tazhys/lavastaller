#!/bin/bash

# Default settings
INSTALL_MODE="full"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config-only)
            INSTALL_MODE="config-only"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--config-only]"
            exit 1
            ;;
    esac
done

if [ "$INSTALL_MODE" = "config-only" ]; then
    echo "Running in config-only mode for Lavalink 3.6.2..."
    
    # Create Lavalink directory if it doesn't exist
    echo "Creating Lavalink directory (if it doesn't exist)..."
    sudo mkdir -p /home/Lavalink
    sudo chmod 755 /home/Lavalink

    # Create the application.yml file
    echo "Creating application.yml file..."
    cat <<'EOF' | sudo tee /home/Lavalink/application.yml
lavalink:
    plugins: null
    server:
        bufferDurationMs: 400
        filters:
            channelMix: true
            distortion: true
            equalizer: true
            karaoke: true
            lowPass: true
            rotation: true
            timescale: true
            tremolo: true
            vibrato: true
            volume: true
        frameBufferDurationMs: 5000
        gc-warnings: true
        nonAllocatingFrameBuffer: false
        opusEncodingQuality: 10
        password: youshallnotpass
        playerUpdateInterval: 5
        resamplingQuality: LOW
        soundcloudSearchEnabled: true
        sources:
            bandcamp: true
            http: true
            local: false
            nico: true
            soundcloud: true
            twitch: true
            vimeo: true
            youtube: false
        trackStuckThresholdMs: 10000
        useSeekGhosting: true
        youtubePlaylistLoadLimit: 6
        youtubeSearchEnabled: true
logging:
    file:
        path: ./logs/
    level:
        lavalink: INFO
        root: INFO
    logback:
        rollingpolicy:
            max-file-size: 1GB
            max-history: 30
    request:
        enabled: true
        includeClientInfo: true
        includeHeaders: false
        includePayload: true
        includeQueryString: true
        maxPayloadLength: 10000
metrics:
    prometheus:
        enabled: false
        endpoint: /metrics
plugins: null
sentry:
    dsn: ""
    environment: ""
server:
    address: 0.0.0.0
    http2:
        enabled: false
    port: 8967
EOF

    # Create a systemd service file for LavaLink
    echo "Creating lavalink.service..."
    cat <<EOL | sudo tee /etc/systemd/system/lavalink.service
[Unit]
Description=LavaLink
After=network.target

[Service]
User=root
WorkingDirectory=/home/Lavalink
ExecStart=/usr/bin/java -jar /home/Lavalink/Lavalink.jar
SuccessExitStatus=143
TimeoutStopSec=10
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemd daemon
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    # Enable and start the LavaLink service
    echo "Enabling and starting lavalink.service..."
    sudo systemctl enable lavalink.service
    sudo systemctl start lavalink.service

    # Check the status of the service
    echo "Checking the status of lavalink.service..."
    sudo systemctl status lavalink.service

    echo "LavaLink configuration for version 3.6.2 complete!"
else
    # Update and upgrade the system
    echo "Updating system..."
    sudo apt update && sudo apt upgrade -y

    # Install Java
    echo "Installing Java..."
    sudo apt install openjdk-11-jre-headless -y

    # Verify Java installation
    java_version=$(java -version 2>&1)
    echo "Java version installed: $java_version"

    # Create Lavalink directory
    echo "Creating Lavalink directory..."
    sudo mkdir -p /home/Lavalink
    sudo chmod 755 /home/Lavalink

    # Download LavaLink.jar
    echo "Downloading LavaLink.jar..."
    wget https://github.com/lavalink-devs/Lavalink/releases/download/3.6.2/Lavalink.jar -O /home/Lavalink/Lavalink.jar

    # Create a systemd service file for LavaLink
    echo "Creating lavalink.service..."
    cat <<EOL | sudo tee /etc/systemd/system/lavalink.service
[Unit]
Description=LavaLink
After=network.target

[Service]
User=root
WorkingDirectory=/home/Lavalink
ExecStart=/usr/bin/java -jar /home/Lavalink/Lavalink.jar
SuccessExitStatus=143
TimeoutStopSec=10
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemd daemon
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    # Enable and start the LavaLink service
    echo "Enabling and starting lavalink.service..."
    sudo systemctl enable lavalink.service
    sudo systemctl start lavalink.service

    # Check the status of the service
    echo "Checking the status of lavalink.service..."
    sudo systemctl status lavalink.service

    echo "LavaLink installation and setup complete!"

    ### Nginx Installation and Configuration ###
    echo "Installing Nginx..."
    sudo apt install nginx -y

    # Retrieve the public IPv4 and IPv6 addresses automatically using ifconfig.me.
    ipv4=$(curl -4 -s ifconfig.me)
    ipv6=$(curl -6 -s ifconfig.me)

    echo "Detected IPv4: $ipv4"
    echo "Detected IPv6: $ipv6"

    echo "Configuring Nginx default server block..."
    sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name ${ipv4} ${ipv6} _;

    location / {
        proxy_pass http://127.0.0.1:8967;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

    ### UFW Configuration ###
    echo "Installing UFW..."
    sudo apt install ufw -y

    echo "Allowing HTTP (port 80) through UFW..."
    sudo ufw allow 80/tcp

    # Optionally, if you need to allow direct access to Lavalink on port 8967 (not recommended if using a reverse proxy):
    echo "Allowing Lavalink (port 8967) through UFW..."
    sudo ufw allow 8967/tcp

    echo "Reloading Nginx..."
    sudo systemctl reload nginx
fi
