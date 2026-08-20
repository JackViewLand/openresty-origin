# air v1.67+ 需要 go >= 1.26；go.mod 宣告的 1.24.4 由新版 toolchain 向下相容
FROM golang:1.26-alpine

WORKDIR /app

# 安裝 air（釘住版本，避免 @latest 某天要求更新的 go 而讓 build 突然壞掉）
RUN go install github.com/air-verse/air@v1.67.4

COPY . .

CMD ["air"]
