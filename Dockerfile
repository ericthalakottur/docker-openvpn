FROM alpine:3.12.0

COPY ./install_openvpn.sh /scripts/

RUN apk -U upgrade && \
	apk add openvpn easy-rsa

CMD /scripts/install_openvpn.sh