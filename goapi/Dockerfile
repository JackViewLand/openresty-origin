FROM golang:1.24-alpine

WORKDIR /app

# 安裝 air
RUN go install github.com/air-verse/air@latest

COPY . .

CMD ["air"]