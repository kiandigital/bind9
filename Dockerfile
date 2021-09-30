FROM alpine:3.14.2

RUN apk --update upgrade && \
    apk add --update bind && \
    rm -rf /var/cache/apk/*

#
# Add named init script.
#

COPY init.sh /init.sh
RUN chmod 750 /init.sh

#
# Define container settings.
#

EXPOSE 53/udp
EXPOSE 53/tcp

WORKDIR /etc/bind


#
# Start named.
#

CMD ["/init.sh"]