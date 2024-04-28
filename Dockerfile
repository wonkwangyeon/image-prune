FROM alpine:latest

RUN apk --no-cache add openssh curl jq bash
COPY image_prune.sh .
RUN chmod +x image_prune.sh

CMD ["/image_prune.sh"]