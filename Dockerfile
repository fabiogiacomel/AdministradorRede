FROM alpine:latest
RUN apk add --no-cache bash openssh-client sshpass iputils arp-scan
CMD ["bash"]
