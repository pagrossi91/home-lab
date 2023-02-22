# Builds a DHCP relay container that listens for DHCP discovery requests on the LAN and forwards them to Pihole on Docker’s internal network.
FROM alpine:latest
RUN apk --no-cache add dhcp-helper

# Expose the UDP port 67 in order to receive DHCP discovery requests.
EXPOSE 67 67/udp

ENTRYPOINT ["dhcp-helper", "-n"]
